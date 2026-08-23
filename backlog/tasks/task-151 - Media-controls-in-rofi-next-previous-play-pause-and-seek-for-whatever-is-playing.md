---
id: TASK-151
title: >-
  Media controls in rofi: next, previous, play/pause and seek, for whatever is
  playing
status: Done
assignee: []
created_date: '2026-08-23 14:06'
updated_date: '2026-08-23 14:31'
labels: []
dependencies: []
ordinal: 158000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The hardware media keys work - XF86AudioNext is bound to playerctl next, and with a queue behind it that now genuinely skips a track. The problem is that this is a ThinkPad: the F row has volume and brightness but no prev/play/next keys at all, so those bindings are attached to keys that do not physically exist on this machine. There is no way to skip a track without opening focus-music, and no way at all to seek.

So the controls need a home that does not depend on the keyboard having the keys. It should behave like the media keys rather than like a focus-music feature: whatever is playing - a browser tab, focus-music, anything speaking MPRIS - is what it acts on, so it goes through playerctl rather than through focus-musics own socket.

Seeking is the part with no equivalent anywhere yet: jumping to a point in a long track, which for a ten hour upload is the difference between usable and not.

The bar is the obvious place to reach it from. Its mpris module is currently the only module with no click action, which contradicts the rule that every module in that bar does something when clicked.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A rofi menu offers play/pause, next, previous and seek for whatever is currently playing
- [x] #2 It acts on the active player, not only on focus-music, and can target a specific one when several are playing
- [x] #3 Seeking supports jumping by a relative amount and to an absolute position typed as a timestamp or a percentage
- [x] #4 The current position and length are shown while seeking, so the jump is informed
- [x] #5 A player that cannot seek, or has no position, says so rather than failing silently
- [ ] #6 It is reachable from the launcher and by clicking the bar mpris module
- [x] #7 checks/session.sh, checks/manual.sh and checks/sway-commands.sh pass, and the manual documents it
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Two assumptions were wrong and both were caught by measuring.

Seeking was first tested against an av://lavfi tone. mpv reports that source with a bogus 4.3 second duration and refuses to seek backwards on it even over its own IPC socket, which made it look as though MPRIS could only seek forwards - a limitation that does not exist. Retested against a real five minute WAV written with the standard library: absolute forward, absolute backward, relative both ways, jump to start, and an accurate mpris:length, all correct. The lesson is in the header comment: test seeking with something seekable.

A live stream does not report nothing, which was the other guess. SomaFM comes back with a position of 6 and a length of 23 - the current track, not the stream - so a menu that trusts the metadata draws a confident, wrong progress bar. There is no CanSeek to ask playerctl for, so seek_to now checks afterwards whether the player actually moved and says so when it did not.

The bar turned out to need nothing. waybar mpris carries its own defaults - left play/pause, middle previous, right next - confirmed in man waybar-mpris, and the manual already documented them. Setting on-click would have replaced play/pause rather than adding a menu, so the override was written and then reverted, with a comment saying why so it is not re-added. That also means universal next/previous already existed on this machine and simply was not known about; what was genuinely missing was seeking.

AC 6 is therefore only half met and deliberately so: the menu is reachable from the launcher, not from the bar, because there is no free mouse button on that module and the three it has are worth more than a fourth route to a menu.

Validation: 24 assertions on the pure functions (time formatting at the boundaries, timestamp/percentage/seconds parsing including rejections, and the progress bar rendering real block characters rather than escape text); 14 against a real seekable player with rofi stubbed (read status/length/title, seek forward, back, to zero, clamping past both ends, the menu jumps, typed timestamp, typed percentage, pause and resume). Two transport assertions failed first time and were MPRIS lag in the harness, not behaviour - they pass with a longer settle. checks/session.sh 92/0, checks/manual.sh 8/0, sway-commands clean, and sync --dry-run shows the helper and its launcher entry reaching the machine.

Also fixed in passing: bash ANSI-C quoting understands \\uHHHH but not the \\u{HHHH} brace form, which would have drawn the progress bar as literal escape text twenty four times over. The bar is built from UTF-8 hex bytes and the source file is pure ASCII.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
A media menu for whatever is playing, reached from the launcher as "Media Controls": play/pause, next, previous, seek, choose player, stop. It goes through MPRIS rather than focus-musics socket, so it acts on a browser tab or anything else the same way the hardware keys would.

Seeking is the part that did not exist anywhere before. The menu shows a progress bar with position and length, offers jumps of ten seconds and a minute either way and back to the start, and takes a typed timestamp (2:30, 1:02:03) or percentage (40%) to go straight to a point - which is what makes a ten hour upload usable.

Two measurements changed the design. Seeking looked broken backwards until the test source was replaced: av://lavfi reports a bogus four second duration and refuses backward seeks, while real media seeks correctly in both directions. And a radio stream does not report an absent position, it reports a wrong one - SomaFM says 6 seconds of 23 - so rather than trusting metadata, a seek now verifies afterwards that the player actually moved and says so when it did not.

The bar needed no change, which is the useful finding for daily use: waybar mpris already carries left play/pause, middle previous, right next, confirmed in its man page and already documented in the manual. Universal next and previous were there all along. An on-click override was written and reverted, since it would have replaced play/pause rather than added anything, and a comment now records why.

Verified with 24 assertions on the pure functions and 14 against a real seekable player with rofi stubbed, so nothing appeared on screen. checks/session.sh 92/0, checks/manual.sh 8/0, sway-commands clean.

One acceptance criterion is deliberately half met: the menu is in the launcher but not on the bar, because that module has no free mouse button and its three existing clicks are worth more than another route to a menu.
<!-- SECTION:FINAL_SUMMARY:END -->
