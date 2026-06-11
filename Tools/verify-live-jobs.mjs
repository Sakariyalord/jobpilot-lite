import fs from "node:fs";

const input = process.argv[2] ?? "JobPilotLite/SeedJobs.json";
const output = process.argv[3] ?? input;
const limit = Number.parseInt(process.argv[4] ?? "0", 10);
const reportPath = process.argv[5] ?? "Data/job-refresh-report.json";

const jobs = JSON.parse(fs.readFileSync(input, "utf8"));
const checkedAt = new Date().toISOString();
const concurrency = Number.parseInt(process.env.JOB_VERIFY_CONCURRENCY ?? "6", 10);
const timeoutMs = Number.parseInt(process.env.JOB_VERIFY_TIMEOUT_MS ?? "15000", 10);
const retryAttempts = Number.parseInt(process.env.JOB_VERIFY_RETRIES ?? "3", 10);
const ashbyBoardCache = new Map();

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isRetryableStatus(status) {
  return status === 408 || status === 429 || status >= 500;
}

function normalize(text = "") {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function titleNeedle(title = "") {
  return normalize(title).split(" ").filter((part) => part.length > 2).slice(0, 5).join(" ");
}

function looksClosed(text = "") {
  const lower = text.toLowerCase();
  const closedPatterns = [
    "job is no longer available",
    "no longer accepting applications",
    "this job is closed",
    "position has been filled",
    "position is no longer available",
    "job not found",
    "posting is no longer available",
    "opening is no longer available",
    "this opening is no longer accepting applications"
  ];

  return closedPatterns.some((pattern) => lower.includes(pattern));
}

function titleMatches(job, text) {
  const normalizedText = normalize(text);
  const needle = titleNeedle(job.title);
  if (!needle) return false;
  if (normalizedText.includes(needle)) return true;

  const titleParts = normalize(job.title).split(" ").filter((part) => part.length > 3);
  if (titleParts.length < 2) return false;
  const matched = titleParts.filter((part) => normalizedText.includes(part)).length;
  return matched >= Math.min(3, titleParts.length);
}

async function verifyReachableSourceURL(originalJob, candidateJob, report, startedAt, trustedLive) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(candidateJob.sourceURL, {
      redirect: "follow",
      signal: controller.signal,
      headers: {
        "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "user-agent": "JobPilotLiteMVP/0.1 public job verification"
      }
    });

    const text = await response.text();
    const reachable = response.ok && !looksClosed(text);
    const titleStillMatches = titleMatches(originalJob, text) || titleMatches(candidateJob, text);
    const isLive = reachable && (trustedLive || titleStillMatches);

    return {
      job: isLive ? {
        ...candidateJob,
        sourceURL: candidateJob.sourceURL,
        liveStatus: "live",
        lastVerifiedAt: checkedAt,
        verifiedSourceURL: response.url
      } : null,
      report: {
        ...report,
        finalURL: response.url,
        sourceURLStatus: response.status,
        live: isLive,
        reason: isLive
          ? `${report.reason}_source_url_live`
          : response.ok
            ? "source_url_closed_or_mismatch"
            : `source_url_http_${response.status}`,
        ms: Date.now() - startedAt
      }
    };
  } catch (error) {
    return {
      job: null,
      report: {
        ...report,
        live: false,
        reason: error.name === "AbortError" ? "source_url_timeout" : "source_url_network_error",
        error: error.message,
        ms: Date.now() - startedAt
      }
    };
  } finally {
    clearTimeout(timer);
  }
}

