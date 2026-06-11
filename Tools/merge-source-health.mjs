import fs from "node:fs";
import path from "node:path";

const output = process.argv[2] ?? "Data/JobSourceHealth.json";
const inputs = process.argv.slice(3);

function findJSONFiles(input) {
  if (!fs.existsSync(input)) return [];
  const stat = fs.statSync(input);
  if (stat.isFile() && input.endsWith(".json")) return [input];
  if (!stat.isDirectory()) return [];

  return fs.readdirSync(input, { withFileTypes: true })
    .flatMap((entry) => findJSONFiles(path.join(input, entry.name)));
}

function sourceKey(source) {
  return `${String(source.platform ?? "").toLowerCase()}:${String(source.board ?? "").toLowerCase()}`;
}

function newerSource(a, b) {
  const aTime = Date.parse(a.lastFetchedAt ?? a.updatedAt ?? "");
  const bTime = Date.parse(b.lastFetchedAt ?? b.updatedAt ?? "");
  if (Number.isNaN(aTime)) return b;
  if (Number.isNaN(bTime)) return a;
  return bTime >= aTime ? b : a;
}

const files = inputs.flatMap(findJSONFiles);
const merged = new Map();
const reports = [];

if (fs.existsSync(output)) {
  try {
    const existing = JSON.parse(fs.readFileSync(output, "utf8"));
    for (const source of existing.sources ?? []) {
      merged.set(sourceKey(source), source);
    }
  } catch {
    // Ignore unreadable previous health files.
  }
}

for (const file of files) {
  try {
    const payload = JSON.parse(fs.readFileSync(file, "utf8"));
    const sources = Array.isArray(payload.sources) ? payload.sources : [];
    for (const source of sources) {
      const key = sourceKey(source);
      if (!key.includes(":") || key.endsWith(":")) continue;
      merged.set(key, merged.has(key) ? newerSource(merged.get(key), source) : source);
    }
    reports.push({ file, sources: sources.length });
  } catch (error) {
    reports.push({ file, error: error.message });
  }
}

const outputPayload = {
  updatedAt: new Date().toISOString(),
  sources: [...merged.values()].sort((a, b) =>
    String(a.platform).localeCompare(String(b.platform)) ||
    String(a.board).localeCompare(String(b.board))
  )
};

fs.mkdirSync(path.dirname(output), { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(outputPayload, null, 2)}\n`);

console.error(JSON.stringify({
  inputFiles: files.length,
  sources: outputPayload.sources.length,
  output,
  reports
}, null, 2));
