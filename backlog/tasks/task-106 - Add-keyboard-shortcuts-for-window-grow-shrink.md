---
id: TASK-106
title: Add keyboard shortcuts for window grow/shrink
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 10:38'
updated_date: '2026-08-22 10:45'
labels: []
dependencies: []
priority: low
type: enhancement
ordinal: 114000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Initially the only ways to resize a window were to use resize mode on the keyboard, or drag on of the thin corners/edges.

Then we added the mod + scroll feature which i absolutely love - it basically grows/shrinks the height and width simultaneously which is more often that not, what i want.

so now id like to extend that functionalilty to the keyboard. im thinking mod and - = (- +). Of course that will require finding a new home for the scratchpad feature.

I use the scratchpad feature a lot less, that I'll be using this. As a general, prime shortcuts (i.e. fewer buttons required, and more natural positions) should be offered to the most used shortcuts.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add $mod+equal (grow) and $mod+minus (shrink) keyboard resize bindings to 50-keybindings.conf, matching the existing $mod+scroll gesture's 64x36 px step and --whole-window-free (mouse-only flag) keyboard semantics.
2. Decide keyboard repeat: repeat ON (no --no-repeat), matching the existing 'resize mode' h/j/k/l precedent where holding is the gesture; add $mod+equal and $mod+minus to checks/sway-bindings.sh's REPEATABLE whitelist.
3. Relocate the scratchpad show/move pair off bare $mod+minus/$mod+Shift+minus (now taken) to $mod+Ctrl+minus (show) / $mod+Ctrl+Shift+minus (move) - a deliberate demotion using the file's existing $mod+Ctrl 'second tier', keeping minus as the mnemonic and the Shift-for-move pattern intact.
4. Apply via chezmoi to the live system, reload sway, verify with swaymsg -t get_config that the new bindings are actually loaded (not just written to the file).
5. Spawn a throwaway probe window, measure its geometry via swaymsg -t get_tree before/after triggering $mod+equal and $mod+minus, confirm real resize happens; kill only that probe by its own con_id/pid.
6. Run checks/sway-bindings.sh, checks/sway-commands.sh, checks/session.sh and confirm all pass.
7. docs/manual/ is being written by another worker - do not touch it; its keyboard reference is generated from tools/shortcuts.sh so it updates automatically.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented in setup/dotfiles/dot_config/sway/config.d/50-keybindings.conf:
- $mod+equal = resize grow width 64px/height 36px; $mod+minus = resize shrink, same. Matches the scroll-wheel gesture's step/unit exactly. No --whole-window (confirmed via 'man 5 sway': that flag is mouse-only, meaningless for a keysym bind). Repeat left ON (no --no-repeat) - holding the key is the gesture, same rationale as the existing 'resize mode' h/j/k/l bindings which also repeat; added $mod+equal and $mod+minus to checks/sway-bindings.sh's REPEATABLE whitelist with a comment.
- Scratchpad relocated from $mod+minus/$mod+Shift+minus to $mod+Ctrl+minus (show) / $mod+Ctrl+Shift+minus (move) - demoted to the file's existing 'second tier' modifier ($mod+Ctrl, already used for relative workspace movement), keeping minus as the mnemonic and the Shift-for-move pattern intact. Literally more buttons for a less-used action, per the user's own principle.
- docs/manual/ untouched per instructions (another worker owns it); tools/shortcuts.sh - which the manual generates from - already reflects the new bindings correctly (verified by running it).

Verification against the RUNNING system, not just the file:
- Applied via 'chezmoi --source setup apply --force' targeted at only this one file, then 'swaymsg reload' (success:true).
- 'man 5 sway' confirms --whole-window is mouse-only (before writing the binding, not after).
- checks/sway-bindings.sh: 74 bindings, no duplicates, every binding either --no-repeat or on the whitelist - passes.
- checks/sway-commands.sh: all referenced commands accounted for - passes.
- checks/session.sh: 91 passed, 0 failed - passes.
- Spawned two throwaway foot probes (app_id resize-probe-a/b, con_id 9 and 11) tiled side-by-side on workspace 91 (not the visible workspace 1). Focused con_id 9 and ran the exact command the binding maps to via swaymsg:
  BEFORE  942x1027
  resize grow width 64px, height 36px  -> width 942->1006 (+64, exact); height unchanged (already at full workspace height, no vertical sibling to take space from - same documented no-op as the mouse gesture)
  resize shrink width 64px, height 36px -> width back to 942 (-64, exact)
  Killed only con_id 9 and 11 (never used pkill or app_id matching), switched back to workspace 1.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added $mod+equal (grow) / $mod+minus (shrink) keyboard resize bindings matching the existing $mod+scroll gesture exactly: 64px width / 36px height per step, no --whole-window (confirmed mouse-only via man 5 sway), and left repeatable-on-hold like the analogous resize-mode h/j/k/l bindings (added to checks/sway-bindings.sh's REPEATABLE whitelist). Relocated the scratchpad show/move pair to $mod+Ctrl+minus / $mod+Ctrl+Shift+minus - the file's existing second-tier modifier - keeping minus as the mnemonic and the show/move-via-Shift pattern intact, per the user's stated 'prime shortcuts go to the most-used action' principle. Verified against the running system: applied via a single-file chezmoi apply + swaymsg reload, then measured a throwaway probe window's real geometry (942->1006->942 px, exact) before/after invoking the bound command. checks/sway-bindings.sh (74 bindings, no duplicates, repeat policy clean), checks/sway-commands.sh and checks/session.sh (91/91) all pass. docs/manual/ left untouched (owned by a concurrent worker); tools/shortcuts.sh, which the manual is generated from, already reflects the new bindings.
<!-- SECTION:FINAL_SUMMARY:END -->
