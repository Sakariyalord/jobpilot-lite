import fs from "node:fs";
import path from "node:path";

const output = process.argv[2] ?? "/tmp/jobpilot-merged-candidates.json";
const limit = Number.parseInt(process.argv[3] ?? "30000", 10);
const inputs = process.argv.slice(4);

function readJSON(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function findJSONFiles(input) {
  if (!fs.existsSync(input)) return [];
  const stat = fs.statSync(input);
  if (stat.isFile() && input.endsWith(".json")) return [input];
  if (!stat.isDirectory()) return [];

  return fs.readdirSync(input, { withFileTypes: true })
    .flatMap((entry) => findJSONFiles(path.join(input, entry.name)));
}

function normalizeURL(url = "") {
  try {
    const parsed = new URL(url);
    parsed.hash = "";
    return parsed.toString().replace(/\/$/, "");
  } catch {
    return String(url).trim();
  }
}

function jobKey(job) {
  return normalizeURL(job.verifiedSourceURL || job.sourceURL) || job.id;
}

function qualityScore(job) {
  const title = String(job.title ?? "").toLowerCase();
  let score = 0;
  if (job.salary && job.salary !== "Not listed") score += 50;
  if (job.contactEmail) score += 60;
  if (Array.isArray(job.requirements)) score += Math.min(job.requirements.length * 5, 25);
  if (String(job.remoteType ?? "").toLowerCase().includes("remote")) score += 12;
  if (/\b(intern|internship|new grad|junior|entry|associate|assistant|coordinator)\b/.test(title)) score += 10;
  if (/\b(senior|staff|principal|director|head of|vp)\b/.test(title)) score -= 8;
  score += Math.max(0, 35 - Number(job.postedDaysAgo ?? 35));
  return score;
}

function selectDiverseJobs(jobs, targetLimit) {
  const sorted = [...jobs].sort((a, b) => qualityScore(b) - qualityScore(a));
  const selected = [];
  const selectedKeys = new Set();
  const companyCounts = new Map();
  const platformCounts = new Map();
  const categoryCounts = new Map();
  const passes = [
    { company: 160, platform: Math.ceil(targetLimit * 0.65), category: Math.ceil(targetLimit * 0.45) },
    { company: 320, platform: Math.ceil(targetLimit * 0.8), category: Math.ceil(targetLimit * 0.6) },
    { company: Number.POSITIVE_INFINITY, platform: Number.POSITIVE_INFINITY, category: Number.POSITIVE_INFINITY }
  ];

  for (const pass of passes) {
    for (const job of sorted) {
      if (selected.length >= targetLimit) return selected;

      const key = jobKey(job);
      if (!key || selectedKeys.has(key)) continue;

      const company = job.company || "Unknown company";
      const platform = job.sourcePlatform || "unknown";
      const category = job.roleCategory || job.tags?.[0] || "General";

      if ((companyCounts.get(company) ?? 0) >= pass.company) continue;
      if ((platformCounts.get(platform) ?? 0) >= pass.platform) continue;
      if ((categoryCounts.get(category) ?? 0) >= pass.category) continue;

      selected.push(job);
      selectedKeys.add(key);
      companyCounts.set(company, (companyCounts.get(company) ?? 0) + 1);
      platformCounts.set(platform, (platformCounts.get(platform) ?? 0) + 1);
      categoryCounts.set(category, (categoryCounts.get(category) ?? 0) + 1);
    }
  }

  return selected;
}

const files = inputs.flatMap(findJSONFiles);
const merged = new Map();
const fileReports = [];

for (const file of files) {
  try {
    const jobs = readJSON(file);
    if (!Array.isArray(jobs)) continue;
    let added = 0;

    for (const job of jobs) {
      const key = jobKey(job);
      if (!key) continue;
      const existing = merged.get(key);
      if (!existing || qualityScore(job) > qualityScore(existing)) {
        merged.set(key, job);
        added += 1;
      }
    }

    fileReports.push({ file, jobs: jobs.length, added });
  } catch (error) {
    fileReports.push({ file, error: error.message });
  }
}

const selected = selectDiverseJobs([...merged.values()], limit);
fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(selected, null, 2)}\n`);

console.error(JSON.stringify({
  inputFiles: files.length,
  uniqueCandidates: merged.size,
  writtenCandidates: selected.length,
  output,
  fileReports
}, null, 2));
