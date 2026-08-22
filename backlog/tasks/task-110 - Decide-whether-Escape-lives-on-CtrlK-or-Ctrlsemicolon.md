---
id: TASK-110
title: Decide whether Escape lives on Ctrl+K or Ctrl+semicolon
status: To Do
assignee: []
created_date: '2026-08-22 12:36'
updated_date: '2026-08-22 12:45'
labels: []
dependencies:
  - TASK-108
priority: low
ordinal: 118000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Both are bound to Escape at the same time, deliberately and temporarily, so they can be compared by use rather than by argument. TASK-108 chose Ctrl+K on the user own reasoning - Ctrl+J is effectively Enter, so Ctrl+K for Escape reads naturally, and both are home row - and the research turned up Ctrl+semicolon as the cheaper key. This ticket exists to end the trial with a decision rather than leaving two bindings for one action indefinitely.

What the comparison is actually between:

Ctrl+K costs three daily bindings, all of which now have a replacement: kill-line in zsh (moved to Alt+K), the split-above mapping in nvim (removed, use Ctrl+W then k), and move-up in fzf (use Ctrl+P). The one to watch for is fzf, where Ctrl+K now ABORTS rather than moving the selection up - the same keystroke doing something almost opposite. It also displaces kill-to-end-of-line in rofi, yazi, lazygit, qutebrowser and foot search, all rare.

Ctrl+semicolon costs nothing measurable. There is no ASCII control code for semicolon, so no terminal program can bind it, and nothing on this machine does. keyd turns it into a real Escape event before any terminal sees it. It is a right little finger reach from the home row rather than an index finger.

So this is not a question about cost, which is settled. It is a question about which one the hand actually reaches for, which only using both answers.

Note that leaving both is a real option and should be considered rather than assumed away - the repository rule is that nothing exists without a reason, not that nothing may be duplicated, and two ways to reach Escape could be defended the same way resizing is defended on both keyboard and pointer. The argument against is that every binding kept has a cost somewhere, and Ctrl+K in particular is paid for in fzf every day.

Whatever is decided, remove what is not kept. The trial ends when this ticket closes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One of the two is chosen, or both are kept with a stated reason
- [ ] #2 Whatever is not kept is removed from setup/system/keyd/default.conf and from anything that documents it
- [ ] #3 Any binding displaced for a key that is dropped is restored - notably kill-line in zsh and the nvim split mapping if Ctrl+K goes
- [ ] #4 tools/shortcuts.sh and the manual describe what is actually bound afterwards
- [ ] #5 Pressing each bound key emits a real Escape event below the compositor, proven by observing what keyd emits rather than by reading the config back
- [ ] #6 Ordinary typing, the left Alt/left Control swap, the Caps Lock scroll layer and the Backspace+Escape+Enter panic sequence all still work with the trial applied
- [ ] #7 setup/system/keyd/default.conf and the applied /etc/keyd/default.conf are identical
<!-- AC:END -->
