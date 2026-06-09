import fs from "node:fs";
import path from "node:path";

const source = process.argv[2] ?? "Data/JobFeed/LiveJobs.json";
const outputDir = process.argv[3] ?? "Data/JobFeed";
const startupOutput = process.argv[4] ?? "JobPilotLite/SeedJobs.json";
const startupLimit = Number.parseInt(process.argv[5] ?? "800", 10);

const sliceDir = path.join(outputDir, "jobs");
const liveOutput = path.join(outputDir, "LiveJobs.json");
const indexOutput = path.join(outputDir, "index.json");

const categoryRules = [
  ["software", "Software & IT", /\b(software|developer|backend|frontend|full.?stack|ios|android|mobile|cloud|devops|security|sre|infrastructure|platform|qa|test engineer)\b/i],
  ["data", "Data & Analytics", /\b(data|analytics|analyst|scientist|bi|business intelligence|machine learning|ml|ai|sql)\b/i],
  ["product-design", "Product & Design", /\b(product|designer|ux|ui|user experience|researcher|design)\b/i],
  ["sales-customer", "Sales & Customer", /\b(sales|account executive|business development|customer success|customer support|support|crm|revenue)\b/i],
  ["operations", "Operations & Logistics", /\b(operations|logistics|supply chain|warehouse|coordinator|program manager|project manager)\b/i],
  ["healthcare", "Healthcare", /\b(healthcare|clinical|nurse|nursing|patient|medical|therapist|physician|care)\b/i],
  ["finance", "Finance & Accounting", /\b(finance|accounting|accountant|payroll|tax|controller|fp&a|bookkeeper|treasury)\b/i],
  ["marketing", "Marketing", /\b(marketing|content|brand|growth|seo|social media|campaign|communications)\b/i],
  ["education", "Education", /\b(education|teacher|teaching|school|student|academic|curriculum|tutor|instructor)\b/i],
  ["hr-admin", "HR & Admin", /\b(recruiter|recruiting|talent|human resources|hr|admin|assistant|office manager)\b/i],
  ["field-work", "Field & Manufacturing", /\b(manufacturing|technician|mechanic|field|production|quality|maintenance|electrician|driver)\b/i]
];

const regionRules = [
  ["remote", "Remote", /\b(remote|anywhere|distributed)\b/i],
  ["united-states", "United States", /\b(united states|usa|u\.s\.| us |new york|san francisco|los angeles|seattle|austin|boston|chicago|california|texas|washington|florida|illinois)\b/i],
  ["canada", "Canada", /\b(canada|toronto|vancouver|montreal|ottawa|calgary|ontario|quebec|british columbia)\b/i],
  ["united-kingdom", "United Kingdom", /\b(united kingdom| uk |london|manchester|edinburgh|birmingham|bristol|glasgow)\b/i],
  ["australia", "Australia", /\b(australia|sydney|melbourne|brisbane|perth|adelaide|canberra)\b/i],
  ["europe", "Europe", /\b(europe|germany|france|netherlands|ireland|spain|sweden|berlin|munich|paris|amsterdam|dublin|madrid|stockholm)\b/i]
];

function readJobs(file) {
  const parsed = JSON.parse(fs.readFileSync(file, "utf8"));
  if (!Array.isArray(parsed)) throw new Error(`${file} must contain a JSON array`);
  return parsed.filter((job) => job.liveStatus === "live" && job.lastVerifiedAt && job.verifiedSourceURL);
}

function textFor(job) {
  return [
    job.title,
    job.company,
    job.city,
    job.remoteType,
    job.roleCategory,
    ...(job.tags ?? []),
    job.summary,
    ...(job.requirements ?? [])
  ].filter(Boolean).join(" ");
}

function categoryFor(job) {
  const known = String(job.roleCategory ?? job.tags?.[0] ?? "").toLowerCase();
  for (const [slug, title] of categoryRules) {
    if (known.includes(title.toLowerCase()) || known.includes(slug)) return slug;
  }

  const text = textFor(job);
  return categoryRules.find(([, , pattern]) => pattern.test(text))?.[0] ?? "general";
}

function regionsFor(job) {
  const text = ` ${textFor(job)} `;
  const regions = regionRules
    .filter(([, , pattern]) => pattern.test(text))
    .map(([slug]) => slug);

  return regions.length ? [...new Set(regions)] : ["global"];
}

function opportunityFor(job) {
  const text = textFor(job).toLowerCase();
  if (/\b(intern|internship|co-?op|student|graduate|new grad|early career)\b/.test(text)) return "internship";
  if (/\b(contract|temporary|seasonal|part.?time|part time)\b/.test(text)) return "contract";
  return "full-time";
}

function workModeFor(job) {
  const text = `${job.remoteType ?? ""} ${job.city ?? ""}`.toLowerCase();
  if (text.includes("remote")) return "remote";
  if (text.includes("hybrid")) return "hybrid";
  if (text.includes("on-site") || text.includes("onsite") || text.includes("office")) return "on-site";
  return "any";
}

