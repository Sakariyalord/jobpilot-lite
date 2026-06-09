import fs from "node:fs";
import crypto from "node:crypto";

const input = process.argv[2] ?? "Data/seed_jobs_template.csv";
const output = process.argv[3] ?? "JobPilotLite/SeedJobs.json";

function parseCSV(text) {
  const rows = [];
  let row = [];
  let cell = "";
  let quoted = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];

    if (char === "\"" && quoted && next === "\"") {
      cell += "\"";
      index += 1;
      continue;
    }

    if (char === "\"") {
      quoted = !quoted;
      continue;
    }

    if (char === "," && !quoted) {
      row.push(cell);
      cell = "";
      continue;
    }

    if ((char === "\n" || char === "\r") && !quoted) {
      if (char === "\r" && next === "\n") index += 1;
      row.push(cell);
      if (row.some((value) => value.trim() !== "")) rows.push(row);
      row = [];
      cell = "";
      continue;
    }

    cell += char;
  }

  if (cell.length > 0 || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }

  return rows;
}

function stableUUID(seed) {
  const hash = crypto.createHash("sha1").update(seed).digest("hex");
  return [
    hash.slice(0, 8),
    hash.slice(8, 12),
    `4${hash.slice(13, 16)}`,
    ((parseInt(hash.slice(16, 18), 16) & 0x3f) | 0x80).toString(16) + hash.slice(18, 20),
    hash.slice(20, 32)
  ].join("-").toUpperCase();
}

const text = fs.readFileSync(input, "utf8");
const [headers, ...records] = parseCSV(text);
const normalizedHeaders = headers.map((header) => header.trim());

const jobs = records.map((record) => {
  const row = Object.fromEntries(normalizedHeaders.map((header, index) => [header, record[index]?.trim() ?? ""]));
  const idSeed = `${row.company}|${row.title}|${row.city}|${row.sourceURL}`;

  return {
    id: row.id || stableUUID(idSeed),
    company: row.company,
    title: row.title,
    city: row.city,
    remoteType: row.remoteType,
    salary: row.salary,
    tags: row.tags ? row.tags.split("|").map((tag) => tag.trim()).filter(Boolean) : [],
    sourceURL: row.sourceURL,
    contactEmail: row.contactEmail || null,
    summary: row.summary,
    requirements: row.requirements ? row.requirements.split("|").map((item) => item.trim()).filter(Boolean) : [],
    visaFriendly: row.visaFriendly.toLowerCase() === "true",
    postedDaysAgo: Number.parseInt(row.postedDaysAgo || "0", 10)
  };
});

fs.writeFileSync(output, `${JSON.stringify(jobs, null, 2)}\n`);
console.log(`Wrote ${jobs.length} jobs to ${output}`);
