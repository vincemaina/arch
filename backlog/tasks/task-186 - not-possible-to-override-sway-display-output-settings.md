---
id: TASK-186
title: not possible to override sway display/output settings
status: Done
assignee: []
created_date: '2026-08-26 13:20'
updated_date: '2026-08-27 11:26'
labels: []
dependencies: []
priority: medium
type: bug
ordinal: 192000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
E.g. if you edit sway config to match your display configuration, and then run sync.sh it wants to revert it back to the default repo config, which appears to have been designed for the virtual machine
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. THE MECHANISM ALREADY EXISTS - TASK-144.3 built it. setup/dotfiles/dot_config/sway/config.d/create_99-local.conf is a chezmoi create_ file: written once, never rewritten, and sway globs config.d/*.conf so 99- sorts last and wins. Its seeded comment even names "an output line for a monitor you own" as the example. So this is not a missing feature, it is a DISCOVERABILITY bug, and the fix belongs where the user actually met the problem.

2. Where they met it is sync.sh. It reports the drifted file, offers `chezmoi re-add` - which would bake this machine displays into the repository, the wrong answer - and then says "For changes that should stay on this machine only, use ~/.config/zsh/local.zsh". That line predates TASK-144.3 and names the ONE local file that is useless to someone editing sway. Make the advice per-file: look up the drifted file tool and name its own local file.

3. Six local files exist to map: sway config.d/99-local.conf, foot local.ini, git local, mpv local.conf, nvim local.lua, rofi local.rasi, plus zsh local.zsh. Derive the mapping from the repository rather than hardcoding a list that can go stale - the create_ files are discoverable under setup/dotfiles.

4. Point 20-output.conf at the local file. Someone changing their display layout is standing in that file, and it is the one tracked file most likely to be machine-specific.

5. Check the manual covers it, and add a session check if the mechanism can silently stop working.

6. On this machine, move the two output lines out of the tracked file and into 99-local.conf, and confirm the displays are byte-identical before and after.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ROOT CAUSE: not a missing mechanism. TASK-144.3 already built it - setup/dotfiles/dot_config/sway/config.d/create_99-local.conf, a chezmoi create_ file written once and never rewritten, and sway globs config.d/*.conf so 99- sorts last and wins. Its seeded comment even names "an output line for a monitor you own" as the example. The file existed on this machine, untouched, containing nothing but that comment.

What actually went wrong is that nothing pointed at it from where the wall was hit. sync.sh reported the drifted file, offered `chezmoi re-add` - which would have committed one desk displays to a repository meant to build anybody machine - and then said "For changes that should stay on this machine only, use ~/.config/zsh/local.zsh". That line predates TASK-144.3 giving six other tools a local file, and never grew. So someone editing their monitor layout was pointed at a shell file that could not help.

FIXED
- sync.sh advice is now per-file. The mapping is DERIVED by finding create_* files under setup/dotfiles rather than hardcoded, so a seventh tool getting a local file needs no edit here. zsh is named explicitly because it predates the pattern and is a .chezmoiignore entry, not a create_ file.
- 20-output.conf gained a "YOUR MONITORS DO NOT BELONG IN THIS FILE" block with a worked example, because someone changing their display layout is standing in that file.
- docs/manual/05-making-it-yours.md gained a "Your monitors are the case this exists for" subsection - the chapter already described the mechanism correctly, it just had no reason to be opened.
- DECISIONS.md records the general lesson: an escape hatch nobody is told about has the same failure mode as one that does not exist, and it is worse because it looks solved.

VERIFIED
Advice tested by manufacturing drift in a sway file and a foot file at once. Output named exactly ~/.config/sway/config.d/99-local.conf and ~/.config/foot/local.ini, one line each, no duplicates. Drift then reverted with apply --force and chezmoi status confirmed clean.

ON THIS MACHINE
The two output lines were moved out of the tracked 20-output.conf and into 99-local.conf, and 20-output.conf restored from git. Displays confirmed IDENTICAL across the move - DP-1 1920x1080@60 at (0,0) and HDMI-A-1 1920x1080@75 at (1920,0) before and after, read from swaymsg -t get_outputs both times. sync.sh --dry-run now reports no dotfile drift at all.

Worth noting for whoever reads this next: the tracked file only ever set a resolution for Virtual-1, which exists only inside a QEMU guest. So on real hardware there was never anything to conflict with - the local lines simply add what sway preferred-mode detection did not get right, and nothing above them competes.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The mechanism already existed and nothing pointed at it. TASK-144.3 created ~/.config/sway/config.d/99-local.conf - written once by chezmoi, never rewritten, globbed by sway and sorted last so it wins - and its seeded comment names an output line for a monitor you own as the example. It was sitting on this machine untouched.

The failure was discoverability, at the exact place the wall was hit: sync.sh reported the drifted file, suggested `chezmoi re-add` (which would have committed one desk monitors to a repository meant to build anybody machine), and advised ~/.config/zsh/local.zsh - a line written before six other tools got local files, naming the one tool that could not help.

sync.sh advice is now per-file, with the mapping derived from create_* files in the source rather than hardcoded. 20-output.conf carries a plain warning and a worked example. The manual gained a monitors subsection. DECISIONS.md records the lesson: an escape hatch nobody is told about fails like one that does not exist, and worse, because it looks solved - so document it where the wall is, not only in the chapter that already described it.

Verified by manufacturing drift in a sway file and a foot file simultaneously and reading the advice back: it named 99-local.conf and foot/local.ini, correctly and without duplicates. On this machine the two output lines were moved into 99-local.conf and the tracked file restored, with displays confirmed byte-identical either side of the move (DP-1 1920x1080@60 at 0,0; HDMI-A-1 1920x1080@75 at 1920,0). sync.sh --dry-run now reports no dotfile drift.
<!-- SECTION:FINAL_SUMMARY:END -->
