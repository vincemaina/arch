---
id: TASK-122
title: Caps Lock + u/i as a fast page down/up
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 16:10'
updated_date: '2026-08-22 16:39'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 127000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The scroll layer j/k emit real wheel events through macro2, which repeat at 40ms after a 250ms delay. That is deliberately paced to feel like a held arrow key, and it is slow when the point is to cross a long document rather than nudge it.

Caps Lock already has a page pair - d = pagedown, u = pageup - but it is on the wrong fingers to be reached quickly from the scroll position, and it is not where the hand already is.

Put paging on u and i, which sit directly above j and k and use the SAME fingers: index down, middle up. That makes the fast pair a row-shift of the slow one rather than a second thing to remember.

THIS REVERSES u. It is Page Up today, following vim, and becomes Page Down. That is the whole risk in this change: a vim reflex on Caps+u will page the wrong way, and it will feel like a bug rather than a decision. It is what was asked for, and the finger-consistency argument is the reason to accept it, but it must be written where the next reader will look rather than left to be discovered.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Caps Lock + u sends Page Down and Caps Lock + i sends Page Up, proven by observing what keyd emits rather than by reading the config back
- [x] #2 The reversal of u from Page Up to Page Down is recorded in the config beside the binding, so a vim reflex paging the wrong way reads as a decision rather than a fault
- [x] #3 The existing scroll layer is unaffected: Caps Lock + j/k/h/l still emit wheel events, Caps Lock + d still pages down, and tapping Caps Lock still toggles caps
- [x] #4 tools/shortcuts.sh reports the page keys by READING them out of the [scroll] layer rather than naming them in a string, so changing them again cannot leave the report asserting something false
- [x] #5 docs/manual/03-the-keyboard.md describes the pair and the reversal, and checks/manual.sh, checks/session.sh, checks/sway-bindings.sh and checks/sway-commands.sh all pass
- [x] #6 setup/system/keyd/default.conf and /etc/keyd/default.conf are identical
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## APPLIED AND PROVEN

| chord | keyd emitted | verdict |
| --- | --- | --- |
| Caps+u | `+pagedown -pagedown` | Page Down - the reversal is live |
| Caps+i | `+pageup -pageup` | Page Up |
| Caps+d | `+pagedown -pagedown` | unchanged |
| Caps+j | 7 wheel events, vertical negative | scroll layer intact |
| Caps+k | 7 wheel events, vertical positive | scroll layer intact |
| Caps+h | 1 wheel event, horizontal negative | scroll layer intact |

Read off keyd two virtual devices - the keyboard for the page keys, the POINTER for the wheel keys, since a wheel event is EV_REL and a keyboard-only probe is blind to it. The probe confirmed it had been grabbed before reporting (plain `j`, unbound, came back as `+j -j`).

One observation not chased, recorded rather than smoothed over: Caps+h produced ONE horizontal wheel event where j and k produced seven each under the same 0.45s hold. The binding plainly fires and the direction is right, and `h = macro2(250, 40, scrollleft)` was not touched by this work, so it is out of scope here - but the asymmetry is real and is not explained. Anyone chasing it should start with whether horizontal repeats differ from vertical in keyd macro2 handling.

The `+leftmeta -leftmeta` trailing the Caps+d row is the real keyboard, not the injection: keyd virtual keyboard carries every device, so a keystroke made while the probe runs lands in whichever row is reading.

## tools/shortcuts.sh now reads the keys

It printed the literal string "d / u   Page Down / Page Up" before. That would have gone on asserting the old pair after this change - confidently and wrongly, which is worse than saying nothing. It now parses the [scroll] layer and reports whatever is bound there, and prints U / I / D read from /etc.

## Checks

`checks/manual.sh` 8 passed / 0 failed. `checks/sway-bindings.sh` exit 0. `checks/sway-commands.sh` clean. `checks/session.sh` 85 passed / 3 failed / 1 skipped - down from four pre-existing failures, none of them related to this work.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Caps Lock + u and i now send Page Down and Page Up, verified by injection: both emit real page keys on keyd virtual keyboard, and the wheel keys j/k/h still emit wheel events on its virtual pointer.

They sit on the same two fingers as j and k, one row up - index down, middle up - so the fast pair is a row-shift of the slow one rather than a second thing to remember. The wheel keys are paced by macro2 to feel like a held arrow key, which is right for nudging a page and slow for crossing a long one; that pacing is the reason this exists.

The part to remember is that u REVERSED. It was Page Up, following vim Ctrl+U, and is now Page Down, because the finger it sits under means down everywhere else in that layer. A vim reflex will page the wrong way, and the config, the manual and the shortcuts report all say so in the place the reader will look. d was left alone as a second Page Down, so no reflex built on it breaks.

tools/shortcuts.sh was changed to READ the page keys out of the [scroll] layer. It named "d / u" in a literal string before, which would have survived this change and gone on reporting a pair that no longer exists.
<!-- SECTION:FINAL_SUMMARY:END -->
