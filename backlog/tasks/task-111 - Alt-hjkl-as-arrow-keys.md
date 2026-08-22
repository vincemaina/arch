---
id: TASK-111
title: Alt + hjkl as arrow keys
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 13:53'
updated_date: '2026-08-22 15:10'
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
- [x] #1 What Alt+h, Alt+j, Alt+k and Alt+l currently do is recorded per program, gathered by asking each program on this machine (zsh bindkey, nvim, fzf, foot, rofi, yazi, lazygit, qutebrowser, firefox and GTK menu mnemonics, the backlog TUI, sway) rather than from general knowledge, and each loss is marked trivial or daily
- [x] #2 The Alt+K collision with kill-line in dot_zshrc is resolved explicitly - replaced on another key, or its loss written down where the next reader will look - and the recommendation states which TASK-110 outcome it assumes
- [x] #3 Whether Shift, Ctrl and Ctrl+Shift compose with the remapped hjkl is established by observing the events keyd emits, not by reading the config or the manual back
- [x] #4 Whether the reach is actually better than the arrow cluster, given that Alt is the bottom-left corner key after the swap, is answered by trying it live rather than by argument
- [x] #5 At least three alternatives are assessed with trade-offs, including a dedicated nav layer on a wasted key, right Alt, and not building it at all because Caps Lock + hjkl already covers scrolling - and one is recommended
- [x] #6 If a binding is made: setup/system/keyd/default.conf passes keyd check and carries the reasoning and cost table in the file, nothing is left in any config that the remap now shadows and that can therefore never fire, tools/shortcuts.sh reports it, docs/manual/03-the-keyboard.md describes it, and ./checks/session.sh, ./checks/manual.sh, ./checks/sway-bindings.sh and ./checks/sway-commands.sh all pass
- [x] #7 If the recommendation is NOT to build it, that finding is written where the next reader will look rather than only in this task
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Ask every candidate program on this machine what Alt+h/j/k/l is bound to, rather than recalling it: zsh bindkey, a full nvim keymap dump, fzf's man table, rofi -dump-config, lazygit --config, foot's man page, strings on the yazi and backlog binaries, qutebrowser's configdata.yml, and the sway binding table.
2. Add a minimal [alt] layer to setup/system/keyd/default.conf and validate it with keyd check.
3. Prove what it EMITS with a uinput probe that reads keyd's own virtual keyboard back - in particular whether Shift and Ctrl compose - and make the probe prove it was grabbed before believing any negative result.
4. Measure the one non-obvious side effect, the transient Alt press keyd emits either side of a bare key, against Firefox's menu bar. Do it on a headless output so the user's screen is never touched.
5. Resolve the Alt+K collision with zsh kill-line. Drop it rather than move it a third time, and write the loss where the next reader will look.
6. Write the reasoning and the full cost table into the keyd config itself; add arrows_note to tools/shortcuts.sh, reading the layer out of the config rather than asserting a binding string.
7. Document it in docs/manual/03-the-keyboard.md, and correct the Ctrl+K row the change invalidates.
8. Run all four checks, and prove the keyd gate fails on a deliberately broken copy.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## What Alt+hjkl cost, asked of each program on this machine

| Program | Evidence | Alt+h/j/k/l was | Weight |
| --- | --- | --- | --- |
| zsh | zsh -i -c bindkey | h=run-help, j=UNBOUND, k=kill-line, l=down-case-word | k daily, rest rare |
| yazi | embedded preset keymap, [cmp] section | A-j/A-k step the COMPLETION popup - and Up/Down are bound to the same two actions two lines below | none |
| firefox | screenshotted: a bare Alt tap opens the menu bar; Alt+H is Help | Help menu | trivial |
| GTK dialogs | mnemonic convention | any _h/_j/_k/_l button | trivial, and NOT exhaustively enumerable |
| fzf | man fzf default binding table | nothing - its Alt keys are b, d, f, backspace and the arrows | none |
| nvim | dumped every keymap with map and map! | nothing - no Alt mapping at all | none |
| sway | checks/sway-bindings.sh, all 76 bindings | nothing - all use $mod, Shift or Ctrl | none |
| rofi | rofi -dump-config | nothing bare; Ctrl+Alt+h is kb-remove-word-back and survives | none |
| foot | man 5 foot.ini | nothing - its Mod1 keys are b, d, f, BackSpace | none |
| lazygit | lazygit --config | nothing | none |
| qutebrowser | configdata.yml | nothing - it binds no Alt shortcut at all | none |
| backlog TUI | strings on the binary | Alt+B and Alt+Q only | none |

