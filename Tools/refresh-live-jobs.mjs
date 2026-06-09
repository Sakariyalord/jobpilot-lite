import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";

const output = process.argv[2] ?? "JobPilotLite/SeedJobs.json";
const targetLiveJobs = Number.parseInt(process.argv[3] ?? "16000", 10);
const candidateJobs = Number.parseInt(process.argv[4] ?? String(Math.ceil(targetLiveJobs * 1.35)), 10);
const reportPath = process.argv[5] ?? "Data/job-refresh-report.json";

function runNode(script, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [script, ...args], {
      stdio: "inherit",
      env: process.env
    });

    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${script} exited with code ${code}`));
    });
  });
}

fs.mkdirSync("Data", { recursive: true });
const candidatesPath = path.join(os.tmpdir(), `jobpilot-candidates-${Date.now()}.json`);
const verifiedPath = path.join(os.tmpdir(), `jobpilot-verified-${Date.now()}.json`);

console.error(`Fetching up to ${candidateJobs} public ATS jobs...`);
await runNode("Tools/fetch-public-jobs.mjs", [candidatesPath, String(candidateJobs)]);

console.error(`Verifying candidates and keeping ${targetLiveJobs} live jobs...`);
await runNode("Tools/verify-live-jobs.mjs", [candidatesPath, verifiedPath, String(targetLiveJobs), reportPath]);

try {
  fs.unlinkSync(candidatesPath);
} catch {
  // Ignore temp cleanup errors.
}

const finalJobs = JSON.parse(fs.readFileSync(verifiedPath, "utf8"));
if (finalJobs.length < targetLiveJobs) {
  console.error(`Only ${finalJobs.length}/${targetLiveJobs} live jobs were available from current public sources.`);
  process.exitCode = 2;
} else {
  fs.copyFileSync(verifiedPath, output);
  console.error(`Refresh complete: ${finalJobs.length} live jobs.`);
}

try {
  fs.unlinkSync(verifiedPath);
} catch {
  // Ignore temp cleanup errors.
}
