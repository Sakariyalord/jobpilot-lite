import fs from "node:fs";

const baseURL = process.argv[2];
const configPath = process.argv[3] ?? "JobPilotLite/JobFeedConfig.json";

if (!baseURL) {
  console.error("Usage: node Tools/configure-job-feed-config.mjs https://owner.github.io/repo/");
  process.exit(1);
}

const normalizedBaseURL = baseURL.endsWith("/") ? baseURL : `${baseURL}/`;
const url = new URL(normalizedBaseURL);
if (url.protocol !== "https:") {
  console.error("Job feed URL must use HTTPS.");
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
config.remoteJobsURL = new URL("LiveJobs.json", normalizedBaseURL).toString();
config.remoteJobIndexURL = new URL("index.json", normalizedBaseURL).toString();
config.minimumLiveJobs = Number.isInteger(config.minimumLiveJobs) ? config.minimumLiveJobs : 12000;
config.startupMinimumLiveJobs = Number.isInteger(config.startupMinimumLiveJobs) ? config.startupMinimumLiveJobs : 200;
config.refreshIntervalHours = Number.isInteger(config.refreshIntervalHours) ? config.refreshIntervalHours : 24;
config.prefetchSliceLimit = Number.isInteger(config.prefetchSliceLimit) ? config.prefetchSliceLimit : 3;

fs.writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`);
console.log(JSON.stringify({
  configPath,
  remoteJobsURL: config.remoteJobsURL,
  remoteJobIndexURL: config.remoteJobIndexURL
}, null, 2));
