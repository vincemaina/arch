---
id: TASK-124
title: 'Take Ctrl+F back out: it is not Tab any more'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 16:48'
updated_date: '2026-08-22 17:05'
labels: []
dependencies: []
ordinal: 129000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-120 bound Ctrl+F to Tab in the [control] layer of setup/system/keyd/default.conf, and recorded at the time that it was the expensive one: five daily losses (page-forward in nvim, less, yazi and qutebrowser, find-in-page in Firefox) against three for Ctrl+K, plus a named asymmetry - Ctrl+B left as a page-backward with no forward counterpart.

Having used it, the trade is not worth it. Remove the binding. Ctrl+Shift+F goes with it and needs no separate work: it was never a binding of its own, it is keyd passing Shift through onto the rewritten Tab.

Keep the research rather than deleting it. TASK-120's per-program table stays as the record, and the config keeps a short note saying the key was tried here and taken back out - this repository's stated failure mode is a fix that did not work and was kept, and the mirror of it is a key that gets re-proposed every six months because nothing says it was already tried.

Ctrl+I is the standing alternative if home-row Tab is wanted again: ASCII 0x09 IS Ctrl+I, so it displaces nothing in any terminal program and adds only the graphical half, which is the half the binding ever existed for. Do not silently re-bind it; that is a separate decision.

Ctrl+J (Enter), Ctrl+H (Backspace) and the Ctrl+K / Ctrl+semicolon Escape trial are NOT in scope and stay exactly as they are.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The [control] layer of setup/system/keyd/default.conf no longer binds f, and `keyd check` passes on the result
- [x] #2 Ctrl+F is observed doing what it did before the binding - reaching the focused program as Ctrl+F - by injecting the chord and reading back what keyd emits, not by reading the config
- [x] #3 Ctrl+Shift+F no longer arrives as Shift+Tab, observed the same way
- [x] #4 The [control+meta] layer and the prose that states how many keys it must keep in step with [control] are both correct after the removal, so the trap that section exists to prevent is still described accurately
- [x] #5 Ctrl+J, Ctrl+H, Ctrl+K and Ctrl+semicolon are unchanged and still emit what they did, observed in the same probe run
- [x] #6 Everything the binding displaced is put back where this repository removed it: nvim's init.lua comment about page-forward being gone no longer claims something untrue
- [x] #7 docs/manual/03-the-keyboard.md no longer teaches Ctrl+F as Tab, and ./checks/manual.sh passes
- [x] #8 ./tools/shortcuts.sh no longer reports the binding, still reading the key out of the layer rather than asserting a string
- [x] #9 setup/system/keyd/default.conf and /etc/keyd/default.conf are identical afterwards, so the machine is not running something the repository does not describe
- [x] #10 TASK-120 records that it was reverted and why, so its per-program table is not read as current
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Replace the CTRL+F IS TAB block in setup/system/keyd/default.conf with a short note recording that the key was tried here and taken back out, why, and that Ctrl+I is the standing alternative - so the next reader does not re-propose f.
2. Remove `f = C-M-f` from [control+meta], and correct the prose that counts how many keys the two layers must keep in step (five -> four) and the Shift note that names Ctrl+Shift+F.
3. Restore what the binding displaced: the nvim init.lua comment claiming page-forward is gone.
4. Take Ctrl+F out of docs/manual/03-the-keyboard.md - the shared paragraph and the cost table - leaving Ctrl+J and Ctrl+H intact.
5. Check tools/shortcuts.sh reads the key out of the layer, so it drops the row on its own.
6. keyd check, then apply to /etc and reload, then prove by injection: Ctrl+F reaches the program as Ctrl+F, Ctrl+Shift+F is no longer Shift+Tab, and Ctrl+J/H/K/semicolon are unchanged.
7. Run checks/manual.sh, checks/session.sh, checks/sway-bindings.sh, checks/sway-commands.sh.
8. Record the reversal on TASK-120 so its table is not read as current.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Removed from the repository

