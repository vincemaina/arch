---
id: TASK-23
title: Fix repository documentation gaps
status: Done
assignee: []
created_date: '2026-08-19 18:16'
updated_date: '2026-08-22 11:59'
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
- [x] #3 No raw conversation transcripts remain under setup/
- [x] #4 Anything still useful from the removed material is preserved in the appropriate document
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

AC#3/#4 completed. Removed setup/packages/CHATGPT.md (git rm), the raw pasted design conversation, since setup/packages/ is now within this session's edit surface.

Verified the 'already covered' claim rather than assuming it, quoting sources:
- Manifest split (base/desktop/dev) and 'intentional top-level requirements, not every transitive dependency' -> DECISIONS.md '## Package manifests' (line 1889) and setup/packages/README.md 'Philosophy' section, near-verbatim to the transcript's suggested paragraph.
- The dependency-vs-explicit distinction ('a dependency may be listed explicitly when the system relies on that capability directly', polkit example) -> setup/packages/README.md 'Philosophy', word-for-word match, extended by the TASK-13 asexplicit/asdeps mechanism and checks/packages.sh in the same file's 'Checking that this is still true' section.
- 'boring one-package-per-line for piping into pacman' -> only ever true for base.txt; CLAUDE.md 'Package manifests -- two different parsers' documents that desktop.txt/dev.txt in fact allow comments (grep -Ev filtered) and are richly commented in practice (verified by reading them) -- this supersedes rather than confirms the transcript, which wrongly assumed all three manifests needed to stay comment-free.
- Per-package rationale table for base.txt (base/linux/linux-firmware/btrfs-progs/networkmanager/sudo/vim/git) -> docs/software/README.md '### base.txt' table plus full Problem/Choice/Alternatives/Cost entries for linux, linux-firmware, btrfs-progs, sudo, vim -- far more detailed than the transcript's one-line table.
- The category grouping tree (compositor/UI/audio/fonts/applications/...) -> superseded by docs/software/README.md's complete roll-call (compositor and session / audio, portals, notifications / utilities / appearance sections), which reflects the actual current package set; the transcript's tree is stale (names wofi, thunar, network-manager-applet, none of which are still declared).
- 'verify against the VM with pacman -Qqe, compare by hand' -> automated by checks/packages.sh, documented in setup/packages/README.md.
- polkit-gnome vs the transcript's undecided lxqt-policykit -> DECISIONS.md '## polkit-gnome as the authentication agent' records the actual decision and why the Qt-based alternative was passed over.

Dropped as category (c), never-adopted speculation, per the instruction not to preserve it 'just in case':
- The install-base/install-desktop/install-dev tiered installer and a hypothetical server profile ('Arch base -> desktop -> dev, or -> server'). Never implemented, no such scripts or profiles exist anywhere in the repo, and nothing else in DECISIONS.md alludes to a rejected server-profile design. Not recorded as a rejected alternative because it was pure brainstorming that was never attempted or decided against -- there is no decision to record, only an idea that was not pursued.
- The 'deliberately left out for now: cliphist, playerctl, lxqt-policykit' note -- overtaken by events: cliphist and playerctl are both declared in desktop.txt today, each with its own comment explaining why (cliphist's is extensive, covering the choice over copyq); lxqt-policykit was superseded by the polkit-gnome decision above.
- The closing 'next thing should be capturing your current Sway and Waybar configuration' -- a stale next-step from when chezmoi dotfiles did not yet exist; they do now.

No content qualified as category (b) (worth recording, currently missing) -- every substantive conclusion in the transcript was already present elsewhere, generally in more detail and more accurate than the transcript itself.

Removed the setup/packages/CHATGPT.md reference from CLAUDE.md's Known gaps section (was the only reference to the file outside setup/ and outside backlog/). Confirmed via repo-wide grep that the only remaining mentions of CHATGPT.md are historical implementation notes inside backlog/tasks/*.md (task-23 itself and task-44), which are not edited directly per CLAUDE.md's CRITICAL_INSTRUCTION.

Verification: ./checks/manual.sh -> 8 passed, 0 failed. ./checks/packages.sh -> 6 passed, 0 failed, 0 skipped ('The manifests describe this machine.').
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed setup/packages/CHATGPT.md, a raw pasted design-conversation transcript that was inside the installation payload copied onto every built machine. Every substantive conclusion in it was verified to already exist elsewhere, generally in more detail: DECISIONS.md '## Package manifests' and '## polkit-gnome as the authentication agent', setup/packages/README.md's Philosophy and Checking-that-this-is-still-true sections, docs/software/README.md's per-manifest tables and Problem/Choice/Alternatives entries, and CLAUDE.md's 'Package manifests -- two different parsers'. Nothing qualified as worth-preserving-and-missing. Dropped as unacted speculation: the install-base/desktop/dev tiered-installer and server-profile idea, the stale 'left out for now: cliphist/playerctl/lxqt-policykit' note (all three are now resolved one way or another), and the closing 'capture the Sway/Waybar config' next-step (already done via chezmoi). Removed the file's only remaining reference outside backlog/ (CLAUDE.md's Known gaps entry). Verified with ./checks/manual.sh (8 passed, 0 failed) and ./checks/packages.sh (6 passed, 0 failed, 0 skipped).
<!-- SECTION:FINAL_SUMMARY:END -->
