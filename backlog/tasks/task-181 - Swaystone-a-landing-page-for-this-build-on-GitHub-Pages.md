---
id: TASK-181
title: 'Swaystone: a landing page for this build, on GitHub Pages'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-26 09:36'
updated_date: '2026-08-26 10:01'
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
- [x] #1 A single landing page exists under site/ and is plain static HTML+CSS with no build step and no external network requests
- [x] #2 The page states the project's premise: light enough to be instant, considered enough to be pleasant, intentional about what earns its place
- [x] #3 Every number on the page (idle memory, package count, shortcut count, theme count) matches what the repository actually declares
- [x] #4 The page shows real screenshots of the desktop and real theme colours taken from themes.toml
- [ ] #5 GitHub Pages publishes it automatically on push to main, via a workflow under .github/workflows/
- [x] #6 The page renders correctly on a phone-width viewport as well as a desktop one
- [x] #7 Nothing under setup/ changes, so the built machine is unaffected
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verification was done by rendering the page in qutebrowser on a throwaway headless output (the desktop-verification skill's recipe), not by reading the files back. That caught three things a file read would not have:

- the wordmark gradient ended on `tertiary`, which is the pale colour in every light palette (paper's is #c9c9c2), so the last letters faded into the page. Now accent -> secondary, which is safe across all eleven.
- the eight stat tiles were on auto-fit and landed 7+1, stranding the eighth. Now an explicit 4x2, and 2x4 under 620px.
- the tagline wrapped to three lines at max-width 22ch.

Also corrected a number before it shipped: a first draft said '70 shortcuts', from `grep -c '^bindsym'`, which counts only bindings at the start of a line and misses the six inside the resize mode block. checks/sway-bindings.sh reports 76. The page now takes the figure from the check, and site/README.md records why.

Two mistakes made during the work, both recovered: staged windows twice mapped onto the user's real workspace instead of the headless output, once fullscreen, because focus was handed back while a window was still starting. Fixed by polling get_tree until the window exists and then moving it explicitly rather than launching onto whatever output happens to be focused. The headless output was unplugged and focus restored at the end; get_outputs and get_tree confirm the session is as it was.

checks/manual.sh passes 8/8 and checks/sway-bindings.sh reports no duplicate bindings. checks/packages.sh fails 21 pre-existing drift items on this laptop (spotify-player, usbutils, base-devel and similar installed by hand); unrelated to this task, which changes nothing under setup/.
<!-- SECTION:NOTES:END -->
