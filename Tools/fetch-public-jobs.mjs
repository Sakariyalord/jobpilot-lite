import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const output = process.argv[2] ?? "JobPilotLite/SeedJobs.json";
const limit = Number.parseInt(process.argv[3] ?? "2000", 10);
const sourceRegistryPath = process.env.JOB_SOURCE_REGISTRY_PATH ?? "Data/JobSourceRegistry.json";
const sourceHealthPath = process.env.JOB_SOURCE_HEALTH_PATH ?? "Data/JobSourceHealth.json";
const extraSourceLimit = Number.parseInt(process.env.JOB_FETCH_EXTRA_SOURCE_LIMIT ?? "120", 10);
const sourceBatchIndex = Number.parseInt(process.env.JOB_FETCH_SOURCE_BATCH_INDEX ?? "0", 10);
const sourceBatchTotal = Number.parseInt(process.env.JOB_FETCH_SOURCE_BATCH_TOTAL ?? "1", 10);
const enabledSources = new Set(
  (process.env.JOB_FETCH_SOURCES ?? "greenhouse,ashby,lever,smartrecruiters,recruitee")
    .split(",")
    .map((source) => source.trim().toLowerCase())
    .filter(Boolean)
);

function sourceEnabled(source) {
  return enabledSources.has("all") || enabledSources.has(source);
}

const defaultGreenhouseBoards = [
  "andurilindustries",
  "databricks",
  "stripe",
  "doordashusa",
  "mongodb",
  "okta",
  "samsara",
  "toast",
  "verkada",
  "roblox",
  "airbnb",
  "oscar",
  "brex",
  "appliedintuition",
  "natera",
  "pinterest",
  "scaleai",
  "block",
  "affirm",
  "reddit",
  "figma",
  "gitlab",
  "elastic",
  "sofi",
  "twilio",
  "cloudflare",
  "boxinc",
  "asana",
  "robinhood",
  "instacart",
  "lyft",
  "motional",
  "postman",
  "nuro",
  "flexport",
  "duolingo",
  "gusto",
  "redwoodmaterials",
  "discord",
  "headway",
  "chime",
  "faire",
  "peloton",
  "twitch",
  "dropbox",
  "mercury",
  "sweetgreen",
  "komodohealth",
  "project44",
  "growtherapy",
  "bird",
  "webflow",
  "renttherunway",
  "khanacademy",
  "thrivemarket",
  "omadahealth",
  "stockx",
  "airtable",
  "calendly",
  "honor",
  "modernhealth",
  "udemy",
  "udacity",
  "coursera",
  "waymo",
  "hellofresh",
  "anthropic",
  "canonical",
  "workato",
  "intercom",
  "checkr",
  "gomotive",
  "life360",
  "ziprecruiter",
  "mavenclinic",
  "chargepoint",
  "nextdoor",
  "gemini",
  "newsela",
  "greenhouse",
  "glossier",
  "sendbird",
  "instabase",
  "shopmonkey",
  "thirtymadison",
  "outschool",
  "calm",
  "spacex",
  "datadog",
  "rocketlab",
  "relativity",
  "remotecom",
  "braze",
  "tripactions",
  "doctolib",
  "thetradedesk",
  "wizinc",
  "formlabs",
  "astranis",
  "rubrik",
  "smartsheet",
  "lucidmotors",
  "jfrog",
  "planetlabs",
  "newrelic",
  "fastly",
  "amplitude",
  "instawork",
  "launchdarkly",
  "snorkelai",
  "maymobility",
  "mixpanel",
  "marqeta",
  "pendo",
  "freenome",
  "cockroachlabs",
  "starburst",
  "descript",
  "flatironhealth",
  "collectivehealth",
  "taskrabbit",
  "skyscanner",
  "transcarent",
  "guild",
  "circleci",
  "planetscale",
  "labelbox",
  "pathai"
];

const defaultAshbyBoards = [
  { slug: "openai", company: "OpenAI" },
  { slug: "airwallex", company: "Airwallex" },
  { slug: "harvey", company: "Harvey" },
  { slug: "elevenlabs", company: "ElevenLabs" },
  { slug: "notion", company: "Notion" },
  { slug: "cohere", company: "Cohere" },
  { slug: "sierra", company: "Sierra" },
  { slug: "ramp", company: "Ramp" },
  { slug: "decagon", company: "Decagon" },
  { slug: "langchain", company: "LangChain" },
  { slug: "cursor", company: "Cursor" },
  { slug: "replit", company: "Replit" },
  { slug: "perplexity", company: "Perplexity" },
  { slug: "cognition", company: "Cognition" },
  { slug: "mercor", company: "Mercor" },
  { slug: "writer", company: "Writer" },
  { slug: "supabase", company: "Supabase" },
  { slug: "reflectionai", company: "Reflection AI" },
  { slug: "cartesia", company: "Cartesia" },
  { slug: "modal", company: "Modal" },
  { slug: "zapier", company: "Zapier" },
  { slug: "linear", company: "Linear" },
  { slug: "poolside", company: "Poolside" },
  { slug: "commonroom", company: "Common Room" },
  { slug: "browserbase", company: "Browserbase" },
  { slug: "pinecone", company: "Pinecone" },
  { slug: "runway", company: "Runway" },
  { slug: "hightouch", company: "Hightouch" },
  { slug: "saronic", company: "Saronic" },
  { slug: "deel", company: "Deel" },
  { slug: "handshake", company: "Handshake" },
  { slug: "synthesia", company: "Synthesia" },
  { slug: "plaid", company: "Plaid" },
  { slug: "1password", company: "1Password" },
  { slug: "deepgram", company: "Deepgram" },
  { slug: "formenergy", company: "Form Energy" },
  { slug: "confluent", company: "Confluent" },
  { slug: "benchling", company: "Benchling" },
  { slug: "watershed", company: "Watershed" },
  { slug: "wealthsimple", company: "Wealthsimple" },
  { slug: "attio", company: "Attio" },
  { slug: "onebrief", company: "Onebrief" },
  { slug: "astronomer", company: "Astronomer" },
  { slug: "brightwheel", company: "Brightwheel" },
  { slug: "render", company: "Render" },
  { slug: "classdojo", company: "ClassDojo" },
  { slug: "railway", company: "Railway" },
  { slug: "neon", company: "Neon" },
  { slug: "guild", company: "Guild" },
  { slug: "prefect", company: "Prefect" }
];

const defaultLeverBoards = [
  { slug: "palantir", company: "Palantir" },
  { slug: "dnb", company: "Dun & Bradstreet" },
  { slug: "cti-md", company: "CTI" },
  { slug: "zoox", company: "Zoox" },
  { slug: "spotify", company: "Spotify" }
];

