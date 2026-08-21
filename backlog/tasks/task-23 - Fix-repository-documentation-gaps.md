---
id: TASK-23
title: Fix repository documentation gaps
status: In Progress
assignee: []
created_date: '2026-08-19 18:16'
updated_date: '2026-08-21 20:36'
labels:
  - repo
dependencies: []
priority: low
type: docs
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
README.md links to FLOW.md, which does not exist, so the documented overview of the installation process is a dead link. setup/packages/CHATGPT.md is a raw pasted assistant conversation sitting inside the installation payload, which is copied onto every built machine; its useful conclusions already live in packages/README.md and DECISIONS.md.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Every link in README.md resolves
- [x] #2 The installation flow is documented, including which stages run on the live ISO and which run inside the chroot
- [ ] #3 No raw conversation transcripts remain under setup/
- [ ] #4 Anything still useful from the removed material is preserved in the appropriate document
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Audited every relative link and named path in every tracked markdown file outside backlog/ with a script (scratchpad linkcheck), not by reading. Result: exactly one broken markdown link in the whole repository — README.md -> FLOW.md. Re-ran after the changes: 13 markdown files scanned, 0 broken links.

AC#1 (done): README.md links all resolve, verified by the same script. The <img src="./assets/arch-logo.svg"> also resolves.

AC#2 (done): wrote FLOW.md — the file README has promised since it was written. Covers the two entrypoints side by side; a table of which step runs on the live ISO and which inside arch-chroot, with the cp -a boundary between them; each of the five stages; what apply-config.sh owns and what --activate changes; the first-boot chain from systemd-boot through greetd/cage/ReGreet to uwsm and wayland-session@sway.target; sync.sh's four phases and why the order is what it is; and a 'where to change what' table. Every one of its 18 relative links was verified to resolve.

AC#3/#4 NOT done, and blocked rather than skipped: setup/packages/CHATGPT.md is still present, and setup/packages/ was outside this session's permitted edit surface (another agent was working there). Nothing else transcript-shaped exists under setup/.

Also fixed while in README.md: the Checks section's prose had drifted out of order — the description of checks/session.sh sat two code blocks below its command, after the sway-bindings description, so each of the three blocks appeared to describe the wrong script. Reordered so each command is followed by its own explanation, and added the checks/ vs tools/ distinction. Added a Documentation table linking FLOW.md, DECISIONS.md, docs/software/ and docs/wallpapers/.

Stale references found that are OUTSIDE this session's edit surface and remain unfixed:
  * DECISIONS.md:859 says user units are enabled from graphical-session.target.wants/ — the actual directory is wayland-session@sway.target.wants/.
  * DECISIONS.md:416 and CLAUDE.md both say the session is launched as 'uwsm start -- sway.desktop'. It is 'uwsm start -N Sway -D sway -- sway', and sway-uwsm.desktop explains at length why the .desktop form cannot be used.
  * DECISIONS.md still carries a '## Wofi' section. wofi is in no manifest; rofi replaced it.
  * CLAUDE.md names four session components; there are six units in wayland-session@sway.target.wants/ (autotiling and greeting were added).
  * CLAUDE.md says 'Checks: three scripts'; checks/packages.sh is now a fourth.

Verification: ./checks/session.sh — 75 passed, 0 failed, 0 skipped.
<!-- SECTION:NOTES:END -->
