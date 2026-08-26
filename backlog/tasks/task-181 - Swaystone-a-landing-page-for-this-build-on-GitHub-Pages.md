---
id: TASK-181
title: 'Swaystone: a landing page for this build, on GitHub Pages'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-26 09:36'
updated_date: '2026-08-26 09:56'
labels: []
dependencies: []
ordinal: 188000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
This repository has no public face. It is presented only as one person's dotfiles, which undersells what it actually is: a deliberate argument about where the sweet spot sits between a system being light enough to feel instant and being considered enough to want to live in.

Give it a name and a single-page site that makes that argument. The name chosen is **Swaystone**. The site is one long landing page - hero, premise, measured numbers, screenshots, themes, install - hosted on GitHub Pages from this repository.

Everything the page asserts must be true of the repo and traceable to it: the idle memory figure, the package counts, the shortcut count, the theme list. A brand page that drifts from the thing it describes is the same failure mode this repository keeps hitting, one surface further out.

The site is repository tooling. Nothing it needs may be added to setup/packages/, and nothing it contains reaches the built machine.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A single landing page exists under site/ and is plain static HTML+CSS with no build step and no external network requests
- [ ] #2 The page states the project's premise: light enough to be instant, considered enough to be pleasant, intentional about what earns its place
- [ ] #3 Every number on the page (idle memory, package count, shortcut count, theme count) matches what the repository actually declares
- [ ] #4 The page shows real screenshots of the desktop and real theme colours taken from themes.toml
- [ ] #5 GitHub Pages publishes it automatically on push to main, via a workflow under .github/workflows/
- [ ] #6 The page renders correctly on a phone-width viewport as well as a desktop one
- [ ] #7 Nothing under setup/ changes, so the built machine is unaffected
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Stage clean screenshots on a throwaway headless output rather than shipping the nine existing debugging captures - the desktop-verification skill's recipe, so the user's screen is never touched.
2. Convert them to WebP with ffmpeg; 1.4 MB of PNG is a silly thing to serve from a page arguing for being light.
3. Generate site/themes.js from setup/dotfiles/.chezmoidata/themes.toml via tools/site-themes.py, so the page wears the real eleven palettes and cannot drift from them.
4. Write site/index.html + style.css + theme.js: one scroll - hero, premise, measured numbers, keyboard, live palette picker, how it is built, install, an honest closing note.
5. Publish with .github/workflows/pages.yml uploading site/ as the Pages artifact. No build step.
6. Verify by rendering in a real browser on the headless output at desktop and phone widths, and under a light palette as well as a dark one.
7. Record the name and the decision in DECISIONS.md; link the site from README.md; describe site/ in CLAUDE.md.
<!-- SECTION:PLAN:END -->
