# JobPilot Lite

JobPilot Lite is a free iOS MVP for validating a North America cross-industry job-search workflow in three weeks.

The first version avoids AI APIs, paid backend services, and complex crawling. It focuses on the shortest usable loop:

1. User fills a lightweight job profile.
2. App shows matching roles from a small bundled startup dataset, then refreshes larger verified job slices from static JSON when configured.
3. User opens a role, sees match reasons, and generates an ATS-friendly role-specific resume.
4. User edits and saves the resume and recruiter note inside the application flow.
5. User opens the verified apply link or recruiter email from the same flow.

## Current Build

- Native iOS app built with SwiftUI.
- No external dependencies.
- Local persistence through `UserDefaults`.
- Bundled startup jobs loaded from `JobPilotLite/SeedJobs.json`.
- Optional full and sliced remote live job feeds configured through `JobPilotLite/JobFeedConfig.json`.
- Static publishable job assets live in `Data/JobFeed`: `LiveJobs.json`, `index.json`, and `jobs/*.json`.
- Public ATS source discovery is tracked in `Data/JobSourceRegistry.json`; source health is written to `Data/JobSourceHealth.json` during refresh.
- Job data must pass recent live verification; the app does not fall back to fake/example roles.
- Template-based matching and template-based application material generation.
- Registration captures resume-ready profile history: contact info, target role, skills, work history, education, projects, certifications, and links.
- Resume-driven recommendation scoring uses local weighted signals from the user's profile history, skills, industry template, requirements overlap, location, visa preference, and experience level.
- One-tap resume generation with multiple template formats: ATS Classic, Modern Snapshot, Operations, Sales, Customer Success, Healthcare, Student, Field Work, and Creative.
- Two-tab structure: Matches and Profile.
- Role detail application flow for ATS resume generation, editing, saving, copying, export file creation, and verified apply-link opening.
- Quick-start role and location choices.
- One-tap demo profile for investor/user walkthroughs.
- Local MVP counters for saved jobs, generated messages, and opened applications.
- Resume builder preview, template switching, regenerate, and copy action.
- Resume Studio upgrades for North America, Australia, UK, and Europe target formats.
- Job-description tailored resume generation, local ATS scoring, keyword gap checks, and local AI-style bullet rewriting.
- Local resume version management with TXT, PDF, and Word-compatible RTF export files.
- In-app language setting now updates supported interface text immediately, with Chinese coverage for the main user flows.
- Privacy, feedback, share, and reset controls in the Profile tab.

## Open In Xcode

Open:

```text
JobPilotLite.xcodeproj
```

Target:

```text
JobPilotLite
```

The project targets iOS 17.0 and iPhone only for the MVP.

## Local Validation

This machine currently only needs Node and Apple Command Line Tools for non-simulator checks:

```sh
JOB_VALIDATE_MIN_LIVE_JOBS=500 node Tools/validate-seed-jobs.mjs JobPilotLite/SeedJobs.json
JOB_VALIDATE_MIN_LIVE_JOBS=12000 node Tools/validate-seed-jobs.mjs Data/JobFeed/LiveJobs.json
node Tools/validate-xcodeproj.mjs
swiftc -parse JobPilotLite/*.swift JobPilotLite/Views/*.swift
plutil -lint JobPilotLite.xcodeproj/project.pbxproj
```

For a stronger non-iOS local compile on machines that only have Apple Command Line Tools:

```sh
swiftc JobPilotLite/*.swift JobPilotLite/Views/*.swift -o /tmp/JobPilotLitePreview
```

A full simulator or device build still requires full Xcode with the iOS Simulator SDK installed.

## Replace Job Data

For production-style data, keep the full verified feed outside the app bundle:

```text
Data/JobFeed/LiveJobs.json
Data/JobFeed/index.json
Data/JobFeed/jobs/*.json
```

`JobPilotLite/SeedJobs.json` is only the small startup dataset bundled into the App Store install.

For quick local tests, edit:

```text
JobPilotLite/SeedJobs.json
```

