---
id: TASK-181
title: 'Swaystone: a landing page for this build, on GitHub Pages'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-26 09:36'
updated_date: '2026-08-26 10:34'
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
- [x] #5 GitHub Pages publishes it automatically on push to main, via a workflow under .github/workflows/
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

Deployment is built and pushed but NOT yet live, and the remaining step is not one this repository can take.

GitHub Pages has to be enabled once by a repository admin: Settings -> Pages -> Build and deployment -> Source: GitHub Actions. Until then `configure-pages` fails and every later step is skipped - confirmed on two runs (c8cd86e, e05b628), and the API still reports has_pages: false.

The action's `enablement: true` input exists to do exactly this through the API and does not work: the workflow's GITHUB_TOKEN cannot create a Pages site that has never existed. It was tried, it failed, and it was taken back out rather than left in looking load-bearing - the failure and the manual step are written into the workflow and site/README.md where the next reader will look.

AC 5 is therefore left unchecked. The workflow itself is correct and its YAML validates; what is unproven is the end-to-end deploy, which needs that one setting. Once it is on, re-running the workflow from the Actions tab publishes to https://vincemaina.github.io/arch/.

AC 5 verified end to end. Pages was enabled on the repository, and the workflow has since deployed successfully twice - runs on e6a4b35 and 7f846f8 both completed with conclusion success, after the two earlier failures on c8cd86e and 3cb8a91 when Pages did not yet exist.

The live site was checked by fetching it rather than by trusting the green run:

  https://vincemaina.github.io/arch/   200, 15,514 bytes of text/html

Every referenced asset resolves: style.css (200), theme.js (200), themes.js (200), assets/hero.webp (200), assets/launcher.webp (200), assets/favicon.svg (200). The served style.css contains the band-centring fix, so what is public is the corrected build and not the first one. Whole page is roughly 500 KB, of which about 460 KB is the two screenshots.

Note for whoever changes the workflow next: the one-time enablement step is real and is written into .github/workflows/pages.yml and site/README.md. configure-pages' enablement: true does not substitute for it.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Named the build **Swaystone** and shipped a one-page site for it, live at https://vincemaina.github.io/arch/.

The page makes the project's actual argument - light enough to feel instant, considered enough to want to live in, and intentional rather than merely empty - and backs it with figures that are all checkable from the repository: 550-650 MiB idle, ~0% idle CPU, 4.5 s of userspace to a desktop, 116 declared packages, 76 keyboard bindings, 39 helper scripts, 11 themes, 6 check scripts. Plain static HTML, one stylesheet, one script, two WebP screenshots; no build step, and no external requests (audited - every loaded resource is local, the only https URLs are GitHub anchors).

The eleven palettes are generated rather than transcribed: tools/site-themes.py writes site/themes.js from setup/dotfiles/.chezmoidata/themes.toml, and a visitor can apply any of them to the page itself. Re-running the generator on merged main reproduces the committed file byte-for-byte.

Verified by rendering in a browser on a throwaway headless output at 1920px, 1500px and 430px and under a light palette as well as a dark one, then by fetching the deployed site. That caught five real defects that reading the files would not have: the wordmark gradient ended on `tertiary` and faded into the page on every light theme; the eight stat tiles landed 7+1; the tagline wrapped to three lines; a wrong figure ('70 shortcuts', from a grep that misses the six bindings inside the resize mode - checks/sway-bindings.sh reports 76); and, found by the user rather than by me, two centre lines in the three full-bleed sections, where per-child margin-inline: auto lost to any child setting its own margin shorthand. The last is fixed structurally, by centring the band's column instead of its children, so a future child cannot opt out of it by accident.

Also updated the surfaces that would otherwise have gone stale: DECISIONS.md records the name and the choice of a no-build static page published from site/ rather than docs/; CLAUDE.md describes site/ and the generated themes.js; README.md is retitled and links to the site; site/README.md records where every asserted number comes from and how to re-take the screenshots.

checks/manual.sh passes 8/8 on merged main and checks/sway-bindings.sh reports no duplicate bindings. checks/packages.sh fails only on 21 pre-existing hand-installed packages on the development laptop, unrelated to this change. Nothing under setup/ was touched, so the built machine is unaffected.

Merged to main and pushed; deployed and confirmed live with all assets returning 200.
<!-- SECTION:FINAL_SUMMARY:END -->
