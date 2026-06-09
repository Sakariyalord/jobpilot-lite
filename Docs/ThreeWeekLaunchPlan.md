# Three Week Validation Plan

## First 20 Hours

Goal: make the MVP usable enough for internal review.

- Open project in Xcode and confirm simulator build.
- Replace sample jobs with 100-300 real public roles in one focused segment.
- Tune copy and labels for the target user group.
- Test the full loop on 5 devices or simulator sizes.
- Record the top friction points.
- Change `support@jobpilotlite.app` to a working inbox before external TestFlight.

## Week 1

Goal: make the UI fast and clear.

- Reduce onboarding to the fewest required fields.
- Improve job cards for scan speed: title, company, city, match label, key tags.
- Add empty states and error states.
- Add privacy screen and support contact.
- Add basic analytics events.
- Prepare TestFlight build.
- Keep the home flow under 4 taps: open app, choose target, show matches, generate template.
- Watch whether users understand the role-detail "Generate Resume & Apply" flow immediately. If not, shorten the button to "Apply" before TestFlight.

## Week 2

Goal: start acquisition.

- Recruit 50-100 target users from one niche.
- Give each user a narrow promise: find matching roles and generate application messages faster.
- Collect feedback after their first 10 minutes.
- Measure profile completion, generated messages, and saved jobs.
- Replace weak jobs daily.
- Compare two pitches: "job matching app" versus "automatic resume-and-apply assistant." Keep the one users repeat back accurately.

## Week 3

Goal: decide whether the idea deserves more engineering.

- Push to 300-500 users if early usage is healthy.
- Interview users who generated 3+ applications.
- Identify whether users want better job data, better resume templates, or more automation.
- Decide the next build: backend job ingestion, AI assistance, or employer-side onboarding.

## Kill Or Continue Criteria

Continue if:

- 50%+ complete profile.
- 30%+ generate at least one application message.
- 20%+ return within 7 days.
- 10%+ say they would pay for better data or automation.

Pause if:

- Users do not complete the profile.
- Users do not trust the job list.
- Users prefer existing tools after one session.
- The value is only "nice to have" and not urgent.