function jobPriority(job) {
  const title = String(job.title ?? "").toLowerCase();
  let score = 0;
  if (job.salary && job.salary !== "Not listed") score += 10;
  if (job.contactEmail) score += 4;
  if (workModeFor(job) === "remote") score += 5;
  if (opportunityFor(job) === "internship") score += 3;
  if (/\b(entry|associate|assistant|coordinator|junior|new grad|graduate)\b/.test(title)) score += 4;
  if (/\b(senior|staff|principal|director|head of|vp)\b/.test(title)) score -= 4;
  score -= Math.min(Number(job.postedDaysAgo ?? 30), 30) / 10;
  return score;
}

function newestVerification(jobs) {
  return jobs
    .map((job) => Date.parse(job.lastVerifiedAt ?? ""))
    .filter((value) => !Number.isNaN(value))
    .sort((a, b) => b - a)
    .map((value) => new Date(value).toISOString())[0] ?? null;
}

function writeJSON(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(value));
}

function selectStartupJobs(jobs, limit) {
  const sorted = [...jobs].sort((a, b) => jobPriority(b) - jobPriority(a));
  const picked = [];
  const companyCounts = new Map();
  const categoryCounts = new Map();

  for (const job of sorted) {
    const company = job.company ?? "Unknown";
    const category = categoryFor(job);
    if ((companyCounts.get(company) ?? 0) >= 6) continue;
    if ((categoryCounts.get(category) ?? 0) >= Math.ceil(limit / 4)) continue;

    picked.push(job);
    companyCounts.set(company, (companyCounts.get(company) ?? 0) + 1);
    categoryCounts.set(category, (categoryCounts.get(category) ?? 0) + 1);
    if (picked.length >= limit) return picked;
  }

  const pickedIds = new Set(picked.map((job) => job.id));
  for (const job of sorted) {
    if (pickedIds.has(job.id)) continue;
    picked.push(job);
    if (picked.length >= limit) break;
  }

  return picked;
}

function makeSlice(id, title, jobs, metadata = {}, limit = 1500) {
  const sliceJobs = [...jobs]
    .sort((a, b) => jobPriority(b) - jobPriority(a))
    .slice(0, limit);

  if (sliceJobs.length < 20) return null;

  const file = `jobs/${id}.json`;
  writeJSON(path.join(outputDir, file), sliceJobs);

  return {
    id,
    title,
    url: file,
    jobCount: sliceJobs.length,
    lastVerifiedAt: newestVerification(sliceJobs),
    ...metadata
  };
}

const liveJobs = readJobs(source);
if (liveJobs.length < startupLimit) {
  throw new Error(`Only ${liveJobs.length} live jobs are available; startup limit is ${startupLimit}`);
}

fs.mkdirSync(sliceDir, { recursive: true });
writeJSON(liveOutput, liveJobs);
writeJSON(startupOutput, selectStartupJobs(liveJobs, startupLimit));

const slices = [];
const addSlice = (...args) => {
  const slice = makeSlice(...args);
  if (slice) slices.push(slice);
};

addSlice("featured", "Featured verified jobs", selectStartupJobs(liveJobs, 800), {
  category: "featured",
  workMode: "any",
  opportunityType: "any",
  locations: ["global"],
  keywords: ["featured", "verified", "popular"]
}, 800);

for (const [slug, title] of categoryRules) {
  const categoryJobs = liveJobs.filter((job) => categoryFor(job) === slug);
  addSlice(slug, title, categoryJobs, {
    category: slug,
    workMode: "any",
    opportunityType: "any",
    locations: ["global"],
    keywords: [slug, ...title.toLowerCase().split(/[^a-z]+/).filter(Boolean)]
  });

  addSlice(`${slug}-remote`, `${title} remote`, categoryJobs.filter((job) => workModeFor(job) === "remote"), {
    category: slug,
    workMode: "remote",
    opportunityType: "any",
    locations: ["remote"],
    keywords: [slug, "remote"]
  }, 1000);

  addSlice(`${slug}-internship`, `${title} internships`, categoryJobs.filter((job) => opportunityFor(job) === "internship"), {
    category: slug,
    workMode: "any",
    opportunityType: "internship",
    locations: ["global"],
    keywords: [slug, "internship", "student", "graduate"]
  }, 800);
}

for (const [slug, title] of regionRules) {
  addSlice(slug, title, liveJobs.filter((job) => regionsFor(job).includes(slug)), {
    category: "all",
    workMode: slug === "remote" ? "remote" : "any",
    opportunityType: "any",
    locations: [slug],
    keywords: [slug, title.toLowerCase()]
  });
}

for (const opportunity of ["internship", "full-time", "contract"]) {
  addSlice(opportunity, opportunity.replace("-", " "), liveJobs.filter((job) => opportunityFor(job) === opportunity), {
    category: "all",
    workMode: "any",
    opportunityType: opportunity,
    locations: ["global"],
    keywords: [opportunity, "job"]
  });
}

const index = {
  generatedAt: new Date().toISOString(),
  liveJobsURL: "LiveJobs.json",
  totalLiveJobs: liveJobs.length,
  startupJobs: startupLimit,
  featuredSliceIds: ["featured", "remote", "united-states", "internship"],
  slices: slices.sort((a, b) => b.jobCount - a.jobCount)
};

writeJSON(indexOutput, index);

console.log(JSON.stringify({
  liveJobs: liveJobs.length,
  startupJobs: startupLimit,
  slices: slices.length,
  outputDir,
  startupOutput
}, null, 2));
