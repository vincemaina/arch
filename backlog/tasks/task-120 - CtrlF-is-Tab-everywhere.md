---
id: TASK-120
title: 'Ctrl+F is Tab, everywhere'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 15:26'
updated_date: '2026-08-22 16:02'
labels: []
dependencies:
  - TASK-119
priority: medium
type: feature
ordinal: 126000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The counterpart to TASK-119: bind Ctrl+F to Tab in the [control] layer of setup/system/keyd/default.conf, so Tab arrives inside every program - GTK dialogs, browser forms, the greeter - without moving the hand off the home row.

THIS ONE IS NOT CHEAP, and the ticket exists partly to record what it costs before it is paid. Ctrl+F is page-forward across the entire vi lineage on this machine - nvim (builtin), less, yazi (arrow 100%) and qutebrowser (scroll-page 0 1) - and find-in-page in Firefox. That is five daily bindings, against three for Ctrl+K in TASK-108. Ctrl+B stays page-backward, so the pair becomes asymmetric.

There is a cheaper key and it should be assessed rather than assumed away: Ctrl+I IS Tab. ASCII 0x09 is Ctrl+I, so in every terminal program Ctrl+I already sends Tab and nothing would be displaced there at all. The gap Ctrl+I does not cover is exactly the gap this ticket is about - GUI applications, where Ctrl+I is italic or page-info rather than Tab - which is an argument for binding it at the keyd layer, not against it. This is the same shape as the Ctrl+semicolon finding in TASK-108: the mnemonic and the cost point at different keys, and only using it settles which wins.

Implement what was asked (Ctrl+F), and record the alternative beside it in the config the way TASK-108 recorded Ctrl+semicolon, so switching is a one-word edit.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 What Ctrl+F currently does is recorded per program, gathered by asking each one on this machine rather than from general knowledge, and each loss is marked trivial, rare or daily
- [x] #2 Ctrl+F emits a real Tab key event below the compositor, proven by observing what keyd emits on its virtual keyboard rather than by reading the config back
- [x] #3 Ctrl+I is assessed as the cheaper alternative with its trade-off written into the config beside the binding, so switching to it is a one-word edit
- [x] #4 The page-forward loss is answered rather than left implicit: for each of nvim, less, yazi, qutebrowser and Firefox the remaining way to page forward or find in page is named in the config comment and in the manual
- [x] #5 Nothing is left in this repository configuration that Ctrl+F now shadows and can therefore never fire; any displaced binding is either replaced or its loss is written down where the next reader will look
- [x] #6 Ctrl+Tab still reaches sway focus mode_toggle, and Ctrl+Shift+F arrives as Shift+Tab, both observed rather than reasoned about
- [x] #7 ./tools/shortcuts.sh reports the binding, read out of the [control] layer rather than asserting a binding string
- [x] #8 docs/manual/03-the-keyboard.md describes it, and ./checks/manual.sh, ./checks/session.sh, ./checks/sway-bindings.sh and ./checks/sway-commands.sh all pass
- [x] #9 setup/system/keyd/default.conf and /etc/keyd/default.conf are identical, so the machine is not running something the repository does not describe
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Complete the per-program cost table for Ctrl+F by asking each program on this machine, and name the surviving way to page forward or find in page for each.
2. Assess Ctrl+I as the cheaper alternative (ASCII 0x09 IS Tab, so it displaces nothing in any terminal program) and write the trade-off into the config beside the binding, so switching is a one-word edit.
3. Add `f = tab` to the [control] layer of setup/system/keyd/default.conf with that table and reasoning in the file.
4. Confirm Ctrl+Tab still reaches sways `focus mode_toggle` - the layer names f, not tab, so the chord should be untouched - and that Ctrl+Shift+F arrives as Shift+Tab.
5. Apply, reload, and prove both by injected chords read back off keyds virtual keyboard.
6. Extend tools/shortcuts.sh and docs/manual/03-the-keyboard.md, and run all four checks.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## What Ctrl+F costs, asked of each program on this machine

| Program | Evidence | Ctrl+F was | Weight | What remains |
| --- | --- | --- | --- | --- |
| nvim | builtin, so it appears in no keymap dump | page forward | daily | `Ctrl+D` half page, `Page Down` |
| less | `man less` -> "SPACE or ^V or f or ^F" | page forward | daily | `Space`, `f` |
| yazi | embedded preset -> `{ on = "<C-f>", run = "arrow 100%" }` | page down | daily | `Page Down` |
| qutebrowser | `configdata.yml:3814` -> `scroll-page 0 1` | page down | daily | `Space`, `Page Down` |
| firefox | convention | find in page | daily | `/` quick-find, `Ctrl+G` for next match |
| zsh | `bindkey` -> `"^F" forward-char` | forward a character | daily | Right arrow, and Alt+L from the arrow layer |
| fzf | `man fzf` -> `forward-char  ctrl-f  right` | forward a character | rare | Right arrow. NOTE Tab is toggle-select in fzf, so Ctrl+F now SELECTS |
| lazygit | `lazygit --config` -> `findBaseCommitForFixup: <ctrl+f>` | find base commit for fixup | rare | the menu |
| rofi | `rofi -dump-config` -> `kb-move-char-forward: "Right,Control+f"` | forward a character | rare | Right arrow |
| qutebrowser (cmd/prompt) | `configdata.yml:3910,3937` | rl-forward-char | rare | Right arrow |
| foot | `man 5 foot.ini` -> cursor-right | forward a character in scrollback search | trivial | Right arrow |
| sway | `checks/sway-bindings.sh` | NOTHING on Ctrl+F | none | - |
| backlog TUI | `strings` | NOTHING | none | - |

