import fs from "node:fs";
import path from "node:path";

const registryPath = process.argv[2] ?? "Data/JobSourceRegistry.json";
const reportPath = process.argv[3] ?? "Data/job-source-discovery-report.json";
const seedPath = process.env.JOB_DISCOVERY_SEED_PATH ?? "Data/JobDiscoverySeeds.json";
const checkedAt = new Date().toISOString();

const maxCDXUrlsPerPattern = Number.parseInt(process.env.JOB_DISCOVERY_CDX_URL_LIMIT ?? "250", 10);
const validateLimit = Number.parseInt(process.env.JOB_DISCOVERY_VALIDATE_LIMIT ?? "90", 10);
const maxNewSources = Number.parseInt(process.env.JOB_DISCOVERY_MAX_NEW_SOURCES ?? "60", 10);
const concurrency = Number.parseInt(process.env.JOB_DISCOVERY_CONCURRENCY ?? "6", 10);
const timeoutMs = Number.parseInt(process.env.JOB_DISCOVERY_TIMEOUT_MS ?? "15000", 10);

const cdxPatterns = [
  { platform: "greenhouse", url: "boards.greenhouse.io/", matchType: "prefix" },
  { platform: "ashby", url: "jobs.ashbyhq.com/", matchType: "prefix" },
  { platform: "lever", url: "jobs.lever.co/", matchType: "prefix" },
  { platform: "smartrecruiters", url: "jobs.smartrecruiters.com/", matchType: "prefix" }
];

const supportedPlatforms = ["greenhouse", "ashby", "lever", "smartrecruiters", "recruitee"];

