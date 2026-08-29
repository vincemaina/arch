---
id: TASK-187
title: make it so copy and paste is just ctrl + c/v without shift
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-26 13:29'
updated_date: '2026-08-29 09:00'
labels: []
dependencies: []
priority: low
type: enhancement
ordinal: 193000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
currently doesn't work because in the terminal ctrl c is used to kill processes. i use that less often so i believe that should be ctrl shift c. i.e. these shortcuts should be swapped around
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 In foot, Ctrl+C copies the selection and Ctrl+V pastes, matching the rest of the desktop
- [ ] #2 The interrupt still works, on Ctrl+Shift+C, and stops a running command
- [ ] #3 Readline's quoted-insert keeps a key rather than being lost silently: Ctrl+Shift+V
- [x] #4 Ctrl+Shift+A (copy the whole terminal) still works and does not collide
- [x] #5 tools/shortcuts.sh reports the new bindings, including where the interrupt went
- [x] #6 The manual and DECISIONS.md describe the swap and its cost, and checks/manual.sh passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. foot.ini.tmpl: move clipboard-copy to Control+c (keeping XF86Copy) and clipboard-paste to Control+v (keeping XF86Paste); add a [text-bindings] section sending \x03 on Control+Shift+c and \x16 on Control+Shift+v, so the interrupt and readline's quoted-insert keep a key.
2. Record in the file WHY there is no copy-or-interrupt option: foot 1.27's BIND_ACTION_CLIPBOARD_COPY returns true unconditionally (input.c:180), so Ctrl+C is swallowed whether or not anything is selected. Verified in the 1.27.0 source, not guessed.
3. tools/shortcuts.sh: parse [text-bindings] as well as [key-bindings], so the swap shows up in the report rather than being invisible to it; replace the note that asserts foot's defaults are Ctrl+Shift+C/V.
4. Manual: docs/manual/04-applications.md (the foot section) and docs/manual/06-working.md (the clipboard-history paste note, which names Ctrl+Shift+V as foot's paste).
5. DECISIONS.md: record the swap and its trade-off - every TUI that uses Ctrl+C to cancel (fzf, nvim, btop) now needs Ctrl+Shift+C.
6. Verify: foot --check-config on the rendered config with negative controls, then checks/session.sh, checks/manual.sh and tools/shortcuts.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented as a swap in setup/dotfiles/dot_config/foot/foot.ini.tmpl: clipboard-copy=Control+c XF86Copy, clipboard-paste=Control+v XF86Paste, plus a new [text-bindings] section sending \\x03 on Control+Shift+c (the interrupt) and \\x16 on Control+Shift+v (readline quoted-insert). foot's own XF86Copy/XF86Paste defaults are repeated because naming a binding replaces the whole default list.

WHY THERE IS NO COPY-OR-INTERRUPT. Checked in foot 1.27.0's source rather than guessed: BIND_ACTION_CLIPBOARD_COPY in input.c calls selection_to_clipboard() then 'return true' unconditionally, so the key is consumed whether or not anything is selected. pipe-selected is not a way round it - its failure path 'goto pipe_err' also returns true. So Ctrl+C in foot now copies always and never reaches the program; fzf, btop, nvim and a hung command all want Ctrl+Shift+C. That cost is written into the config, the manual and DECISIONS.md rather than left to be discovered.

VERIFICATION, AND ITS ONE GAP. foot --check-config passes on the rendered config (exit 0). That is meaningful because two negative controls were run first and both failed loudly: a duplicate inside [key-bindings] ('Control+c already mapped to clipboard-copy', exit 230), and a [text-bindings] entry colliding with a live key binding ('Control+Shift+c already mapped to clipboard-copy', exit 230). So foot cross-checks the two sections, and a config that parses is proof the swap is complete in both directions - which is what makes AC 4 (no collision with Ctrl+Shift+A) provable at all.

The keypresses themselves cannot be scripted on this machine: sway has no key-injection IPC (checks/session.sh already says so for the Ctrl+Shift+A step), wtype/ydotool are not installed and sudo needs a password. So step 6 was added to session.sh's manual-verification list, alongside the existing Ctrl+Shift+A one.

Also: tools/shortcuts.sh now parses [text-bindings] as well as [key-bindings]. Without that, the report would have shown Ctrl+C copying and no sign of where the interrupt went - the exact question that file exists to answer. Its collision section now correctly flags ctrl+v as 'foot: Paste | zsh: quoted-insert', which is the drift that motivated moving quoted-insert rather than dropping it.

Checks after the change: checks/session.sh 138 passed 0 failed 2 skipped; checks/manual.sh 8 passed 0 failed; checks/sway-bindings.sh 77 bindings, none doubled; checks/sway-commands.sh all accounted for. A foot launched with the applied config emits no config warnings at runtime (only the unrelated pre-existing xdg-toplevel-icon one).

Out of scope, noticed in passing: site/index.html asserts 76 keyboard bindings and checks/sway-bindings.sh now reports 77. Pre-existing - nothing here touches a sway binding - and adjacent to TASK-185.
<!-- SECTION:NOTES:END -->