Keep each job `id` stable after release. Saved applications are stored by `jobID`, so changing IDs will break saved application history.

Required fields:

```json
{
  "id": "UUID",
  "company": "Company",
  "title": "Operations Associate",
  "city": "New York, NY",
  "remoteType": "Remote",
  "salary": "$55,000 - $70,000",
  "tags": ["Operations & Logistics", "Excel", "Customer Service"],
  "sourceURL": "https://company.com/careers/role",
  "contactEmail": "careers@company.com",
  "summary": "One or two sentence role summary.",
  "requirements": ["2+ years of operations experience"],
  "visaFriendly": true,
  "postedDaysAgo": 2,
  "liveStatus": "live",
  "lastVerifiedAt": "2026-06-09T03:24:23.345Z",
  "verifiedSourceURL": "https://company.com/careers/role"
}
```

User resume data is stored in `CandidateProfile` and remains local in the MVP. The resume generator is deterministic and template-based; it does not call AI APIs.

Use `null` for `contactEmail` when there is only an apply link.

You can also prepare a CSV using:

```text
Data/seed_jobs_template.csv
```

Then convert it into the app JSON:

```sh
node Tools/csv-to-seed-jobs.mjs Data/seed_jobs_template.csv JobPilotLite/SeedJobs.json
```

Or refresh public ATS jobs directly:

```sh
node Tools/fetch-public-jobs.mjs Data/JobFeed/LiveJobs.json 12000
```

The crawler currently uses public Greenhouse, Ashby, and Lever job board surfaces. It does not access login-gated pages, bypass anti-bot controls, or infer email formats. `contactEmail` is only populated when a recruiting/careers-style email is explicitly present in the public job text. `salary` is extracted from public job text or public pay-transparency metadata when available; otherwise it remains `Not listed`.

To expand source coverage without running your own server, use the source discovery step:

```sh
node Tools/discover-job-sources.mjs Data/JobSourceRegistry.json Data/job-source-discovery-report.json
```

The discovery script uses `Data/JobDiscoverySeeds.json` and the latest Common Crawl index only as sources of candidate public ATS board URLs. It then validates each candidate against the public Greenhouse, Ashby, or Lever board endpoint/page before adding it to `Data/JobSourceRegistry.json`. A URL seen in a seed file or Common Crawl is not enough by itself; it must expose real current postings through the public ATS surface.

The fetch script always keeps the built-in reliable seed boards and adds only a bounded number of registry sources through `JOB_FETCH_EXTRA_SOURCE_LIMIT` so the GitHub Actions job cannot grow without limit. During fetch it writes `Data/JobSourceHealth.json`, including board status, job count, and latest error when a source fails. Large per-job refresh reports are kept out of git so the repository does not grow every day.

For the production-style daily feed, use the live verifier:

```sh
JOB_FETCH_PAY_BATCH_SIZE=64 JOB_FETCH_PAY_TIMEOUT_MS=8000 JOB_FETCH_LEVER_BATCH_SIZE=8 JOB_FETCH_EXTRA_SOURCE_LIMIT=120 JOB_VERIFY_TIMEOUT_MS=30000 JOB_VERIFY_RETRIES=2 node Tools/refresh-live-jobs.mjs Data/JobFeed/LiveJobs.json 12000 23000
node Tools/build-job-feed-assets.mjs Data/JobFeed/LiveJobs.json Data/JobFeed JobPilotLite/SeedJobs.json 800
```

The first command fetches public ATS candidates, verifies each job against the public ATS detail endpoint when available, checks that the final source URL still opens, keeps only jobs that still resolve to a live role, stamps each kept row with `liveStatus: "live"` and `lastVerifiedAt`, and writes a local refresh report. The second command builds static publish assets and shrinks the bundled startup dataset.

The refresh script writes to a temporary verified file first. It replaces `Data/JobFeed/LiveJobs.json` only if the target live-job count is reached, so a bad crawl cannot publish a partial feed. `Tools/validate-seed-jobs.mjs` also rejects any row without `liveStatus: "live"`, `verifiedSourceURL`, or a recent `lastVerifiedAt` timestamp.