async function verifyGreenhouseJob(job) {
  if (job.sourcePlatform !== "greenhouse" || !job.sourceBoard || !job.sourceJobId) return null;

  const startedAt = Date.now();
  const apiURL = `https://boards-api.greenhouse.io/v1/boards/${encodeURIComponent(job.sourceBoard)}/jobs/${encodeURIComponent(job.sourceJobId)}`;
  let lastReport = null;

  for (let attempt = 1; attempt <= Math.max(1, retryAttempts); attempt += 1) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(apiURL, {
        signal: controller.signal,
        headers: {
          "accept": "application/json",
          "user-agent": "JobPilotLiteMVP/0.1 public job verification"
        }
      });

      if (!response.ok) {
        lastReport = {
          id: job.id,
          company: job.company,
          title: job.title,
          sourceURL: job.sourceURL,
          verificationURL: apiURL,
          status: response.status,
          live: false,
          reason: `greenhouse_api_${response.status}`,
          attempts: attempt,
          ms: Date.now() - startedAt
        };

        if (attempt < retryAttempts && isRetryableStatus(response.status)) {
          await sleep(350 * attempt);
          continue;
        }

        return {
          job: null,
          report: lastReport
        };
      }

      const payload = await response.json();
      const isLive = normalize(payload.title ?? "") === normalize(job.title) || titleMatches(job, payload.title ?? "");
      const finalURL = payload.absolute_url ?? job.sourceURL;
      const candidateJob = {
        ...job,
        sourceURL: finalURL,
        liveStatus: "live",
        lastVerifiedAt: checkedAt,
        verifiedSourceURL: finalURL
      };
      const report = {
        id: job.id,
        company: job.company,
        title: job.title,
        sourceURL: job.sourceURL,
        finalURL,
        verificationURL: apiURL,
        status: response.status,
        live: isLive,
        reason: isLive ? "greenhouse_api_live" : "greenhouse_title_mismatch",
        attempts: attempt,
        ms: Date.now() - startedAt
      };

      if (!isLive) return { job: null, report };
      return verifyReachableSourceURL(job, candidateJob, report, startedAt, true);
    } catch (error) {
      lastReport = {
        id: job.id,
        company: job.company,
        title: job.title,
        sourceURL: job.sourceURL,
        verificationURL: apiURL,
        live: false,
        reason: error.name === "AbortError" ? "greenhouse_api_timeout" : "greenhouse_api_network_error",
        error: error.message,
        attempts: attempt,
        ms: Date.now() - startedAt
      };

      if (attempt < retryAttempts) {
        await sleep(350 * attempt);
        continue;
      }

      return {
        job: null,
        report: lastReport
      };
    } finally {
      clearTimeout(timer);
    }
  }

  return { job: null, report: lastReport };
}

async function fetchAshbyBoardJobs(board) {
  if (ashbyBoardCache.has(board)) return ashbyBoardCache.get(board);

  const promise = (async () => {
    const apiURL = `https://api.ashbyhq.com/posting-api/job-board/${encodeURIComponent(board)}`;
    let lastError = null;

    for (let attempt = 1; attempt <= Math.max(1, retryAttempts); attempt += 1) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);

      try {
        const response = await fetch(apiURL, {
          signal: controller.signal,
          headers: {
            "accept": "application/json",
            "user-agent": "JobPilotLiteMVP/0.1 public job verification"
          }
        });

        if (!response.ok) {
          lastError = new Error(`ashby_api_${response.status}`);
          if (attempt < retryAttempts && isRetryableStatus(response.status)) {
            await sleep(350 * attempt);
            continue;
          }
          throw lastError;
        }

        const data = await response.json();
        return Array.isArray(data.jobs) ? data.jobs : [];
      } catch (error) {
        lastError = error;
        if (attempt < retryAttempts) {
          await sleep(350 * attempt);
          continue;
        }
      } finally {
        clearTimeout(timer);
      }
    }

    throw lastError ?? new Error("ashby_api_unknown_error");
  })();

  ashbyBoardCache.set(board, promise);
  return promise;
}

