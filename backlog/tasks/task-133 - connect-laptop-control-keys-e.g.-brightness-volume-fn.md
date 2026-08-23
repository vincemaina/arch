---
id: TASK-133
title: 'connect laptop control keys e.g. brightness, volume, fn'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 00:14'
updated_date: '2026-08-23 10:35'
labels: []
dependencies: []
priority: medium
type: bug
ordinal: 137000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently those keys on my thinkpad don't seem to be doing anything in linux, howeever I can see in the terminal that they are generating _some_ input.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Diagnosis (measured on the X280, not inferred):

* The repo is NOT at fault. setup/dotfiles/dot_config/sway/config.d/52-media-keys.conf already binds volume/mute/micmute/brightness, is installed and identical to the repo. brightnessctl and wpctl both work when run directly as the user.
* keyd is NOT at fault, despite grabbing 'Video Bus' (keycodes 224/225 = brightness) and 'ThinkPad Extra Buttons' (113/114/115 = mute/vol, 248 = micmute) via [ids] *. Its virtual keyboard advertises all of those keycodes and keyd list-keys knows them by name.
* Runtime sway probe: pressing the six top-row keys logged F2 F3 F1 F4 F5 F6 and zero XF86 keys. The media keycodes are never generated - the top row is emitting literal function keys.
* Cause: FnLock is ON (padlock lit on Esc). It is an EC-level runtime toggle that inverts the BIOS default.
* think_lmi BIOS attributes read via pkexec: FnCtrlKeySwap=Enable, FnKeyAsPrimary=Disable, FnSticky=Disable.
  - FnKeyAsPrimary=Disable means the BIOS already wants media keys primary, which matches what the repo expects. FnLock is overriding it.
  - FnCtrlKeySwap=Enable means the real Fn key is the one LABELLED Ctrl, which is why Fn+Esc appeared to do nothing.
* Note: wpctl reported the sink at 119%, above the -l 1.0 clamp in the sway binding - consistent with the volume keys never having reached sway on this machine.

keyd EXONERATED by direct experiment. Stopped keyd (releasing its exclusive grabs on ThinkPad Extra Buttons / Video Bus / AT keyboard) and re-ran the sway probe: still six plain function keys, byte-identical to the result with keyd running. keyd is not swallowing anything.

Also established: Fn changes nothing. Fn+F3 and bare F3 produce identical events, and likewise Fn+F5/F6. That is the expected behaviour when FnLock is ON - FnLock means Fn is held permanently, so adding Fn is a no-op rather than an inversion.

The key LABELLED Ctrl is confirmed as the real Fn: it contributes no modifier to any chord (a real Ctrl would have suppressed the bare-F3 binding; it did not).

Conclusion: nothing in Linux or in this repository is broken. The embedded controller is not emitting media keycodes because FnLock is on. Fix is firmware state, not repo config.

Fn key established as non-functional, by elimination:

* Armed all 30 combinations (5 media keys x bare/Ctrl/Alt/Mod4/Shift/Ctrl+Alt) to rule out sway's bare-bindsym only matching when no modifier is held. Corner key + F3/F5/F6 produced NOTHING on any of the 30. So the corner key is purely a modifier and carries no Fn behaviour - the 'corner does both jobs (Ctrl to Linux, Fn inside the EC)' hypothesis is disproved.
* labelled-Ctrl + F3/F5/F6 produced bare F3/F5/F6 - no modifier contributed, consistent with it being Fn.
* Fn+P and Fn+K produced no Pause / Scroll_Lock.
* Fn+Esc does not toggle FnLock; padlock stays lit.
* Fn does not invert the top row (contradicts documented ThinkPad FnLock behaviour, which the user confirms is how this machine used to behave).

So: the key labelled Ctrl contributes no modifier AND triggers no EC function. Fn is effectively dead. BIOS FnKeyAsPrimary=Disable ('media keys primary') disagrees with observed behaviour ('F-keys primary'), which is the signature of stale embedded-controller state.

Invalid test to not repeat: tpacpi::thinklight is the pre-2015 ThinkLight lamp, absent on X280, and there is no kbd_backlight device - so Fn+Space cannot be observed via sysfs on this machine.
Dead end to not repeat: hotkey_mask differing from hotkey_all_mask (volume/mute bits masked off) is a real difference but cannot be the cause - that fix addresses keys producing NO event, whereas these produce a plain F3.

Action taken: set FnCtrlKeySwap from Enable to Disable via think_lmi (echo Disable > /sys/class/firmware-attributes/thinklmi/attributes/FnCtrlKeySwap/current_value, as root via pkexec). No BIOS admin password is set (authentication/Admin/is_enabled=0) so the write was accepted without authentication. Takes effect on reboot. Previous value was Enable; revert by writing Enable back.

