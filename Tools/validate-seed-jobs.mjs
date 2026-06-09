import fs from "node:fs";

const file = process.argv[2] ?? "JobPilotLite/SeedJobs.json";
const jobs = JSON.parse(fs.readFileSync(file, "utf8"));
const maxVerificationAgeHours = Number.parseInt(process.env.JOB_VALIDATE_MAX_VERIFICATION_AGE_HOURS ?? "36", 10);
const minimumLiveJobs = Number.parseInt(process.env.JOB_VALIDATE_MIN_LIVE_JOBS ?? "1", 10);

const requiredFields = [
  "id",
  "company",
  "title",
  "city",
  "remoteType",
  "salary",
  "tags",
  "sourceURL",
  "contactEmail",
  "summary",
  "requirements",
  "visaFriendly",
  "postedDaysAgo",
  "liveStatus",
  "lastVerifiedAt",
  "verifiedSourceURL"
];

const uuidPattern = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/i;
const emailPattern = /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i;
const ids = new Set();
const urls = new Set();
const errors = [];
let verifiedLive = 0;
let oldestVerifiedAt = null;
let newestVerifiedAt = null;

jobs.forEach((job, index) => {
  for (const field of requiredFields) {
    if (!(field in job)) errors.push(`job[${index}] missing ${field}`);
  }

  if (!uuidPattern.test(job.id ?? "")) errors.push(`job[${index}] invalid id`);
  if (ids.has(job.id)) errors.push(`job[${index}] duplicate id ${job.id}`);
  ids.add(job.id);

  if (!job.sourceURL || urls.has(job.sourceURL)) errors.push(`job[${index}] duplicate or missing sourceURL`);
  urls.add(job.sourceURL);

  if (!Array.isArray(job.tags)) errors.push(`job[${index}] tags is not an array`);
  if (!Array.isArray(job.requirements)) errors.push(`job[${index}] requirements is not an array`);
  if (job.contactEmail !== null && !emailPattern.test(job.contactEmail)) errors.push(`job[${index}] invalid contactEmail`);
  if (typeof job.visaFriendly !== "boolean") errors.push(`job[${index}] visaFriendly is not boolean`);
  if (!Number.isInteger(job.postedDaysAgo)) errors.push(`job[${index}] postedDaysAgo is not integer`);

  if ("liveStatus" in job && job.liveStatus !== "live") errors.push(`job[${index}] unsupported liveStatus`);
  if (job.liveStatus !== "live") errors.push(`job[${index}] missing live verification`);
  if (!job.verifiedSourceURL || typeof job.verifiedSourceURL !== "string") errors.push(`job[${index}] missing verifiedSourceURL`);

  const verifiedAt = Date.parse(job.lastVerifiedAt ?? "");
  if (Number.isNaN(verifiedAt)) {
    errors.push(`job[${index}] invalid lastVerifiedAt`);
  } else {
    verifiedLive += job.liveStatus === "live" ? 1 : 0;
    oldestVerifiedAt = oldestVerifiedAt === null ? verifiedAt : Math.min(oldestVerifiedAt, verifiedAt);
    newestVerifiedAt = newestVerifiedAt === null ? verifiedAt : Math.max(newestVerifiedAt, verifiedAt);

    const ageHours = (Date.now() - verifiedAt) / 3_600_000;
    if (ageHours < -0.25) errors.push(`job[${index}] lastVerifiedAt is in the future`);
    if (ageHours > maxVerificationAgeHours) {
      errors.push(`job[${index}] stale live verification: ${ageHours.toFixed(1)}h old`);
    }
  }
});

if (verifiedLive !== jobs.length) {
  errors.push(`verifiedLive ${verifiedLive} does not match job count ${jobs.length}`);
}

if (verifiedLive < minimumLiveJobs) {
  errors.push(`verifiedLive ${verifiedLive} is below minimum ${minimumLiveJobs}`);
}

const stats = {
  jobs: jobs.length,
  uniqueIds: ids.size,
  uniqueUrls: urls.size,
  companies: new Set(jobs.map((job) => job.company)).size,
  salaryListed: jobs.filter((job) => job.salary && job.salary !== "Not listed").length,
  recruitingEmailListed: jobs.filter((job) => job.contactEmail).length,
  requirementsListed: jobs.filter((job) => job.requirements?.length).length,
  verifiedLive,
  oldestVerifiedAt: oldestVerifiedAt === null ? null : new Date(oldestVerifiedAt).toISOString(),
  newestVerifiedAt: newestVerifiedAt === null ? null : new Date(newestVerifiedAt).toISOString(),
  sourceSizeMB: Math.round((fs.statSync(file).size / 1024 / 1024) * 10) / 10
};

console.log(JSON.stringify(stats, null, 2));

if (errors.length) {
  console.error(errors.slice(0, 50).join("\n"));
  if (errors.length > 50) console.error(`...and ${errors.length - 50} more errors`);
  process.exit(1);
}