const defaultSmartRecruitersBoards = [
  { slug: "AbbVie", company: "AbbVie" },
  { slug: "BoschGroup", company: "Bosch Group" },
  { slug: "WesternDigital", company: "Western Digital" },
  { slug: "Visa", company: "Visa" },
  { slug: "SmartRecruiters", company: "SmartRecruiters" },
  { slug: "AbanoHealthcare", company: "Abano Healthcare" },
  { slug: "1Huddle", company: "1Huddle" },
  { slug: "CityFibre", company: "CityFibre" }
];

const defaultRecruiteeBoards = [
  { slug: "1x", company: "1X" },
  { slug: "greatminds", company: "Great Minds" },
  { slug: "openrole", company: "Openrole" },
  { slug: "asmpthk", company: "ASMPT" },
  { slug: "technicaengineeringgmbh", company: "Technica Engineering" },
  { slug: "xneelo", company: "xneelo" },
  { slug: "sahl", company: "Sahl" },
  { slug: "cta", company: "Tech Allies" }
];

function readJSONIfExists(file) {
  if (!fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function sourceKey(platform, board) {
  return `${String(platform ?? "").toLowerCase()}:${String(board ?? "").toLowerCase()}`;
}

function normalizeBoardSlug(value) {
  return String(value ?? "")
    .trim()
    .replace(/^https?:\/\/[^/]+\//i, "")
    .split(/[/?#]/)[0]
    .replace(/[^a-z0-9._ -]/gi, "")
    .trim();
}

function sourceActive(source) {
  const status = String(source.status ?? "active").toLowerCase();
  return status !== "disabled" && status !== "blocked" && status !== "quarantined";
}

function readRegistrySources(file) {
  try {
    const payload = readJSONIfExists(file);
    if (!payload) return [];
    const rawSources = Array.isArray(payload) ? payload : payload.sources;
    if (!Array.isArray(rawSources)) return [];

    return rawSources
      .map((source) => ({
        platform: String(source.platform ?? "").toLowerCase(),
        board: normalizeBoardSlug(source.board ?? source.slug),
        company: source.company ? String(source.company).trim() : null,
        status: source.status ?? "active"
      }))
      .filter((source) =>
        ["greenhouse", "ashby", "lever", "smartrecruiters", "recruitee"].includes(source.platform) &&
        source.board &&
        sourceActive(source)
      );
  } catch (error) {
    console.error(`Source registry skipped (${error.message})`);
    return [];
  }
}

function mergeGreenhouseBoards(defaults, registrySources) {
  const seen = new Set();
  const merged = [];

  for (const board of defaults) {
    const slug = normalizeBoardSlug(board);
    const key = slug.toLowerCase();
    if (!slug || seen.has(key)) continue;
    seen.add(key);
    merged.push(slug);
  }

  let added = 0;
  for (const source of registrySources.filter((item) => item.platform === "greenhouse")) {
    const key = source.board.toLowerCase();
    if (seen.has(key)) continue;
    if (added >= extraSourceLimit) break;
    seen.add(key);
    merged.push(source.board);
    added += 1;
  }

  return merged;
}

function mergeObjectBoards(platform, defaults, registrySources) {
  const seen = new Set();
  const merged = [];

  for (const board of defaults) {
    const slug = normalizeBoardSlug(board.slug);
    const key = slug.toLowerCase();
    if (!slug || seen.has(key)) continue;
    seen.add(key);
    merged.push({ ...board, slug });
  }

  let added = 0;
  for (const source of registrySources.filter((item) => item.platform === platform)) {
    const key = source.board.toLowerCase();
    if (seen.has(key)) continue;
    if (added >= extraSourceLimit) break;
    seen.add(key);
    merged.push({ slug: source.board, company: source.company ?? source.board });
    added += 1;
  }

  return merged;
}

function applySourceBatch(platform, sources) {
  if (sourceBatchTotal <= 1 || !sourceEnabled(platform)) return sources;
  if (sourceBatchIndex < 0 || sourceBatchIndex >= sourceBatchTotal) {
    throw new Error(`JOB_FETCH_SOURCE_BATCH_INDEX must be between 0 and ${sourceBatchTotal - 1}`);
  }

  return sources.filter((_, index) => index % sourceBatchTotal === sourceBatchIndex);
}

function writeSourceHealth(reports) {
  if (!sourceHealthPath) return;

  const previous = (() => {
    try {
      const payload = readJSONIfExists(sourceHealthPath);
      return Array.isArray(payload?.sources) ? payload.sources : [];
    } catch {
      return [];
    }
  })();
  const merged = new Map(previous.map((source) => [sourceKey(source.platform, source.board), source]));

  for (const report of reports) {
    merged.set(sourceKey(report.platform, report.board), {
      ...merged.get(sourceKey(report.platform, report.board)),
      ...report,
      lastFetchedAt: report.lastFetchedAt ?? new Date().toISOString()
    });
  }

  fs.mkdirSync(path.dirname(sourceHealthPath), { recursive: true });
  fs.writeFileSync(sourceHealthPath, `${JSON.stringify({
    updatedAt: new Date().toISOString(),
    sources: [...merged.values()].sort((a, b) =>
      String(a.platform).localeCompare(String(b.platform)) ||
      String(a.board).localeCompare(String(b.board))
    )
  }, null, 2)}\n`);
}

const registrySources = readRegistrySources(sourceRegistryPath);
const greenhouseBoards = applySourceBatch("greenhouse", mergeGreenhouseBoards(defaultGreenhouseBoards, registrySources));
const ashbyBoards = applySourceBatch("ashby", mergeObjectBoards("ashby", defaultAshbyBoards, registrySources));
const leverBoards = applySourceBatch("lever", mergeObjectBoards("lever", defaultLeverBoards, registrySources));
const smartRecruitersBoards = applySourceBatch("smartrecruiters", mergeObjectBoards("smartrecruiters", defaultSmartRecruitersBoards, registrySources));
const recruiteeBoards = applySourceBatch("recruitee", mergeObjectBoards("recruitee", defaultRecruiteeBoards, registrySources));
const sourceReports = [];

console.error(
  `Source registry: ${registrySources.length} active records; fetching ` +
  `${greenhouseBoards.length} Greenhouse, ${ashbyBoards.length} Ashby, ${leverBoards.length} Lever, ` +
  `${smartRecruitersBoards.length} SmartRecruiters, ${recruiteeBoards.length} Recruitee boards` +
  (sourceBatchTotal > 1 ? `; source batch ${sourceBatchIndex + 1}/${sourceBatchTotal}` : "")
);

const skillDictionary = [
  "Swift", "SwiftUI", "iOS", "Android", "Kotlin", "Java", "JavaScript", "TypeScript",
  "React", "Node", "Python", "Ruby", "Go", "Rust", "C++", "C#", "SQL", "Postgres",
  "MySQL", "MongoDB", "Redis", "AWS", "GCP", "Azure", "Kubernetes", "Docker",
  "Terraform", "Spark", "Kafka", "Airflow", "Tableau", "Looker", "Excel", "Analytics",
  "Machine Learning", "AI", "Data Science", "Product", "Design", "Figma", "Sales",
  "Marketing", "Operations", "Finance", "Accounting", "Customer Support", "Security",
  "Compliance", "Legal", "Recruiting", "HR", "Mandarin", "Spanish", "English",
  "Retail", "Store Manager", "Merchandising", "Inventory", "POS", "Cash Handling",
  "Customer Service", "Customer Success", "Call Center", "Account Executive", "CRM",
  "Salesforce", "Business Development", "Partnerships", "Admissions", "Education",
  "Teacher", "Tutor", "Curriculum", "Healthcare", "Clinical", "Nursing", "RN",
  "Medical Assistant", "Patient Support", "Medical Billing", "Pharmacy", "Therapy",
  "Behavioral Health", "Insurance", "Claims", "Underwriting", "Payroll", "Bookkeeping",
  "Accounts Payable", "Accounts Receivable", "Audit", "Tax", "FP&A", "Banking",
  "Real Estate", "Property Management", "Hospitality", "Restaurant", "Food Service",
  "Barista", "Cook", "Kitchen", "Logistics", "Supply Chain", "Warehouse", "Forklift",
  "CDL", "Driver", "Dispatch", "Procurement", "Manufacturing", "Production",
  "Quality Assurance", "Quality Control", "Maintenance", "Facilities", "Safety",
  "OSHA", "Construction", "Electrical", "Mechanical", "HVAC", "Technician",
  "Field Service", "Administrative", "Receptionist", "Office Manager", "Paralegal",
  "Legal Assistant", "Content", "Copywriting", "Social Media", "Events"
];

const titlePriorityRules = [
  ["Sales & Business Development", /\b(account executive|sales|business development|territory|partnerships?|revenue|customer growth|commercial)\b/i],
  ["Customer Support & Success", /\b(customer support|customer success|support specialist|client success|implementation consultant|solutions consultant|technical support|call center)\b/i],
  ["Operations & Logistics", /\b(operations|logistics|supply chain|warehouse|driver|dispatch|fulfillment|procurement|fleet|inventory)\b/i],
  ["Finance & Accounting", /\b(finance|accounting|bookkeeper|payroll|tax|audit|fp&a|controller|treasury|underwriting|claims|insurance)\b/i],
  ["HR & Recruiting", /\b(recruiter|recruiting|talent acquisition|human resources|people operations|hrbp|compensation|benefits)\b/i],
  ["Legal & Compliance", /\b(legal|counsel|paralegal|compliance|policy|privacy|risk|regulatory)\b/i],
  ["Healthcare & Clinical", /\b(clinical|nurse|rn|medical|patient|healthcare|therapist|pharmacy|behavioral health|care coordinator)\b/i],
  ["Retail & Hospitality", /\b(retail associate|store manager|store associate|restaurant|hospitality|barista|cook|kitchen|food service|merchandising|guest)\b/i],
  ["Education & Training", /\b(teacher|tutor|curriculum|instructional|education|admissions|student|learning)\b/i],
  ["Administrative", /\b(administrative|assistant|receptionist|office manager|coordinator|executive assistant)\b/i],
  ["Design & Product", /\b(product manager|product designer|ux|ui|visual designer|researcher|design)\b/i],
  ["Data & Analytics", /\b(data analyst|business analyst|analytics|bi analyst|research analyst|data scientist|insights|reporting)\b/i],
  ["Software & IT", /\b(software engineer|software developer|developer|frontend|backend|fullstack|full-stack|ios|android|devops|sre|security engineer|data engineer|machine learning|infrastructure engineer|cloud engineer|platform engineer|site reliability|systems engineer|web engineer|mobile engineer)\b/i],
  ["Manufacturing & Field Work", /\b(manufacturing|production|technician|mechanic|maintenance|field service|facilities|quality control|quality assurance|safety|construction|hvac|electrical)\b/i]
];

const roleCategoryRules = [
  ["Sales & Business Development", /\b(sales|account executive|business development|commercial|territory|partnerships?|revenue|customer growth)\b/i],
  ["Customer Support & Success", /\b(customer support|customer success|support specialist|client success|implementation|solutions consultant|technical support|call center)\b/i],
  ["Operations & Logistics", /\b(operations|logistics|supply chain|warehouse|driver|dispatch|fulfillment|procurement|fleet|inventory)\b/i],
  ["Manufacturing & Field Work", /\b(manufacturing|production|technician|mechanic|maintenance|field service|facilities|quality control|quality assurance|safety|construction|hvac|electrical)\b/i],
  ["Healthcare & Clinical", /\b(clinical|nurse|rn|medical|patient|healthcare|therapist|pharmacy|behavioral health|billing|care coordinator)\b/i],
  ["Retail & Hospitality", /\b(retail|store|restaurant|hospitality|barista|cook|kitchen|food service|merchandising|guest)\b/i],
  ["Marketing & Content", /\b(marketing|brand|content|copywriter|seo|social media|communications|growth|demand generation|events)\b/i],
  ["Finance & Accounting", /\b(finance|accounting|bookkeeper|payroll|tax|audit|fp&a|controller|treasury|underwriting|claims|insurance)\b/i],
  ["HR & Recruiting", /\b(recruit|talent|human resources|people operations|hrbp|compensation|benefits|learning and development)\b/i],
  ["Legal & Compliance", /\b(legal|counsel|paralegal|compliance|policy|privacy|risk|regulatory)\b/i],
  ["Education & Training", /\b(teacher|tutor|curriculum|instructional|education|admissions|student|learning)\b/i],
  ["Design & Product", /\b(product manager|product designer|ux|ui|visual designer|researcher|design)\b/i],
  ["Data & Analytics", /\b(data analyst|business analyst|analytics|bi analyst|research analyst|data scientist|insights|reporting)\b/i],
  ["Software & IT", /\b(software engineer|software developer|developer|frontend|backend|fullstack|full-stack|ios|android|devops|sre|security engineer|data engineer|machine learning|infrastructure engineer|cloud engineer|platform engineer|site reliability|systems engineer|web engineer|mobile engineer)\b/i],
  ["Administrative", /\b(administrative|assistant|receptionist|office manager|coordinator|executive assistant)\b/i]
];

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function hasSkill(haystack, skill) {
  if (skill === "Go") {
    return /\b(golang|go programming|programming in go|go language|experience (with|in) go|proficiency (with|in) go)\b/i.test(haystack);
  }

  if (skill === "HR") {
    return /\b(hrbp|human resources|hr operations|hr coordinator|hr manager)\b/i.test(haystack);
  }

  const escaped = escapeRegExp(skill.toLowerCase());
  if (/^[a-z0-9+#.]{1,3}$/i.test(skill)) {
    return new RegExp(`(^|[^a-z0-9+#.])${escaped}([^a-z0-9+#.]|$)`, "i").test(haystack);
  }

  return new RegExp(`(^|[^a-z0-9+#.])${escaped}([^a-z0-9+#.]|$)`, "i").test(haystack);
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

function decodeEntities(text) {
  let decoded = text;
  for (let index = 0; index < 3; index += 1) {
    decoded = decoded
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&mdash;/gi, " - ")
    .replace(/&ndash;/gi, " - ")
    .replace(/&bull;/gi, "-")
    .replace(/&quot;/gi, "\"")
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/gi, "'")
    .replace(/&#x2F;/gi, "/")
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number.parseInt(code, 10)));
  }
  return decoded;
}

function stripHTML(html = "") {
  return decodeEntities(html)
    .replace(/<\/(li|p|h1|h2|h3|h4|div)>/gi, "\n")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<li[^>]*>/gi, "\n- ")
    .replace(/<[^>]+>/g, " ")
    .replace(/\u00a0/g, " ")
    .replace(/[ \t]+/g, " ")
    .replace(/\n[ \t]+/g, "\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function cleanLine(line) {
  return line
    .replace(/^[-•*]\s*/, "")
    .replace(/&nbsp;/gi, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function firstSentence(text) {
  const cleaned = cleanLine(text)
    .replace(/^(About the team|About the role|The role|Who we are|What you'll do)[:\s-]*/i, "");
  const sentence = cleaned.match(/^.{80,260}?[.!?](\s|$)/)?.[0] ?? cleaned.slice(0, 240);
  return sentence.trim();
}

function summarize(text, title) {
  const lines = text.split(/\n+/).map(cleanLine).filter(Boolean);
  const blocked = /(equal opportunity|accommodation|privacy notice|candidate privacy|background check|fair chance|eeo|benefits|compensation|salary range)/i;
  const candidate = lines.find((line) =>
    line.length >= 90 &&
    line.length <= 420 &&
    !blocked.test(line) &&
    !line.toLowerCase().includes("about ")
  );
  return firstSentence(candidate ?? `${title}. Review the source job page for the full description and application details.`);
}

function extractSalary(text) {
  const compact = text.replace(/\s+/g, " ");
  const patterns = [
    /\$\s?\d{2,3}(?:,\d{3})?\s?(?:k|K)?\s?[-–—to]+\s?\$?\s?\d{2,3}(?:,\d{3})?\s?(?:k|K)?(?:\s?(?:per year|annually|\/year|yr|USD))?/,
    /\$\s?\d{2,3}(?:\.\d{1,2})?\s?[-–—to]+\s?\$?\s?\d{2,3}(?:\.\d{1,2})?\s?(?:\/hour|per hour|hourly|hr)/i,
    /(?:salary|compensation|pay) range[^.]{0,120}\$\s?\d{2,3}(?:,\d{3})?[^.]{0,80}/i
  ];

  for (const pattern of patterns) {
    const match = compact.match(pattern);
    if (match) return match[0].replace(/\s+/g, " ").trim();
  }

  return "Not listed";
}

function formatPayInputRanges(ranges) {
  if (!Array.isArray(ranges) || ranges.length === 0) return null;
  const range = ranges.find((item) => item.min_cents || item.max_cents) ?? ranges[0];
  const currency = range.currency_type ?? "USD";
  const divisor = currency === "USD" ? 100 : 100;
  const min = Number.isFinite(range.min_cents) ? Math.round(range.min_cents / divisor).toLocaleString("en-US") : null;
  const max = Number.isFinite(range.max_cents) ? Math.round(range.max_cents / divisor).toLocaleString("en-US") : null;
  const prefix = currency === "USD" ? "$" : `${currency} `;

  if (min && max) return `${prefix}${min} - ${prefix}${max}`;
  if (min) return `${prefix}${min}+`;
  if (max) return `Up to ${prefix}${max}`;
  return null;
}

function extractContactEmail(text) {
  const emails = [...text.matchAll(/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi)].map((match) => match[0].toLowerCase());
  const blocked = /(^name@|^jsmith@|^john@|^jane@|example|privacy|legal|security|abuse|support|press|investor|accommodation|accessibility|no-?reply|donotreply|^eoe@|^eeo@|accessibleinterviewing)/i;
  const allowed = /(career|careers|job|jobs|recruit|recruiting|talent|people|hr|hiring)/i;

  for (const email of [...new Set(emails)]) {
    if (blocked.test(email)) continue;
    const index = text.toLowerCase().indexOf(email);
    const context = index >= 0 ? text.slice(Math.max(0, index - 120), index + email.length + 120) : "";
    if (allowed.test(email) || allowed.test(context)) return email;
  }

  return null;
}

function extractRequirements(text) {
  const lines = text.split(/\n+/).map(cleanLine).filter((line) => line.length >= 25 && line.length <= 220);
  const headingIndex = lines.findIndex((line) =>
    /^(requirements|qualifications|minimum qualifications|preferred qualifications|what you.ll need|what we.re looking for|what you.ll bring|you have|about you|who you are|you might be a fit if)/i.test(line)
  );

  const blocked = /(equal opportunity|privacy|accommodation|benefits|compensation|salary|apply|background check)/i;
  let pool = headingIndex >= 0 ? lines.slice(headingIndex + 1, headingIndex + 12) : lines;
  let requirements = pool
    .filter((line) => !blocked.test(line))
    .filter((line) => /(experience|ability|proficiency|knowledge|familiar|skill|degree|years|understanding|communication|manage|build|design|develop|lead|work)/i.test(line))
    .slice(0, 6);

  if (requirements.length < 2) {
    requirements = lines
      .filter((line) => !blocked.test(line))
      .filter((line) => /(experience|ability|proficiency|knowledge|familiar|skill|degree|years)/i.test(line))
      .slice(0, 6);
  }

  return [...new Set(requirements)].map((line) => line.replace(/\.$/, "")).slice(0, 6);
}

function extractTags(title, text) {
  const haystack = `${title} ${text}`.toLowerCase();
  const tags = skillDictionary.filter((skill) => hasSkill(haystack, skill));
  if (/remote/i.test(text)) tags.push("Remote");
  if (/hybrid/i.test(text)) tags.push("Hybrid");
  return [...new Set(tags)].slice(0, 10);
}

function inferRoleCategory(title, text) {
  const titleCategory = titlePriorityRules.find(([, pattern]) => pattern.test(title))?.[0]
    ?? roleCategoryRules.find(([, pattern]) => pattern.test(title))?.[0];
  if (titleCategory) return titleCategory;

  return roleCategoryRules.find(([, pattern]) => pattern.test(text))?.[0] ?? "General";
}

function detectRemoteType(location, text) {
  const combined = `${location} ${text}`.toLowerCase();
  if (combined.includes("hybrid")) return "Hybrid";
  if (combined.includes("remote")) return "Remote";
  return "On-site";
}

function detectVisaFriendly(text) {
  const lower = text.toLowerCase();
  if (/(unable to sponsor|not sponsor|does not sponsor|do not sponsor|cannot sponsor)/.test(lower)) return false;
  return /(visa sponsorship|sponsor.*visa|h-1b|h1b|opt|cpt)/.test(lower);
}

function postedDaysAgo(dateText) {
  const date = dateText ? new Date(dateText) : new Date();
  if (Number.isNaN(date.getTime())) return 0;
  return Math.max(0, Math.floor((Date.now() - date.getTime()) / 86_400_000));
}

function normalizeGreenhouseJob(job, board) {
  const text = stripHTML(job.content ?? "");
  const location = job.location?.name ?? "Not listed";
  const sourceURL = job.absolute_url;
  const roleCategory = inferRoleCategory(job.title ?? "", text);
  const tags = extractTags(job.title ?? "", text);
  if (roleCategory !== "General") tags.unshift(roleCategory);

  return {
    _greenhouseBoard: board,
    _greenhouseJobId: job.id,
    id: stableUUID(sourceURL),
    company: job.company_name || "Unknown company",
    title: job.title || "Untitled role",
    city: location,
    remoteType: detectRemoteType(location, text),
    salary: extractSalary(text),
    tags: [...new Set(tags)].slice(0, 10),
    sourceURL,
    sourcePlatform: "greenhouse",
    sourceBoard: board,
    sourceJobId: String(job.id),
    roleCategory,
    contactEmail: extractContactEmail(text),
    summary: summarize(text, job.title ?? "Open role"),
    requirements: extractRequirements(text),
    visaFriendly: detectVisaFriendly(text),
    postedDaysAgo: postedDaysAgo(job.first_published ?? job.updated_at)
  };
}

function normalizeAshbyLocation(job) {
  if (job.location) return job.location;

  const address = job.address?.postalAddress;
  if (!address) return "Not listed";

  return [
    address.addressLocality,
    address.addressRegion,
    address.addressCountry
  ].filter(Boolean).join(", ") || "Not listed";
}

function normalizeAshbyJob(job, board) {
  const text = stripHTML(job.descriptionHtml ?? job.descriptionPlain ?? "");
  const location = normalizeAshbyLocation(job);
  const sourceURL = job.jobUrl;
  const roleCategory = inferRoleCategory(job.title ?? "", `${job.department ?? ""} ${job.team ?? ""} ${text}`);
  const tags = extractTags(job.title ?? "", `${job.department ?? ""} ${job.team ?? ""} ${text}`);
  if (roleCategory !== "General") tags.unshift(roleCategory);

  return {
    id: stableUUID(sourceURL),
    company: board.company || board.slug || "Unknown company",
    title: job.title || "Untitled role",
    city: location,
    remoteType: job.isRemote ? "Remote" : detectRemoteType(`${location} ${job.workplaceType ?? ""}`, text),
    salary: extractSalary(text),
    tags: [...new Set(tags)].slice(0, 10),
    sourceURL,
    sourcePlatform: "ashby",
    sourceBoard: board.slug,
    sourceJobId: String(job.id),
    roleCategory,
    contactEmail: extractContactEmail(text),
    summary: summarize(text, job.title ?? "Open role"),
    requirements: extractRequirements(text),
    visaFriendly: detectVisaFriendly(text),
    postedDaysAgo: postedDaysAgo(job.publishedAt)
  };
}

function extractClassText(html, className) {
  const pattern = new RegExp(`<[^>]+class="[^"]*${className}[^"]*"[^>]*>([\\s\\S]*?)<\\/[^>]+>`, "i");
  const match = html.match(pattern);
  return match ? cleanLine(stripHTML(match[1]).replace(/\u2014/g, " ")) : "";
}

function extractLeverBoardPostings(html, board) {
  const parts = html.split('<div class="posting" data-qa-posting-id=').slice(1);
  const postings = [];

  for (const part of parts) {
    const id = part.match(/^"([^"]+)"/)?.[1];
    const title = stripHTML(part.match(/<h5[^>]*data-qa="posting-name"[^>]*>([\s\S]*?)<\/h5>/i)?.[1] ?? "");
    const sourceURL = part.match(/<a[^>]+class="posting-title"[^>]+href="([^"]+)"/i)?.[1]
      ?? part.match(/<a[^>]+href="([^"]+)"[^>]+class="[^"]*posting-btn-submit/i)?.[1];
    const location = extractClassText(part, "location");
    const commitment = extractClassText(part, "commitment");
    const workplaceType = extractClassText(part, "workplaceTypes").replace(/\s+[-–—]\s*$/, "");

    if (!id || !title || !sourceURL) continue;

    postings.push({
      id,
      title,
      sourceURL,
      location: location || "Not listed",
      commitment,
      workplaceType,
      company: board.company
    });
  }

  return postings;
}

function normalizeLeverJob(posting, board, detailHTML) {
  const text = stripHTML(detailHTML);
  const roleCategory = inferRoleCategory(posting.title, text);
  const tags = extractTags(posting.title, text);
  if (roleCategory !== "General") tags.unshift(roleCategory);
  if (posting.commitment) tags.push(posting.commitment);
  if (posting.workplaceType) tags.push(posting.workplaceType);

  return {
    id: stableUUID(posting.sourceURL),
    company: posting.company || board.company || board.slug || "Unknown company",
    title: posting.title || "Untitled role",
    city: posting.location || "Not listed",
    remoteType: detectRemoteType(`${posting.location ?? ""} ${posting.workplaceType ?? ""}`, text),
    salary: extractSalary(text),
    tags: [...new Set(tags)].slice(0, 10),
    sourceURL: posting.sourceURL,
    sourcePlatform: "lever",
    sourceBoard: board.slug,
    sourceJobId: String(posting.id),
    roleCategory,
    contactEmail: extractContactEmail(text),
    summary: summarize(text, posting.title ?? "Open role"),
    requirements: extractRequirements(text),
    visaFriendly: detectVisaFriendly(text),
    postedDaysAgo: 0
  };
}

function normalizeSmartRecruitersLocation(location = {}) {
  return location.fullLocation
    || [location.city, location.region, location.country].filter(Boolean).join(", ")
    || "Not listed";
}

function smartRecruitersJobText(job) {
  const sections = job.jobAd?.sections ?? {};
  const sectionText = Object.values(sections)
    .map((section) => typeof section === "string"
      ? section
      : `${section?.title ?? ""}\n${section?.text ?? ""}`)
    .filter(Boolean)
    .join("\n\n");

  return stripHTML([
    sectionText,
    job.industry?.label,
    job.function?.label,
    job.department?.label,
    job.typeOfEmployment?.label,
    job.experienceLevel?.label
  ].filter(Boolean).join("\n"));
}

function normalizeSmartRecruitersJob(job, board) {
  const title = job.name || job.title || "Untitled role";
  const location = normalizeSmartRecruitersLocation(job.location);
  const text = smartRecruitersJobText(job);
  const context = `${job.department?.label ?? ""} ${job.function?.label ?? ""} ${job.industry?.label ?? ""} ${text}`;
  const sourceURL = job.postingUrl
    || `https://jobs.smartrecruiters.com/${encodeURIComponent(board.slug)}/${encodeURIComponent(job.id)}`;
  const roleCategory = inferRoleCategory(title, context);
  const tags = extractTags(title, context);
  if (roleCategory !== "General") tags.unshift(roleCategory);
  if (job.typeOfEmployment?.label) tags.push(job.typeOfEmployment.label);
  if (job.experienceLevel?.label) tags.push(job.experienceLevel.label);

  return {
    id: stableUUID(sourceURL),
    company: job.company?.name || board.company || board.slug || "Unknown company",
    title,
    city: location,
    remoteType: job.location?.remote
      ? "Remote"
      : job.location?.hybrid
        ? "Hybrid"
        : detectRemoteType(location, text),
    salary: extractSalary(text),
    tags: [...new Set(tags)].slice(0, 10),
    sourceURL,
    sourcePlatform: "smartrecruiters",
    sourceBoard: board.slug,
    sourceJobId: String(job.id),
    roleCategory,
    contactEmail: extractContactEmail(text),
    summary: summarize(text, title),
    requirements: extractRequirements(text),
    visaFriendly: detectVisaFriendly(text),
    postedDaysAgo: postedDaysAgo(job.releasedDate ?? job.updatedDate)
  };
}

function recruiteeTranslation(offer) {
  const translations = offer.translations ?? {};
  return translations.en
    ?? translations["en-US"]
    ?? translations["en-GB"]
    ?? Object.values(translations)[0]
    ?? {};
}

function recruiteeOfferText(offer) {
  const translation = recruiteeTranslation(offer);
  return stripHTML([
    translation.description,
    translation.requirements,
    offer.description,
    offer.requirements,
    offer.department,
    offer.kind,
    offer.location
  ].filter(Boolean).join("\n\n"));
}

function normalizeRecruiteeLocation(offer) {
  const parts = [
    offer.city,
    offer.state_code,
    offer.country_code ?? offer.country,
    offer.location
  ].filter(Boolean);
  return [...new Set(parts)].join(", ") || "Not listed";
}

function normalizeRecruiteeJob(offer, board) {
  const translation = recruiteeTranslation(offer);
  const title = translation.title || offer.title || offer.name || "Untitled role";
  const text = recruiteeOfferText(offer);
  const location = normalizeRecruiteeLocation(offer);
  const sourceURL = offer.careers_url
    || offer.url
    || `https://${board.slug}.recruitee.com/o/${encodeURIComponent(offer.slug ?? offer.id)}`;
  const roleCategory = inferRoleCategory(title, `${offer.department ?? ""} ${offer.kind ?? ""} ${text}`);
  const tags = extractTags(title, `${offer.department ?? ""} ${offer.kind ?? ""} ${text}`);
  if (roleCategory !== "General") tags.unshift(roleCategory);
  if (offer.kind) tags.push(offer.kind);
  if (offer.department) tags.push(offer.department);

  return {
    id: stableUUID(sourceURL),
    company: offer.company_name || board.company || board.slug || "Unknown company",
    title,
    city: location,
    remoteType: detectRemoteType(location, `${offer.location ?? ""} ${text}`),
    salary: extractSalary(text),
    tags: [...new Set(tags)].slice(0, 10),
    sourceURL,
    sourcePlatform: "recruitee",
    sourceBoard: board.slug,
    sourceJobId: String(offer.id ?? offer.slug),
    roleCategory,
    contactEmail: extractContactEmail(text),
    summary: summarize(text, title),
    requirements: extractRequirements(text),
    visaFriendly: detectVisaFriendly(text),
    postedDaysAgo: postedDaysAgo(offer.published_at ?? offer.created_at)
  };
}

async function fetchGreenhouseBoard(board) {
  const url = `https://boards-api.greenhouse.io/v1/boards/${encodeURIComponent(board)}/jobs?content=true`;
  const response = await fetch(url, {
    headers: {
      "accept": "application/json",
      "user-agent": "JobPilotLiteMVP/0.1 public job board indexing"
    },
    signal: AbortSignal.timeout(20_000)
  });

  if (!response.ok) throw new Error(`${board}: ${response.status}`);
  const data = await response.json();
  return Array.isArray(data.jobs) ? data.jobs.map((job) => normalizeGreenhouseJob(job, board)) : [];
}

async function fetchAshbyBoard(board) {
  const url = `https://api.ashbyhq.com/posting-api/job-board/${encodeURIComponent(board.slug)}`;
  const response = await fetch(url, {
    headers: {
      "accept": "application/json",
      "user-agent": "JobPilotLiteMVP/0.1 public job board indexing"
    },
    signal: AbortSignal.timeout(20_000)
  });

  if (!response.ok) throw new Error(`${board.slug}: ${response.status}`);
  const data = await response.json();
  const jobs = Array.isArray(data.jobs) ? data.jobs.filter((job) => job.isListed !== false) : [];
  const company = board.company || data.name || data.companyName || data.organizationName || board.slug;
  return jobs.map((job) => normalizeAshbyJob(job, { ...board, company }));
}

async function fetchLeverDetail(posting) {
  const response = await fetch(posting.sourceURL, {
    headers: {
      "accept": "text/html,application/xhtml+xml",
      "user-agent": "JobPilotLiteMVP/0.1 public job board indexing"
    },
    signal: AbortSignal.timeout(20_000)
  });

  if (!response.ok) throw new Error(`${posting.sourceURL}: ${response.status}`);
  return response.text();
}

async function fetchLeverBoard(board) {
  const url = `https://jobs.lever.co/${encodeURIComponent(board.slug)}`;
  const response = await fetch(url, {
    headers: {
      "accept": "text/html,application/xhtml+xml",
      "user-agent": "JobPilotLiteMVP/0.1 public job board indexing"
    },
    signal: AbortSignal.timeout(20_000)
  });

  if (!response.ok) throw new Error(`${board.slug}: ${response.status}`);

  const html = await response.text();
  const postingLimit = Number.parseInt(process.env.JOB_FETCH_LEVER_POSTING_LIMIT ?? "0", 10);
  const allPostings = extractLeverBoardPostings(html, board);
  const postings = postingLimit > 0 ? allPostings.slice(0, postingLimit) : allPostings;
  const batchSize = Number.parseInt(process.env.JOB_FETCH_LEVER_BATCH_SIZE ?? "8", 10);
  const jobs = [];

  for (let index = 0; index < postings.length; index += batchSize) {
    const batch = postings.slice(index, index + batchSize);
    const results = await Promise.all(batch.map(async (posting) => {
      try {
        const detailHTML = await fetchLeverDetail(posting);
        return normalizeLeverJob(posting, board, detailHTML);
      } catch {
        return null;
      }
    }));
    jobs.push(...results.filter(Boolean));
  }

  return jobs;
}

async function fetchSmartRecruitersBoard(board) {
  const postingLimit = Number.parseInt(process.env.JOB_FETCH_SMARTRECRUITERS_POSTING_LIMIT ?? "100", 10);
  const pageSize = Math.max(1, Math.min(100, postingLimit || 100));
  const jobs = [];

  for (let offset = 0; offset < Math.max(1, postingLimit); offset += pageSize) {
    const url = `https://api.smartrecruiters.com/v1/companies/${encodeURIComponent(board.slug)}/postings?limit=${pageSize}&offset=${offset}`;
    const response = await fetch(url, {
      headers: {
        "accept": "application/json",
        "user-agent": "JobPilotLiteMVP/0.1 public job board indexing"
      },
      signal: AbortSignal.timeout(20_000)
    });

    if (!response.ok) throw new Error(`${board.slug}: ${response.status}`);
    const data = await response.json();
    const postings = Array.isArray(data.content)
      ? data.content.filter((job) => job.visibility !== "PRIVATE")
      : [];
    jobs.push(...postings.map((job) => normalizeSmartRecruitersJob(job, board)));

    if (postings.length < pageSize || jobs.length >= postingLimit || jobs.length >= Number(data.totalFound ?? jobs.length)) {
      break;
    }
  }

  return jobs.slice(0, Math.max(0, postingLimit));
}

async function fetchRecruiteeBoard(board) {
  const postingLimit = Number.parseInt(process.env.JOB_FETCH_RECRUITEE_POSTING_LIMIT ?? "200", 10);
  const url = `https://${board.slug}.recruitee.com/api/offers/`;
  const response = await fetch(url, {
    headers: {
      "accept": "application/json",
      "user-agent": "JobPilotLiteMVP/0.1 public job board indexing"
    },
    signal: AbortSignal.timeout(20_000)
  });

  if (!response.ok) throw new Error(`${board.slug}: ${response.status}`);
  const data = await response.json();
  const offers = Array.isArray(data)
    ? data
    : Array.isArray(data.offers)
      ? data.offers
      : Array.isArray(data.result)
        ? data.result
        : [];

  return offers
    .filter((offer) => offer && offer.status !== "closed")
    .slice(0, Math.max(0, postingLimit))
    .map((offer) => normalizeRecruiteeJob(offer, board));
}

async function fetchGreenhousePayRange(job) {
  if (!job._greenhouseBoard || !job._greenhouseJobId) return null;
  const url = `https://boards-api.greenhouse.io/v1/boards/${encodeURIComponent(job._greenhouseBoard)}/jobs/${encodeURIComponent(job._greenhouseJobId)}?pay_transparency=true`;
  const response = await fetch(url, {
    headers: {
      "accept": "application/json",
      "user-agent": "JobPilotLiteMVP/0.1 public job board indexing"
    },
    signal: AbortSignal.timeout(Number.parseInt(process.env.JOB_FETCH_PAY_TIMEOUT_MS ?? "8000", 10))
  });

  if (!response.ok) return null;
  const data = await response.json();
  return formatPayInputRanges(data.pay_input_ranges);
}

async function hydrateMissingSalary(jobs) {
  const missing = jobs.filter((job) => job.salary === "Not listed" && job._greenhouseBoard && job._greenhouseJobId);
  const batchSize = Number.parseInt(process.env.JOB_FETCH_PAY_BATCH_SIZE ?? "48", 10);
  let hydrated = 0;

  for (let index = 0; index < missing.length; index += batchSize) {
    const batch = missing.slice(index, index + batchSize);
    const ranges = await Promise.all(batch.map((job) => fetchGreenhousePayRange(job).catch(() => null)));

    ranges.forEach((range, rangeIndex) => {
      if (range) {
        batch[rangeIndex].salary = range;
        hydrated += 1;
      }
    });
  }

  return hydrated;
}

const allJobs = [];
const seen = new Set();

if (sourceEnabled("greenhouse")) {
  for (const board of greenhouseBoards) {
    try {
      const jobs = await fetchGreenhouseBoard(board);
      let added = 0;

      for (const job of jobs) {
        if (!job.sourceURL || seen.has(job.sourceURL)) continue;
        if (!job.tags.length) job.tags = ["General"];
        seen.add(job.sourceURL);
        allJobs.push(job);
        added += 1;
      }

      console.error(`${board}: ${added} jobs`);
      sourceReports.push({
        platform: "greenhouse",
        board,
        company: jobs[0]?.company ?? null,
        status: added > 0 ? "active" : "empty",
        jobCount: added
      });
    } catch (error) {
      console.error(`${board}: skipped (${error.message})`);
      sourceReports.push({
        platform: "greenhouse",
        board,
        company: null,
        status: "failed",
        jobCount: 0,
        error: error.message
      });
    }

  }
}

if (sourceEnabled("ashby")) {
  for (const board of ashbyBoards) {
    try {
      const jobs = await fetchAshbyBoard(board);
      let added = 0;

      for (const job of jobs) {
        if (!job.sourceURL || seen.has(job.sourceURL)) continue;
        if (!job.tags.length) job.tags = ["General"];
        seen.add(job.sourceURL);
        allJobs.push(job);
        added += 1;
      }

      console.error(`${board.slug}: ${added} jobs`);
      sourceReports.push({
        platform: "ashby",
        board: board.slug,
        company: jobs[0]?.company ?? board.company ?? null,
        status: added > 0 ? "active" : "empty",
        jobCount: added
      });
    } catch (error) {
      console.error(`${board.slug}: skipped (${error.message})`);
      sourceReports.push({
        platform: "ashby",
        board: board.slug,
        company: board.company ?? null,
        status: "failed",
        jobCount: 0,
        error: error.message
      });
    }
  }
}

if (sourceEnabled("lever")) {
  for (const board of leverBoards) {
    try {
      const jobs = await fetchLeverBoard(board);
      let added = 0;

      for (const job of jobs) {
        if (!job.sourceURL || seen.has(job.sourceURL)) continue;
        if (!job.tags.length) job.tags = ["General"];
        seen.add(job.sourceURL);
        allJobs.push(job);
        added += 1;
      }

      console.error(`${board.slug}: ${added} jobs`);
      sourceReports.push({
        platform: "lever",
        board: board.slug,
        company: jobs[0]?.company ?? board.company ?? null,
        status: added > 0 ? "active" : "empty",
        jobCount: added
      });
    } catch (error) {
      console.error(`${board.slug}: skipped (${error.message})`);
      sourceReports.push({
        platform: "lever",
        board: board.slug,
        company: board.company ?? null,
        status: "failed",
        jobCount: 0,
        error: error.message
      });
    }
  }
}

if (sourceEnabled("smartrecruiters")) {
  for (const board of smartRecruitersBoards) {
    try {
      const jobs = await fetchSmartRecruitersBoard(board);
      let added = 0;

      for (const job of jobs) {
        if (!job.sourceURL || seen.has(job.sourceURL)) continue;
        if (!job.tags.length) job.tags = ["General"];
        seen.add(job.sourceURL);
        allJobs.push(job);
        added += 1;
      }

      console.error(`${board.slug}: ${added} jobs`);
      sourceReports.push({
        platform: "smartrecruiters",
        board: board.slug,
        company: jobs[0]?.company ?? board.company ?? null,
        status: added > 0 ? "active" : "empty",
        jobCount: added
      });
    } catch (error) {
      console.error(`${board.slug}: skipped (${error.message})`);
      sourceReports.push({
        platform: "smartrecruiters",
        board: board.slug,
        company: board.company ?? null,
        status: "failed",
        jobCount: 0,
        error: error.message
      });
    }
  }
}

if (sourceEnabled("recruitee")) {
  for (const board of recruiteeBoards) {
    try {
      const jobs = await fetchRecruiteeBoard(board);
      let added = 0;

      for (const job of jobs) {
        if (!job.sourceURL || seen.has(job.sourceURL)) continue;
        if (!job.tags.length) job.tags = ["General"];
        seen.add(job.sourceURL);
        allJobs.push(job);
        added += 1;
      }

      console.error(`${board.slug}: ${added} jobs`);
      sourceReports.push({
        platform: "recruitee",
        board: board.slug,
        company: jobs[0]?.company ?? board.company ?? null,
        status: added > 0 ? "active" : "empty",
        jobCount: added
      });
    } catch (error) {
      console.error(`${board.slug}: skipped (${error.message})`);
      sourceReports.push({
        platform: "recruitee",
        board: board.slug,
        company: board.company ?? null,
        status: "failed",
        jobCount: 0,
        error: error.message
      });
    }
  }
}

function qualityScore(job) {
  let score = 0;
  if (job.salary !== "Not listed") score += 50;
  if (job.contactEmail) score += 80;
  score += Math.min(job.requirements.length * 4, 20);
  score += Math.max(0, 30 - job.postedDaysAgo);
  return score;
}

function selectDiverseJobs(jobs, targetLimit) {
  const sortedJobs = jobs.toSorted((a, b) => qualityScore(b) - qualityScore(a) || a.postedDaysAgo - b.postedDaysAgo);
  const categories = [...new Set(sortedJobs.map((job) => job.roleCategory ?? "General"))];
  const categoryTarget = Math.max(80, Math.ceil(targetLimit / Math.max(categories.length, 1)));
  const hardCategoryLimits = new Map([
    ["Software & IT", Math.ceil(targetLimit * 0.45)],
    ["Data & Analytics", Math.ceil(targetLimit * 0.16)]
  ]);
  const passes = [
    { companyLimit: Math.max(80, Math.ceil(targetLimit / 35)), categoryLimit: categoryTarget },
    { companyLimit: Math.max(160, Math.ceil(targetLimit / 18)), categoryLimit: categoryTarget * 2 },
    { companyLimit: Math.max(300, Math.ceil(targetLimit / 10)), categoryLimit: categoryTarget * 4 },
    { companyLimit: Number.POSITIVE_INFINITY, categoryLimit: Number.POSITIVE_INFINITY }
  ];

  const selected = [];
  const selectedURLs = new Set();
  const companyCounts = new Map();
  const categoryCounts = new Map();

  function tryAdd(job, pass, enforceHardLimit) {
    if (selectedURLs.has(job.sourceURL)) return false;

    const company = job.company || "Unknown company";
    const category = job.roleCategory ?? "General";
    const companyCount = companyCounts.get(company) ?? 0;
    const categoryCount = categoryCounts.get(category) ?? 0;
    const hardCategoryLimit = hardCategoryLimits.get(category) ?? Number.POSITIVE_INFINITY;

    if (companyCount >= pass.companyLimit) return false;
    if (categoryCount >= pass.categoryLimit) return false;
    if (enforceHardLimit && categoryCount >= hardCategoryLimit) return false;

    selected.push(job);
    selectedURLs.add(job.sourceURL);
    companyCounts.set(company, companyCount + 1);
    categoryCounts.set(category, categoryCount + 1);
    return true;
  }

  for (const pass of passes) {
    for (const job of sortedJobs) {
      if (selected.length >= targetLimit) return selected;
      tryAdd(job, pass, true);
    }
  }

  for (const job of sortedJobs) {
    if (selected.length >= targetLimit) return selected;
    tryAdd(job, { companyLimit: Number.POSITIVE_INFINITY, categoryLimit: Number.POSITIVE_INFINITY }, false);
  }

  if (selected.length < targetLimit) {
    for (const job of sortedJobs) {
      if (selected.length >= targetLimit) return selected;
      if (selectedURLs.has(job.sourceURL)) continue;
      selected.push(job);
      selectedURLs.add(job.sourceURL);
    }
  }

  return selected;
}

allJobs.sort((a, b) => qualityScore(b) - qualityScore(a) || a.postedDaysAgo - b.postedDaysAgo);
const selected = selectDiverseJobs(allJobs, limit);
const hydratedSalary = await hydrateMissingSalary(selected);
const outputJobs = selected.map((job) => {
  const { _greenhouseBoard, _greenhouseJobId, ...publicJob } = job;
  return publicJob;
});

fs.writeFileSync(output, `${JSON.stringify(outputJobs, null, 2)}\n`);
writeSourceHealth(sourceReports);
console.error(`Wrote ${outputJobs.length} jobs to ${output}`);
console.error(`Wrote source health to ${sourceHealthPath}`);
console.error(`Salary listed: ${outputJobs.filter((job) => job.salary !== "Not listed").length} (${hydratedSalary} hydrated from pay transparency endpoint)`);
console.error(`Recruiting email listed: ${outputJobs.filter((job) => job.contactEmail).length}`);