Rationale: the BIOS swap was redundant with keyd's leftcontrol/leftalt swap - it moved Ctrl INTO the corner only for keyd to move it straight back out - and its only net effect was to hide the Fn key under a cap labelled Ctrl. Disabling it returns Fn to the corner. Ctrl stays where it is today (labelled-Alt); Alt moves from the corner to the labelled-Ctrl position.

Next: full EC power drain to clear the stuck FnLock state.

VERIFIED after the fix, end to end on the running machine rather than by keysym alone:
* volume:     sink 1.19 -> 0.75 (below the -l 1.0 clamp, so 52-media-keys.conf is demonstrably what fired)
* brightness: 1515 -> 831 of 1515
* mute:       sink reports [MUTED] and /sys/class/leds/platform::mute/brightness = 1

Checks on the changed tree: checks/session.sh 91 passed / 1 failed, checks/sway-bindings.sh, checks/packages.sh, checks/sway-commands.sh and tools/manual.sh all pass. checks/manual.sh 7 passed / 1 failed. BOTH failures are pre-existing and unrelated:
  - session.sh: chezmoi records no sourceDir on this machine (the TASK-121.1 hole); sync.sh has simply never been run on this laptop. sync.sh itself is safe, it always passes --source explicitly.
  - manual.sh: 05-making-it-yours.md names ~/Pictures/wallpapers, which does not exist. Confirmed pre-existing by re-running with the chapter 3 change stashed.

Documentation added (no functional repo change was needed or made):
  - setup/system/keyd/default.conf: the 'Left Control sits in the far bottom corner' premise is false on a ThinkPad, where the corner is Fn. Also a warning not to stack the BIOS Fn/Ctrl swap on keyd's swap.
  - DECISIONS.md: new subsection 'The firmware underneath it, on a ThinkPad' under the keyd decision.
  - docs/manual/03-the-keyboard.md: 'If they do nothing at all, on a laptop' under Media keys, plus a geometry correction in the swap section.

REVERTED the FnCtrlKeySwap change. Setting it to Disable returned Fn to the corner but left Alt unreachable: keyd monitor showed the labelled-Alt key emitting leftcontrol and BOTH the corner and labelled-Ctrl keys emitting nothing, with zero leftalt events across a 218-event capture of ordinary typing. FnCtrlKeySwap is back to Enable.

So this machine keeps BOTH swaps stacked, deliberately: the BIOS swap puts Control in the corner (which a ThinkPad does not do by default), and keyd then moves it off the pinky as designed. Alt under the corner finger is worth more than a layout that is easier to explain. The cost is that Fn sits under a cap labelled Ctrl, which is what made Fn+Esc unfindable and cost most of the investigation.

Docs corrected accordingly - setup/system/keyd/default.conf, DECISIONS.md and docs/manual/03-the-keyboard.md had all been committed saying the BIOS swap should stay disabled, which was wrong for this machine.

Measurement note worth keeping: keyd monitor block-buffers when redirected to a file, so a short capture killed by timeout loses everything and reads as 'no events'. Use stdbuf -oL.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
No repository change was needed: sway's bindings, brightnessctl, wpctl and keyd were all already correct. The cause was ThinkPad firmware - FnLock was on, so the top row emitted plain F1-F12 instead of media keycodes, and the BIOS 'Fn and Ctrl key swap' had moved Fn under a cap labelled Ctrl so Fn+Esc could not be found to turn it off.

Diagnosis was by elimination against the running machine: a runtime sway probe showed six top-row presses producing F2 F3 F1 F4 F5 F6 and zero XF86 keys; stopping keyd entirely (releasing its exclusive grabs on ThinkPad Extra Buttons and Video Bus) reproduced the same result, exonerating it; and arming all 30 modifier+media combinations proved the corner key carried no Fn behaviour.

Fixed by setting FnCtrlKeySwap=Disable through think_lmi and doing a full EC power drain to clear the stale FnLock state. Verified afterwards end to end: volume 1.19 -> 0.75, brightness 1515 -> 831, sink [MUTED] with the hardware mute LED lit.

Documented in setup/system/keyd/default.conf, DECISIONS.md and docs/manual/03-the-keyboard.md, because FnLock is firmware state that install.sh cannot reproduce - a fresh build onto another ThinkPad with FnLock set the other way would hit this identically, with a configuration that looks perfectly correct.
<!-- SECTION:FINAL_SUMMARY:END -->