One daily loss, and it had already been displaced twice: zsh kill-line. Dropped rather than moved a third time, on the owner's judgement that it was not being used. Recorded in dot_zshrc where the binding used to be, together with how to bring it back.

## The two questions that actually decided it

**Shift and Ctrl compose, and need no configuration at all.** Measured with a uinput probe reading keyd's own virtual keyboard back:

    Alt+h            -> +left -left with NO modifier held
    Alt+Shift+h      -> shift still held across the arrow  = Shift+Left
    Alt+Ctrl+h       -> ctrl still held across the arrow   = Ctrl+Left
    Alt+Ctrl+Shift+h -> both still held                    = Ctrl+Shift+Left

keyd strips only the layer's OWN modifier. So these are arrow keys rather than an imitation of them - selection and word-jump both work, and no composite layers were needed.

**The transient Alt does not open the menu bar.** To emit a bare key keyd releases the modifier and re-presses it, so an Alt press surrounds every one of these. A bare Alt tap DOES open Firefox's menu bar - screenshotted, mnemonics visible. Alt+h does not, and neither does Alt+h five times over, because keyd presses Control inside the Alt hold and an intervening key cancels the bare-tap gesture. Control shots and injected shots were compared with focus asserted on firefox before each injection.

## Ergonomics

Answered by the owner using it, which is the only way this one could be answered: Alt+hjkl is a far smaller movement than taking the whole right hand to the arrow cluster - Alt is a short stretch of the left little finger. That is why the feature exists, and every conflict above is cheaper than that movement.

## Apparatus faults met on the way, all three of the shape scripting-traps warns about

1. The grab-check matched a STALE journal line from a previous session's `keyd-probe` and announced "keyd IGNORED the probe" about a device keyd had in fact matched. Filter on this probe's own name, and on the LAST matching line.
2. `struct.pack("=llHHi", ...)` makes input_event 16 bytes rather than 24, because under `=` the format `l` is four bytes, not eight. Every write failed with EINVAL. `q` is correct.
3. The first menu-bar run injected into whatever happened to be focused: the polkit password prompt had taken focus off firefox on its way in. The test now sets focus itself and ABORTS when it cannot confirm it, rather than producing a photograph of nothing.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Alt+hjkl are now the arrow keys, as an [alt] layer in setup/system/keyd/default.conf, emitted below the compositor so they arrive inside every program.

WHAT WAS DECIDED. Build it. Every conflict found is cheaper than the movement it removes, and the owner confirmed by using it that Alt+hjkl is a short stretch of the left little finger where the arrow cluster is a journey for the whole right hand.

HOW IT WAS VERIFIED, none of it by reading the config back:
- A uinput probe injected chords on a device keyd had grabbed and read keyd's own virtual keyboard back. Alt+h emits a BARE Left; Alt+Shift+h, Alt+Ctrl+h and Alt+Ctrl+Shift+h emit Shift+Left, Ctrl+Left and Ctrl+Shift+Left, because keyd strips only the layer's own modifier. Composition needed no configuration, which is what makes these arrow keys rather than an imitation.
- The transient Alt that keyd emits either side of a bare key was measured against Firefox on a headless output. A bare Alt tap opens the menu bar; Alt+h does not, and nor does Alt+h five times over, because keyd presses Control inside the Alt hold. Screenshots compared against a no-injection control, with focus asserted on firefox before each injection.
- Alt+h/j/k/l was asked of twelve programs individually. Only zsh had a daily binding on any of them.

WHAT IT COST. zsh kill-line, which had already been displaced twice (Ctrl+K to Alt+K by TASK-108), is now dropped entirely rather than moved a third time - the owner confirmed it was not being used. The reason and how to restore it are recorded in dot_zshrc where the binding was, in tools/shortcuts.sh, and in the manual. yazi's Alt+j/k are replaced by keys bound to the identical action in the same keymap, so nothing changes there. Firefox loses the Help menu; GTK dialogs lose any h/j/k/l mnemonic, which is the one entry that cannot be enumerated exhaustively.

CHECKS. keyd check passes, and was proven to FAIL on a deliberately broken copy (exit 255 against 0). checks/manual.sh 8/8, checks/sway-bindings.sh and checks/sway-commands.sh clean. checks/session.sh reports 84 passed / 4 failed - the same four failures, verbatim, on the pristine tree with these changes stashed, so none is caused by this work.

STATE. The layer is live: it was installed to /etc/keyd/default.conf and reloaded during the trial, and the bindings there are identical to the repository's. Only the comment block differs, which the next ./sync.sh carries over through apply-config.sh.
<!-- SECTION:FINAL_SUMMARY:END -->
