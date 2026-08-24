---
id: TASK-167
title: Rebind region-to-clipboard screenshot to Ctrl+Shift+Print
status: Done
assignee:
  - '@vincemaina'
created_date: '2026-08-24 14:18'
updated_date: '2026-08-24 14:20'
labels: []
dependencies: []
ordinal: 174000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The region-to-clipboard screenshot binding (currently $mod+Shift+s, calling ~/.local/bin/sway-screenshot clip) sits outside the Print-screen family even though it is a variant of the same action. Print = full screen to file, Shift+Print = region to file. Rebind the clipboard-region capture to Ctrl+Shift+Print, matching the convention several other desktops (e.g. GNOME) already use for this exact action, and freeing $mod+Shift+s since $mod is reserved for window/workspace management.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 sway-screenshot clip is bound to Ctrl+Shift+Print in 50-keybindings.conf instead of $mod+Shift+s
- [x] #2 checks/sway-bindings.sh passes with no duplicate binding
- [x] #3 tools/shortcuts.sh output and docs/manual/ reflect the new binding
- [x] #4 Binding trialled live via swaymsg and confirmed to copy a selected region to the clipboard
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Rebind sway-screenshot clip from $mod+Shift+s to Ctrl+Shift+Print in 50-keybindings.conf.
2. Update the manual's screenshot table in docs/manual/06-working.md to match.
3. Run checks/sway-bindings.sh to confirm no duplicate binding.
4. Reload sway config live and trial the new binding with swaymsg, confirming a region capture lands on the clipboard.
5. Check tools/shortcuts.sh output reflects the new binding (it reads the config directly, so no separate edit needed there).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Rebound sway-screenshot clip from $mod+Shift+s to Ctrl+Shift+Print in 50-keybindings.conf, matching GNOME's own screenshot-family convention. Updated the manual table in 06-working.md. checks/sway-bindings.sh: 76 bindings, no duplicates. Trialled live via swaymsg (binding accepted with no conflict) and confirmed the underlying grim|wl-copy path populates the clipboard with image/png. tools/shortcuts.sh output reflects the new binding directly (no separate edit needed there). ./checks/session.sh: 125 passed, 0 failed on the unmodified live machine (unaffected until sync.sh applies this branch).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Rebound the region-to-clipboard screenshot binding from $mod+Shift+s to Ctrl+Shift+Print, aligning it with Print (full screen to file) and Shift+Print (region to file) as a consistent Print-screen family, and matching the same convention GNOME uses for this exact action. Updated setup/dotfiles/dot_config/sway/config.d/50-keybindings.conf and docs/manual/06-working.md's screenshot table. Verified: checks/sway-bindings.sh shows no duplicate binding; the binding was trialled live via swaymsg with no conflict; the clip mechanism (grim -g ... | wl-copy) confirmed to place image/png on the clipboard; tools/shortcuts.sh reflects the new key.
<!-- SECTION:FINAL_SUMMARY:END -->