- `setup/system/keyd/default.conf`: `f = tab` is gone from [control], and `f = C-M-f` from [control+meta]. The 56-line CTRL+F IS TAB block is replaced by a 31-line note recording that the key was tried here and taken back out, what it cost, that Ctrl+Shift+F was passthrough rather than a binding, and that Ctrl+I is the key to spend if home-row Tab is ever wanted again. `keyd check` passes.
- The [control+meta] prose is corrected in both places it counts: five keys to keep in step became four (k, semicolon, j, h), and "the other three are listed" became two. That section exists to describe a trap and a wrong count is how it stops describing it.
- The Shift sentence there named Ctrl+Shift+F; it now names Ctrl+Shift+J, which is what remains.
- `setup/dotfiles/dot_config/nvim/init.lua`: the comment claiming page-forward was gone from nvim was left saying something untrue by the removal. It now says <C-f> pages forward again and points at the keyd config for why f was the wrong key to spend.
- `docs/manual/03-the-keyboard.md`: the section is "Enter and Backspace", the 26-line Ctrl+F cost table and the Ctrl+I note are out, the Shift example is Ctrl+Shift+J, and one new paragraph says Tab is deliberately NOT on this layer and names Ctrl+I as the key it would cost nothing on. An absence with no explanation is how this gets re-proposed.
- `tools/shortcuts.sh`: two changes, both so it keeps reading the layer rather than asserting a string. The Shift sentence was the one hardcoded fact in that function - it said "Ctrl+Shift+F is Shift+Tab" - and is now derived from the first pair the layer yields. And the Ctrl+F cost trailer is guarded on `^f tab$` rather than any key bound to tab, because printing that page-forward table for `i = tab` would be a lie: Ctrl+I costs none of it.

## Verified without root

- `keyd check setup/system/keyd/default.conf` - no errors.
- The [control] layer now yields exactly `j enter` and `h backspace` to the awk in shortcuts.sh, so the Tab row and its trailer both drop out on their own.
- The derived Shift sentence was exercised against those pairs rather than read: it produces "Ctrl+Shift+J is Shift+Enter".
- `./checks/manual.sh` 8 passed / 0 failed. `./checks/session.sh` 91 passed / 0 failed / 1 skipped. `./checks/sway-bindings.sh` exit 0. `./checks/sway-commands.sh` clean. `bash -n tools/shortcuts.sh` clean.
- `diff /etc/keyd/default.conf setup/system/keyd/default.conf` differs by exactly the two removed binding lines and the prose around them - nothing else in the live file has drifted from the branch.

## NOT DONE: the machine is still running the binding

AC #2, #3, #5, #8 and #9 are unmet and are all one step: applying the config needs root, and `sudo -n` fails in this session. /etc/keyd/default.conf still contains `f = tab`, so Ctrl+F is still Tab on this machine and `tools/shortcuts.sh` - which reads /etc, not the repo - still reports it.

Not escalated with pkexec deliberately: it would throw a password dialog at a screen nobody may be sitting in front of, and it would hang this job if nobody was.

To finish:

    cd <this worktree> && sudo install -Dm644 setup/system/keyd/default.conf /etc/keyd/default.conf && sudo keyd reload

Then prove it by injection rather than by reading the config back - the probe apparatus and its trap (keyd ignores a uinput device that is not keyboard-shaped, and prints nothing rather than failing) are in the scripting-traps skill and in TASK-120's notes.

## Gap noticed, not fixed

`checks/session.sh` does not compare setup/system/keyd/default.conf with /etc/keyd/default.conf. It checks that /etc parses, that the Alt/Control swap is in it, and that keyd is running - so a machine running a keyd config the repository no longer describes passes cleanly, which is exactly the state this task leaves it in until the command above is run. TASK-120 and TASK-123 both had to assert that identity by hand. Worth its own ticket.

## APPLIED AND PROVEN

Applied with pkexec, gated the way apply-config.sh gates it - `keyd check` on the source before it goes near /etc, again on the installed file, and a restore from backup if the installed one does not parse. The previous config is at `/etc/keyd/default.conf.before-task-124`, which keyd does not load because it does not end in .conf. `diff /etc/keyd/default.conf setup/system/keyd/default.conf` is empty and keyd is active.

## What keyd emits, by injection

A uinput keyboard, grabbed by keyd (journal: `DEVICE: match dead:beef:0bcc010d (keyd-probe-task-124)`), with an unbound key as the positive control. Note the swap: the chord a human calls Ctrl+F is injected as KEY_LEFTALT + KEY_F.

