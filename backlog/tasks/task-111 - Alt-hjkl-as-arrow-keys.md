---
id: TASK-111
title: Alt + hjkl as arrow keys
status: To Do
assignee: []
created_date: '2026-08-22 13:53'
labels: []
dependencies: []
references:
  - setup/system/keyd/default.conf
  - setup/dotfiles/dot_zshrc
  - docs/manual/03-the-keyboard.md
priority: medium
type: spike
ordinal: 119000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Holding Alt should turn hjkl into arrow keys - h Left, j Down, k Up, l Right - so the hand never leaves the home row to reach the arrow cluster.

This is a spike, not the implementation. The question it has to answer is what Alt+hjkl already does on this machine, and whether the cost is worth paying, BEFORE anything is bound.

Where it would live is not the interesting part. Almost certainly an [alt] layer in setup/system/keyd/default.conf, alongside the [control] layer that already carries Ctrl+K as Escape. keyd's manual states that bindings are not affected by the modifiers of the layer they are defined in, so an [alt] layer with h = left emits a BARE Left, exactly as [control] k = esc emits a bare Escape. The arrow therefore arrives inside every program, including the ones this repository has no config file for. That much is established and does not need re-deriving.

What is not established, and is the actual work:

1. What Alt+h, Alt+j, Alt+k and Alt+l currently do, asked of each program on this machine rather than recalled from general knowledge - the method TASK-108 used for Ctrl+K, and the reason its cost table is trustworthy. At least: zsh, nvim, fzf, foot, rofi, yazi, lazygit, qutebrowser, firefox, the backlog TUI, sway, and GTK dialogs, whose Alt+letter menu mnemonics are the least obvious of these and the easiest to forget.

2. One conflict is already known, and it is circular. dot_zshrc binds Alt+K to kill-line, and it is there ONLY because TASK-108 took Ctrl+K for Escape and kill-line had nowhere else to go. Taking Alt+K for Up displaces it a second time, and a bindkey line left behind for a key keyd now swallows would read as configuration and never fire - this repository's signature bug. There is also an interaction with TASK-110: if that trial drops Ctrl+K, kill-line returns to it and Alt+K comes free. Do not block on TASK-110, but say which outcome the recommendation assumes.

3. Whether the arrows compose with other modifiers. An arrow key is not only an arrow: Shift+Left selects, Ctrl+Left jumps a word, Ctrl+Shift+Left selects a word. If Alt+Shift+h does not produce Shift+Left, this delivers a fraction of what arrow keys do. Layer precedence in keyd is not obvious enough to reason about - find the limit by observing what keyd emits.

4. Whether it is reachable at all. keyd swaps left Alt and left Control here, so the [alt] layer is entered by the PHYSICAL bottom-left corner key, under the weakest finger - a worse position than the key it replaces, which is the honest cost dot_zshrc already records for Alt+K. Right Alt is a separate layer (altgr) and would not trigger this unless bound too. Whether the reach genuinely beats the arrow cluster is a question for the hand, not the argument.

5. Whether it duplicates something already here. Holding Caps Lock already makes hjkl scroll and d/u page. Two hold-keys putting directional movement on hjkl needs a reason, or these arrows belong on the layer that already exists.

6. What else could carry it. At least three alternatives with their trade-offs, in the style of the tables already in default.conf - a dedicated nav layer on a currently wasted key, right Alt, and doing nothing at all because Caps+hjkl covers the case this was reached for.

The output is a recommendation with its costs written down, not a binding. If the recommendation is to build it, this task can carry that too - but the conflict table comes first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 What Alt+h, Alt+j, Alt+k and Alt+l currently do is recorded per program, gathered by asking each program on this machine (zsh bindkey, nvim, fzf, foot, rofi, yazi, lazygit, qutebrowser, firefox and GTK menu mnemonics, the backlog TUI, sway) rather than from general knowledge, and each loss is marked trivial or daily
- [ ] #2 The Alt+K collision with kill-line in dot_zshrc is resolved explicitly - replaced on another key, or its loss written down where the next reader will look - and the recommendation states which TASK-110 outcome it assumes
- [ ] #3 Whether Shift, Ctrl and Ctrl+Shift compose with the remapped hjkl is established by observing the events keyd emits, not by reading the config or the manual back
- [ ] #4 Whether the reach is actually better than the arrow cluster, given that Alt is the bottom-left corner key after the swap, is answered by trying it live rather than by argument
- [ ] #5 At least three alternatives are assessed with trade-offs, including a dedicated nav layer on a wasted key, right Alt, and not building it at all because Caps Lock + hjkl already covers scrolling - and one is recommended
- [ ] #6 If a binding is made: setup/system/keyd/default.conf passes keyd check and carries the reasoning and cost table in the file, nothing is left in any config that the remap now shadows and that can therefore never fire, tools/shortcuts.sh reports it, docs/manual/03-the-keyboard.md describes it, and ./checks/session.sh, ./checks/manual.sh, ./checks/sway-bindings.sh and ./checks/sway-commands.sh all pass
- [ ] #7 If the recommendation is NOT to build it, that finding is written where the next reader will look rather than only in this task
<!-- AC:END -->