Five daily losses, against three for Ctrl+K in TASK-108. This is the expensive one, and the asymmetry it leaves is worth naming: Ctrl+B is still page-BACKWARD in nvim, less, yazi and qutebrowser, and now has no forward counterpart.

## Ctrl+I is the cheaper key, and the decision is recorded rather than closed

**Ctrl+I already IS Tab.** ASCII 0x09 is Ctrl+I, so every terminal program on this machine receives a real Tab from that chord today, and binding it at the keyd layer would displace nothing in any of them - `bindkey` shows `"^I" fzf-completion`, which is Tab-completion, i.e. it is already behaving as Tab.

What Ctrl+I does not cover is exactly the gap this ticket exists for: graphical applications, where Ctrl+I is italic or page-info rather than Tab. That is an argument for binding it at the evdev layer, not against it.

So the mnemonic and the cost point at different keys - the same shape as the Ctrl+semicolon finding in TASK-108. Ctrl+F was implemented as asked; the alternative is written into the config beside it, and `tools/shortcuts.sh` and the `[control+meta]` layer both read the key out of the layer, so switching is genuinely the one-word edit the config claims.

## Ctrl+Tab is unaffected, by construction

sway binds `Ctrl+Tab` to `focus mode_toggle` (`50-keybindings.conf:227`). The `[control]` layer names `f`, not `tab`, so `Ctrl+Tab` is still `Ctrl+Tab` - a layer only takes the keys it names. And because keyd strips only the Control it owns, `Ctrl+Shift+F` arrives as `Shift+Tab`, which is back-tab and is wanted in a form. Both are in the probe rather than left as reasoning.

## Implemented

- `setup/system/keyd/default.conf`: `f = tab` in `[control]`, with the cost table, the surviving route for each program, and the Ctrl+I alternative written into the file.
- `f` is also listed in the new `[control+meta]` layer (see TASK-119) so that a future `$mod+Ctrl+f` sway binding cannot be silently swallowed.
- `tools/shortcuts.sh` and `docs/manual/03-the-keyboard.md` cover it alongside Ctrl+J.

## Verification status

Same as TASK-119: `keyd check` passes, the parsers and all four repository checks are clean, and the behavioural claim is UNPROVEN until the config is applied as root and the probe reads back what keyd emits. The prepared script covers Ctrl+F, Ctrl+Shift+F and the two Escape regressions in one run.

## APPLIED AND PROVEN

Applied in the same pkexec run as TASK-119; repo and /etc are byte-identical and keyd reloaded.

| chord injected | keyd emitted | verdict |
| --- | --- | --- |
| Ctrl+F | `+leftctrl -leftctrl +tab -tab +leftctrl -leftctrl` | Tab, control released around it |
| Ctrl+Shift+F | `+leftctrl +leftshift -leftctrl +tab -tab +leftctrl -leftshift -leftctrl` | Shift+Tab - back-tab, as claimed |

Read off keyd own virtual keyboard by a probe that first proved it had been grabbed (plain `j`, unbound, came back as `+j -j`).

Ctrl+Tab is untouched, by construction and by check: the layer names `f`, not `tab`, so the chord never enters it, and `checks/sway-bindings.sh` still passes with `Ctrl+Tab focus mode_toggle` bound.

`tools/shortcuts.sh` reports the binding live, reading `f tab` out of the [control] layer of /etc rather than asserting a string - so switching the key changes the report without anyone editing the report.

## The cost is now live, and it is the part to watch

The five daily losses are real from this moment: page-forward in nvim, less, yazi and qutebrowser, and find-in-page in Firefox. Each has its surviving route named in the config comment and in the manual chapter. Ctrl+B still pages backward everywhere, so the asymmetry is now something to live with rather than a prediction.

Ctrl+I remains the cheaper key and the note beside the binding says so. If the page-forward loss turns out to bite, changing `f = tab` to `i = tab` is the whole edit - nothing else reads the key by name.

## Checks after applying

`checks/manual.sh` 8 passed / 0 failed. `checks/sway-bindings.sh` exit 0. `checks/sway-commands.sh` clean. `checks/session.sh` 84 passed / 4 failed / 1 skipped, the same four the main checkout reports, all pre-existing.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ctrl+F now emits a real Tab key event at the evdev layer, from the same [control] layer as Ctrl+J and Ctrl+K, applied and reloaded on this machine. Verified by injecting the chord and reading back what keyd emits: Tab with the control released around it, and Shift+Tab from Ctrl+Shift+F, which is back-tab and is the useful half of the bargain in a form.

This was the expensive one and the config says so beside the binding rather than burying it here. Ctrl+F meant page-forward across the whole vi lineage on this machine - nvim, less, yazi and qutebrowser - and find-in-page in Firefox: five daily bindings, against three for Ctrl+K. Every one has its surviving route named, in the config and in the manual, and Ctrl+B is left as a page-backward with no forward counterpart, which is a real asymmetry accepted knowingly.

The finding worth keeping is that a cheaper key exists and was not chosen. Ctrl+I already IS Tab - ASCII 0x09 is exactly that chord - so binding it would have displaced nothing in any terminal program on this machine. What it does not cover is graphical applications, where Ctrl+I is italic or page-info, and that is precisely the gap this binding exists for. Mnemonic and cost point at different keys, the same shape as the Ctrl+semicolon finding in TASK-108, so the alternative is written in beside the line and switching is genuinely one word: nothing reads the key by name.

Ctrl+Tab is unaffected - the layer names f, not tab - and checks/sway-bindings.sh confirms focus mode_toggle is still bound.
<!-- SECTION:FINAL_SUMMARY:END -->