function readJSONIfExists(file) {
  if (!fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function writeJSON(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
}

function normalizeBoardSlug(value) {
  return String(value ?? "")
    .trim()
    .replace(/^https?:\/\/[^/]+\//i, "")
    .split(/[/?#]/)[0]
    .replace(/[^a-z0-9._ -]/gi, "")
    .trim();
}

function sourceKey(platform, board) {
  return `${String(platform ?? "").toLowerCase()}:${normalizeBoardSlug(board).toLowerCase()}`;
}

function sourceActive(source) {
  const status = String(source.status ?? "active").toLowerCase();
  return status !== "disabled" && status !== "blocked";
}

function readRegistry(file) {
  const payload = readJSONIfExists(file);
  const sources = Array.isArray(payload) ? payload : payload?.sources;

  const normalizedSources = Array.isArray(sources)
    ? sources
      .map((source) => ({
        ...source,
        platform: String(source.platform ?? "").toLowerCase(),
        board: normalizeBoardSlug(source.board ?? source.slug),
        status: source.status ?? "active"
      }))
      .filter((source) =>
        supportedPlatforms.includes(source.platform) &&
        source.board &&
        sourceActive(source)
      )
    : [];
  const seen = new Set();

  return {
    version: 1,
    sourcePolicy: {
      publicOnly: true,
      noLoginOrAntiBotBypass: true,
      publishOnlyAfterLiveVerification: true,
      allowedPlatforms: supportedPlatforms
    },
    sources: normalizedSources.filter((source) => {
      const key = sourceKey(source.platform, source.board);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
  };
}

function parseCDXLines(text) {
  return text
    .split(/\n+/)
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return null;
      }
    })
    .filter(Boolean);
}

async function fetchJSON(url) {
  const response = await fetch(url, {
    headers: {
      "accept": "application/json",
      "user-agent": "JobPilotLiteMVP/0.1 public source discovery"
    },
    signal: AbortSignal.timeout(timeoutMs)
  });

  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`.trim());
  return response.json();
}

async function fetchText(url) {
  const response = await fetch(url, {
    headers: {
      "accept": "text/html,application/json;q=0.9,*/*;q=0.8",
      "user-agent": "JobPilotLiteMVP/0.1 public source discovery"
    },
    signal: AbortSignal.timeout(timeoutMs)
  });

  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`.trim());
  return response.text();
}

async function latestCommonCrawlIndex() {
  const collections = await fetchJSON("https://index.commoncrawl.org/collinfo.json");
  const latest = Array.isArray(collections) ? collections[0] : null;
  if (!latest?.["cdx-api"]) throw new Error("Common Crawl index unavailable");
  return latest;
}

async function fetchCDXUrls(apiURL, query) {
  const url = new URL(apiURL);
  url.searchParams.set("url", query.url);
  if (query.matchType) url.searchParams.set("matchType", query.matchType);
  url.searchParams.set("output", "json");
  url.searchParams.set("fl", "url");
  url.searchParams.append("filter", "status:200");
  url.searchParams.append("filter", "!url:.*robots\\.txt");
  url.searchParams.append("collapse", "urlkey");
  url.searchParams.set("limit", String(maxCDXUrlsPerPattern));

  const text = await fetchText(url);
  return parseCDXLines(text).map((row) => row.url).filter(Boolean);
}

function readSeedURLs(file) {
  const payload = readJSONIfExists(file);
  const values = Array.isArray(payload) ? payload : payload?.urls;
  if (!Array.isArray(values)) return [];

  return values
    .map((item) => typeof item === "string" ? item : item?.url)
    .filter(Boolean);
}

function extractBoardFromURL(platform, rawURL) {
  let url;
  try {
    url = new URL(rawURL);
  } catch {
    return null;
  }

  const host = url.hostname.toLowerCase();
  const segments = url.pathname.split("/").filter(Boolean);
  let board = normalizeBoardSlug(decodeURIComponent(segments[0] ?? ""));
  const blocked = new Set([
    "api",
    "embed",
    "job_app",
    "privacy",
    "robots.txt",
    "terms",
    "users"
  ]);

  if (platform === "recruitee") {
    if (!host.endsWith(".recruitee.com")) return null;
    board = normalizeBoardSlug(host.replace(/\.recruitee\.com$/i, ""));
  }

  if (!board || blocked.has(board) || board.includes(".")) return null;
  if (platform === "greenhouse" && host !== "boards.greenhouse.io") return null;
  if (platform === "ashby" && host !== "jobs.ashbyhq.com") return null;
  if (platform === "lever" && host !== "jobs.lever.co") return null;
  if (platform === "smartrecruiters" && host !== "jobs.smartrecruiters.com") return null;
  if (platform === "recruitee" && ["app", "api", "www", "support", "status"].includes(board.toLowerCase())) return null;

  return {
    platform,
    board,
    lastSeenURL: rawURL
  };
}

function cleanText(text = "") {
  return text
    .replace(/<[^>]+>/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/\s+/g, " ")
    .trim();
}

async function validateGreenhouse(board) {
  const url = `https://boards-api.greenhouse.io/v1/boards/${encodeURIComponent(board)}/jobs?content=false`;
  const data = await fetchJSON(url);
  const jobs = Array.isArray(data.jobs) ? data.jobs : [];
  if (jobs.length === 0) throw new Error("greenhouse_empty_board");

  return {
    company: jobs.find((job) => job.company_name)?.company_name ?? board,
    jobCount: jobs.length,
    validationURL: url
  };
}

async function validateAshby(board) {
  const url = `https://api.ashbyhq.com/posting-api/job-board/${encodeURIComponent(board)}`;
  const data = await fetchJSON(url);
  const jobs = Array.isArray(data.jobs) ? data.jobs.filter((job) => job.isListed !== false) : [];
  if (jobs.length === 0) throw new Error("ashby_empty_board");

  return {
    company: data.name || data.companyName || data.organizationName || board,
    jobCount: jobs.length,
    validationURL: url
  };
}

async function validateLever(board) {
  const url = `https://jobs.lever.co/${encodeURIComponent(board)}`;
  const html = await fetchText(url);
  const postings = [...html.matchAll(/data-qa-posting-id="([^"]+)"/g)];
  if (postings.length === 0) throw new Error("lever_empty_board");

  const title = cleanText(html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] ?? "");
  const company = title
    .replace(/\s*-\s*Jobs\s*$/i, "")
    .replace(/\s*-\s*Careers\s*$/i, "")
    .trim() || board;

  return {
    company,
    jobCount: postings.length,
    validationURL: url
  };
}

async function validateSmartRecruiters(board) {
  const url = `https://api.smartrecruiters.com/v1/companies/${encodeURIComponent(board)}/postings?limit=1`;
  const data = await fetchJSON(url);
  const jobs = Array.isArray(data.content) ? data.content : [];
  if (jobs.length === 0) throw new Error("smartrecruiters_empty_board");

  return {
    company: jobs[0]?.company?.name ?? board,
    jobCount: Number(data.totalFound ?? jobs.length),
    validationURL: url
  };
}

async function validateRecruitee(board) {
  const url = `https://${board}.recruitee.com/api/offers/`;
  const data = await fetchJSON(url);
  const jobs = Array.isArray(data)
    ? data
    : Array.isArray(data.offers)
      ? data.offers
      : Array.isArray(data.result)
        ? data.result
        : [];
  if (jobs.length === 0) throw new Error("recruitee_empty_board");

  return {
    company: board,
    jobCount: jobs.length,
    validationURL: url
  };
}

async function validateCandidate(candidate) {
  const validators = {
    greenhouse: validateGreenhouse,
    ashby: validateAshby,
    lever: validateLever,
    smartrecruiters: validateSmartRecruiters,
    recruitee: validateRecruitee
  };
  const validate = validators[candidate.platform];
  if (!validate) throw new Error(`unsupported_platform_${candidate.platform}`);

  const result = await validate(candidate.board);
  return {
    ...candidate,
    ...result,
    status: "active",
    discoveredBy: candidate.discoveredBy ?? "common_crawl",
    firstDiscoveredAt: checkedAt,
    lastDiscoveredAt: checkedAt,
    lastValidatedAt: checkedAt
  };
}

async function validateInBatches(candidates) {
  const accepted = [];
  const rejected = [];
  let nextIndex = 0;

  async function worker() {
    while (nextIndex < candidates.length && accepted.length < maxNewSources) {
      const index = nextIndex;
      nextIndex += 1;
      const candidate = candidates[index];

      try {
        const source = await validateCandidate(candidate);
        accepted.push(source);
        console.error(`${candidate.platform}:${candidate.board}: accepted (${source.jobCount} jobs)`);
      } catch (error) {
        rejected.push({
          ...candidate,
          status: "rejected",
          error: error.message
        });
      }
    }
  }

  await Promise.all(Array.from({ length: Math.max(1, concurrency) }, worker));
  return { accepted, rejected };
}

const registry = readRegistry(registryPath);
const existingKeys = new Set(registry.sources.map((source) => sourceKey(source.platform, source.board)));
const candidates = new Map();
const cdxReports = [];
const seedReports = [];
let index = null;

for (const rawURL of readSeedURLs(seedPath)) {
  for (const platform of supportedPlatforms) {
    const candidate = extractBoardFromURL(platform, rawURL);
    if (!candidate) continue;
    const key = sourceKey(candidate.platform, candidate.board);
    if (existingKeys.has(key) || candidates.has(key)) continue;
    candidates.set(key, { ...candidate, discoveredBy: "seed_file" });
    seedReports.push({ platform: candidate.platform, board: candidate.board, url: rawURL });
  }
}

try {
  index = await latestCommonCrawlIndex();

  for (const query of cdxPatterns) {
    try {
      const urls = await fetchCDXUrls(index["cdx-api"], query);
      let added = 0;

      for (const rawURL of urls) {
        const candidate = extractBoardFromURL(query.platform, rawURL);
        if (!candidate) continue;
        const key = sourceKey(candidate.platform, candidate.board);
        if (existingKeys.has(key) || candidates.has(key)) continue;
        candidates.set(key, candidate);
        added += 1;
      }

      cdxReports.push({ platform: query.platform, url: query.url, urls: urls.length, candidates: added });
    } catch (error) {
      cdxReports.push({ platform: query.platform, url: query.url, error: error.message });
    }
  }
} catch (error) {
  cdxReports.push({ error: error.message });
}

const candidateList = [...candidates.values()]
  .sort((a, b) => a.platform.localeCompare(b.platform) || a.board.localeCompare(b.board))
  .slice(0, validateLimit);

const { accepted, rejected } = await validateInBatches(candidateList);
const acceptedSources = accepted.slice(0, maxNewSources);
const mergedSources = [...registry.sources, ...acceptedSources]
  .sort((a, b) => a.platform.localeCompare(b.platform) || a.board.localeCompare(b.board));

writeJSON(registryPath, {
  version: 1,
  updatedAt: checkedAt,
  sourcePolicy: registry.sourcePolicy,
  sources: mergedSources
});

writeJSON(reportPath, {
  checkedAt,
  commonCrawlIndex: index?.id ?? null,
  registryPath,
  seedPath,
  existingSources: registry.sources.length,
  seedReports,
  cdxReports,
  candidateSources: candidates.size,
  validatedSources: candidateList.length,
  newSources: acceptedSources.length,
  rejectedSources: rejected.length,
  accepted: acceptedSources,
  rejected: rejected.slice(0, 200)
});

console.error(`Discovered ${acceptedSources.length} new sources from ${candidateList.length} validated candidates.`);