The included GitHub Actions workflow `.github/workflows/daily-job-refresh.yml` runs the same refresh daily. It first tries to discover more public ATS sources, then fetches and verifies jobs, then publishes static JSON files. This uses GitHub's scheduled runner and commits static JSON files; it does not require an app server, database, cron VM, or paid backend. If source discovery fails, the workflow continues with the existing reliable source set.

The same workflow also uploads `Data/JobFeed` to GitHub Pages, so the refreshed job feed can be served as static JSON at no app-server cost. In the GitHub repo settings, set Pages to use GitHub Actions as the build source.

To make the App Store build dynamic, publish `Data/JobFeed` at a stable HTTPS URL and put the full-feed and index URLs in `JobPilotLite/JobFeedConfig.json`:

```json
{
  "remoteJobsURL": "https://your-domain.example/LiveJobs.json",
  "remoteJobIndexURL": "https://your-domain.example/index.json",
  "minimumLiveJobs": 12000,
  "startupMinimumLiveJobs": 200,
  "refreshIntervalHours": 24,
  "prefetchSliceLimit": 3
}
```

After GitHub Pages is available, update the config with:

```sh
node Tools/configure-job-feed-config.mjs https://OWNER.github.io/REPO/
```

On launch, the app first shows cached or bundled startup jobs, then refreshes the most relevant slices in the background when `remoteJobIndexURL` is configured. `remoteJobsURL` is a full-feed fallback. The app accepts remote data only when jobs have recent `liveStatus: "live"` verification. If the feed is missing, stale, or too small, it falls back only to bundled jobs that also have recent live verification. If neither source is fresh, the app shows no jobs instead of fake/example roles.

Current data assets:

- 800 verified live startup postings bundled into the app, about 1.2 MB
- 12,441 verified live public job postings in `Data/JobFeed/LiveJobs.json`, about 20 MB
- 31 static job slices in `Data/JobFeed/jobs`
- 155 companies
- 5,234 postings with public salary text or public pay transparency range
- 630 postings with explicit public recruiting/careers email
- 12,407 postings with extracted requirements/role standards
- 7,578 Greenhouse postings, 4,134 Ashby postings, and 729 Lever postings
- 12,441 postings with `liveStatus: "live"` from the latest public ATS and final source URL verification
- Cross-industry categories include sales, software/IT, operations/logistics, customer success, design/product, marketing, manufacturing/field work, data, legal/compliance, finance/accounting, healthcare, education, HR/recruiting, retail/hospitality, and administrative roles

## MVP Validation Metrics

Track manually or add analytics later:

- Profile completion rate
- Jobs viewed per user
- Jobs saved per user
- Application templates generated per user
- Apply-link opens or email opens
- Applications moved beyond Saved
- Day-7 retention
- Referral intent

The Profile tab also shows local-only counters:

- Saved applications
- Generated application templates
- Opened apply links or email drafts

These counters are stored on device and are meant for quick TestFlight conversations, not production analytics.

## Fast User Test Script

Use this script for a 10-minute test session:

1. Ask the user to open the app and either fill their name/email or tap `Use Demo Profile`.
2. Ask them to choose a target role and location.
3. Ask them to scan the first 10 job cards.
4. Ask them to save 3 jobs.
5. Ask them to open a role and tap Generate Resume & Apply.
6. Ask them to edit and save the generated resume from the application flow.
7. Ask whether they would use this again tomorrow with real jobs.
8. Ask what matters more next: better job data, better templates, or automation.

## Next Product Steps

1. Add more public/authorized ATS sources such as Workday, Recruitee, SmartRecruiters, and industry-specific boards.
2. Tighten first-run onboarding to under 90 seconds.
3. Add analytics events.
4. Add TestFlight feedback link.
5. Add simple privacy and data deletion screens.
6. Add employer/contact source provenance before any scaled application automation workflow.