async function verifyAshbyJob(job) {
  if (job.sourcePlatform !== "ashby" || !job.sourceBoard || !job.sourceJobId) return null;

  const startedAt = Date.now();
  const apiURL = `https://api.ashbyhq.com/posting-api/job-board/${encodeURIComponent(job.sourceBoard)}`;

  try {
    const boardJobs = await fetchAshbyBoardJobs(job.sourceBoard);
    const payload = boardJobs.find((item) => String(item.id) === String(job.sourceJobId));
    const isLive = Boolean(payload) && payload.isListed !== false && titleMatches(job, payload.title ?? "");
    const finalURL = payload?.jobUrl ?? job.sourceURL;
    const candidateJob = {
      ...job,
      sourceURL: finalURL,
      liveStatus: "live",
      lastVerifiedAt: checkedAt,
      verifiedSourceURL: finalURL
    };
    const report = {
      id: job.id,
      company: job.company,
      title: job.title,
      sourceURL: job.sourceURL,
      finalURL,
      verificationURL: apiURL,
      status: payload ? 200 : 404,
      live: isLive,
      reason: isLive ? "ashby_api_live" : payload ? "ashby_title_mismatch" : "ashby_job_missing",
      ms: Date.now() - startedAt
    };

    if (!isLive) return { job: null, report };
    return verifyReachableSourceURL(job, candidateJob, report, startedAt, true);
  } catch (error) {
    return {
      job: null,
      report: {
        id: job.id,
        company: job.company,
        title: job.title,
        sourceURL: job.sourceURL,
        verificationURL: apiURL,
        live: false,
        reason: error.name === "AbortError" ? "ashby_api_timeout" : "ashby_api_network_error",
        error: error.message,
        ms: Date.now() - startedAt
      }
    };
  }
}

async function verifyJob(job) {
  const greenhouseResult = await verifyGreenhouseJob(job);
  if (greenhouseResult) return greenhouseResult;

  const ashbyResult = await verifyAshbyJob(job);
  if (ashbyResult) return ashbyResult;

  const startedAt = Date.now();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(job.sourceURL, {
      redirect: "follow",
      signal: controller.signal,
      headers: {
        "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "user-agent": "JobPilotLiteMVP/0.1 public job verification"
      }
    });

    const text = await response.text();
    const isLive = response.ok && !looksClosed(text) && titleMatches(job, text);

    return {
      job: isLive ? {
        ...job,
        liveStatus: "live",
        lastVerifiedAt: checkedAt,
        verifiedSourceURL: response.url
      } : null,
      report: {
        id: job.id,
        company: job.company,
        title: job.title,
        sourceURL: job.sourceURL,
        finalURL: response.url,
        status: response.status,
        live: isLive,
        reason: isLive ? "live" : response.ok ? "title_or_closed_text_mismatch" : `http_${response.status}`,
        ms: Date.now() - startedAt
      }
    };
  } catch (error) {
    return {
      job: null,
      report: {
        id: job.id,
        company: job.company,
        title: job.title,
        sourceURL: job.sourceURL,
        live: false,
        reason: error.name === "AbortError" ? "timeout" : "network_error",
        error: error.message,
        ms: Date.now() - startedAt
      }
    };
  } finally {
    clearTimeout(timer);
  }
}

async function verifyInBatches(items) {
  const liveJobs = [];
  const reports = [];
  let nextIndex = 0;

  async function worker(workerId) {
    while (nextIndex < items.length) {
      const currentIndex = nextIndex;
      nextIndex += 1;

      const result = await verifyJob(items[currentIndex]);
      reports[currentIndex] = result.report;
      if (result.job) liveJobs.push(result.job);

      if ((currentIndex + 1) % 100 === 0) {
        console.error(`verified ${currentIndex + 1}/${items.length}; live=${liveJobs.length}; worker=${workerId}`);
      }
    }
  }

  await Promise.all(Array.from({ length: Math.max(1, concurrency) }, (_, index) => worker(index + 1)));
  return { liveJobs, reports };
}

const { liveJobs, reports } = await verifyInBatches(jobs);
const selected = limit > 0 ? liveJobs.slice(0, limit) : liveJobs;

fs.mkdirSync("Data", { recursive: true });
fs.writeFileSync(output, `${JSON.stringify(selected, null, 2)}\n`);
fs.writeFileSync(reportPath, `${JSON.stringify({
  checkedAt,
  input,
  output,
  requestedLimit: limit || null,
  inputJobs: jobs.length,
  liveJobs: liveJobs.length,
  writtenJobs: selected.length,
  failedJobs: reports.filter((report) => !report.live).length,
  reports
}, null, 2)}\n`);

console.error(`Live jobs: ${liveJobs.length}/${jobs.length}`);
console.error(`Wrote ${selected.length} verified jobs to ${output}`);
console.error(`Wrote verification report to ${reportPath}`);
