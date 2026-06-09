import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const projectFile = path.join(root, "JobPilotLite.xcodeproj/project.pbxproj");
const project = fs.readFileSync(projectFile, "utf8");

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(fullPath);
    return fullPath;
  });
}

const swiftFiles = walk(path.join(root, "JobPilotLite"))
  .filter((file) => file.endsWith(".swift"))
  .map((file) => path.basename(file));

const requiredResources = ["Assets.xcassets", "SeedJobs.json", "JobFeedConfig.json"];
const missing = [];

for (const file of swiftFiles) {
  if (!project.includes(`/* ${file} in Sources */`)) missing.push(`${file} is not in Sources build phase`);
}

for (const resource of requiredResources) {
  if (!project.includes(`/* ${resource} in Resources */`)) missing.push(`${resource} is not in Resources build phase`);
}

const stats = {
  swiftFiles: swiftFiles.length,
  requiredResources: requiredResources.length,
  projectFile: "JobPilotLite.xcodeproj/project.pbxproj"
};

console.log(JSON.stringify(stats, null, 2));

if (missing.length) {
  console.error(missing.join("\n"));
  process.exit(1);
}