| Injected | keyd emits | |
| --- | --- | --- |
| plain f | `+f -f` | positive control - the device really is grabbed |
| Ctrl+F | `+leftctrl +f -f -leftctrl` | Ctrl+F, reaching the program as itself again |
| Ctrl+Shift+F | `+leftctrl +leftshift +f -f -leftshift -leftctrl` | no Shift+Tab |
| Ctrl+J | `+leftctrl -leftctrl +enter -enter +leftctrl -leftctrl` | unchanged |
| Ctrl+H | `+leftctrl -leftctrl +backspace -backspace +leftctrl -leftctrl` | unchanged |
| Ctrl+K | `+leftctrl -leftctrl +esc -esc +leftctrl -leftctrl` | unchanged |
| Ctrl+semicolon | `+leftctrl -leftctrl +esc -esc +leftctrl -leftctrl` | unchanged |

## The first probe run measured nothing, and said so wrongly

Worth recording, because it is a new instance of the apparatus trap already in the scripting-traps skill rather than a repeat of the one written there.

The probe reads keyd's VIRTUAL KEYBOARD, which carries the output of every keyboard on the machine and not just the probe device. A Super key was held down on the real keyboard across four of the seven cases, so Ctrl+J, Ctrl+H and Ctrl+K were routed through the [control+meta] layer and came back as C-M-j, C-M-h and C-M-k. The probe reported three FAILs. All three were correct behaviour from the composite layer - the bindings were never tested at all.

The tell was `+125` (KEY_LEFTMETA) appearing in output for a chord that never injected it, and a matching `-125` four cases later.

Second probe: before each injection it asks the virtual keyboard which keys are physically down (EVIOCGKEY) and waits rather than measuring, and it runs every case twice. It waited twice, visibly, and the contaminated cases stopped being contaminated.

Ctrl+J and Ctrl+H were still marked DISAGREED by that run, on strict string equality between the two readings. That check was too strict for a machine somebody is typing on: the difference in both cases was a trailing stray event from the real keyboard, and the substantive event was present in all four readings - `+enter` in both readings of Ctrl+J, `+backspace` in both readings of Ctrl+H. Recorded rather than smoothed over, because "the probe said FAIL and I decided it was fine" is worth a reader being able to audit.

## Checks after applying

`./checks/session.sh` 92 passed / 0 failed / 0 skipped. `./checks/manual.sh` 8 passed / 0 failed. `./checks/sway-bindings.sh` exit 0. `./checks/sway-commands.sh` clean.

`./tools/shortcuts.sh`, now reading the updated /etc, prints Ctrl+J and Ctrl+H only, no Tab row, no Ctrl+F cost paragraph, and its Shift sentence reads "Ctrl+Shift+J is Shift+Enter" - derived from the layer, which is what that edit was for.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ctrl+F is not Tab any more, on this machine and in the repository.

`f = tab` is out of the [control] layer and `f = C-M-f` out of [control+meta]. Ctrl+Shift+F went with it and needed no work of its own: it was never a binding, only keyd passing Shift through onto the rewritten Tab.

TASK-120's measurement was not wrong and is not discarded - it is the reason. Page-forward across nvim, less, yazi and qutebrowser plus find-in-page in Firefox, five daily bindings against three for Ctrl+K, with Ctrl+B left as a page-backward with no forward counterpart. It was an accurate price and too high a one, which only using it could settle. A 31-line note replaces the 56-line one so the key is not re-proposed from scratch, and names Ctrl+I as the key to spend if home-row Tab is ever wanted again - deliberately not bound, because that is a separate decision.

Four places would have been left describing something untrue and are corrected: nvim's init.lua comment about page-forward, the manual's cost table and Shift example, the [control+meta] prose that counts how many keys it keeps in step with [control], and tools/shortcuts.sh - which had exactly one hardcoded fact in a function built to have none ("Ctrl+Shift+F is Shift+Tab") and now derives it from the layer.

Verified by injection on a uinput keyboard keyd had grabbed, with an unbound key as the positive control, not by reading the config back: Ctrl+F emits `+leftctrl +f -f -leftctrl` and Ctrl+Shift+F emits Ctrl+Shift+F, while Ctrl+J, Ctrl+H, Ctrl+K and Ctrl+semicolon still emit Enter, Backspace and Escape. /etc/keyd/default.conf is byte-identical to the repository. session 92/0/0, manual 8/8, sway-bindings and sway-commands clean.

The first probe run reported three false FAILs because a Super key was held on the real keyboard and routed those chords through [control+meta]; the second waits for a quiet keyboard before measuring. Recorded in the notes as a fresh instance of the apparatus trap rather than quietly rerun.
<!-- SECTION:FINAL_SUMMARY:END -->
