---
id: TASK-18
title: 'Tune keyboard, pointer and cursor for responsiveness'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-19 18:16'
updated_date: '2026-08-20 13:02'
labels:
  - desktop
  - feel
dependencies:
  - TASK-17
references:
  - 'https://man.archlinux.org/man/sway-input.5'
priority: medium
type: enhancement
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
No input tuning exists at all. The sway config sets only xkb_layout gb; repeat delay and rate are left at defaults, which feel sluggish when navigating by keyboard, and the touchpad block is still commented-out upstream example text. No cursor theme or size is set either, which is why cursors change appearance between native Wayland and XWayland windows. These are small settings with a disproportionate effect on how immediate the system feels.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Key repeat delay and rate are set deliberately and recorded, not left at defaults
- [x] #2 Touchpad behaviour - tap, natural scroll, disable-while-typing - is configured for laptop machines
- [x] #3 A cursor theme and size are set and applied consistently across native Wayland, XWayland and GTK applications
- [x] #4 Settings are verified against the live session rather than assumed to have applied
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Key repeat set to 250ms delay and 40 per second against defaults of 600 and 25, with the reasoning recorded in the fragment and DECISIONS.md rather than the numbers appearing unexplained.

Touchpad configured with tap, natural scroll, disable-while-typing and middle emulation. No machine profile was needed: sway input type:touchpad matches only devices that exist, so the block is inert on a VM or desktop. That avoids a dependency on TASK-14.

Cursor set to Adwaita 24 in three places because three different consumers read three different sources - the sway seat for the compositor and its windows, XCURSOR_THEME for XWayland and anything started as a user unit, and GTK settings.ini which reads neither. Missing one is what makes a cursor change appearance between windows.

Added an Input section to checks/session.sh that asks swaymsg -t get_inputs what the compositor actually applied rather than trusting the file, and checks XCURSOR_THEME. The JSON extraction is grep-based to avoid adding jq as a dependency; verified against realistic swaymsg output.

The XCURSOR_THEME check will fail until a fresh login even after a successful sync, because environment.d is read when the user manager starts. The failure message says so.

AC #4 verified on the machine: checks/session.sh reports repeat_delay 250, repeat_rate 40 and XCURSOR_THEME Adwaita at size 24, all read back from the live session via swaymsg and the environment rather than from the files.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Key repeat set to 250ms delay and 40 per second against defaults of 600 and 25, which are tuned for not repeating by accident and cost real time on a keyboard-driven desktop. Touchpad configured without needing a machine profile, since sway input type:touchpad matches only devices that exist. Cursor set to Adwaita 24 in three places because three consumers read three different sources - the sway seat, XCURSOR_THEME for XWayland and user units, and GTK settings which reads neither - and missing one is what makes a cursor change appearance between windows. Verified against the live session rather than the files.
<!-- SECTION:FINAL_SUMMARY:END -->
