# OpenAI Build Week requirements

Status date: 2026-07-18
Target track: **Work & Productivity**

This file is a working compliance map, not a submission and not legal advice. The official
sources remain authoritative:

- [OpenAI Build Week](https://openai.com/build-week/)
- [Challenge overview](https://openai.devpost.com/)
- [Official rules](https://openai.devpost.com/rules)

## Verified requirements

| Requirement | Repository response | Current status |
|---|---|---|
| Build with Codex and GPT-5.6 | This primary run uses Codex CLI with the owner-selected GPT-5.6 Sol profile; earlier Build Week Codex work is separately logged. | In progress |
| Working, consistently installable project | Windows self-contained desktop and installer paths exist; final exact-SHA artifacts still need rebuilding. | Partial |
| Existing project meaningfully extended after 2026-07-13 09:00 PT | The project predates Build Week. The first commit after the official cutoff is `43e62cc`; the pre-period parent is `ecfb473`. | Documented |
| Evaluate only Submission Period additions | `BUILD_WEEK_CHANGELOG.md` separates the pre-period baseline from later commits and pending finalization work. | In progress |
| Pick one category | Work & Productivity: a local tournament workstation for volunteer organizers and clubs. | Ready |
| English project description and testing guidance | English Devpost draft, README, judge quickstart, demo script, and manual test path now exist; final candidate fields remain placeholders. | Prepared |
| Demo video under three minutes | A public YouTube video with audio explaining the product, Codex, and GPT-5.6 is required. Upload remains Owner-only. | Pending |
| Testable repository | Public repository needs relevant licensing; otherwise it must be private and shared with the two official judging addresses. | Owner decision required |
| README with setup, sample data, and test route | English-first README now documents setup paths, synthetic demo, architecture, collaboration and limitations. | Prepared; final SHA check pending |
| Explain Codex collaboration and key human decisions | `CODEX_COLLABORATION.md` records acceleration, corrections, attribution, and Owner decisions. | Prepared |
| `/feedback` Session ID | Must come from this same primary thread. The actual ID stays local; only a SHA-256 may be committed. | Pending user command |
| English or complete English translation | Core judge navigation/demo/round/result/standings controls and all submission materials have English text; dense expert screens remain documented as partial. | Manual verification pending |
| Third-party rights | Direct dependency inventory exists; final Android and transitive notices require review after PR #49 reaches a final head. | Partial |

## Judging criteria

The four criteria are equally weighted:

1. **Technological Implementation** — genuine, non-trivial, working use of Codex.
2. **Design** — a complete and coherent runnable product experience.
3. **Potential Impact** — a credible solution for a specific real audience.
4. **Quality of the Idea** — creative differentiation from existing concepts.

The candidate will not be marked ready merely because it builds. Installation, first-run
clarity, the central tournament workflow, mobile result entry, evidence, and honest limitations
must agree with the video and written description.

## Claims that are explicitly prohibited

The submission must not claim that the project was wholly built during Build Week, is FIDE
certified or approved, provides full Android offline operation, is a public release, is on
F-Droid, or ships a production-signed Windows executable.
