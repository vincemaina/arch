---
id: TASK-53
title: 'Make the bar clickable, and put the clock and media where the window title was'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 04:22'
updated_date: '2026-08-21 04:41'
labels:
  - desktop
  - feel
  - dotfiles
dependencies: []
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two changes to the bar, which turn out to be related.

Nothing in the bar does anything when clicked except pulseaudio, which opens pavucontrol. Every other module is a readout you can only look at. Clicking a reading should open the thing that explains it - cpu or memory should open btop, the network module should offer somewhere to change the connection, and so on. A bar that reports without responding trains you to ignore it.

The centre currently shows the focused window's title, which is not worth the space: sway already shows which window is focused by giving it the accent border, and the title is usually a truncated path. The date and time should be there instead - it is the thing most often wanted at a glance, and it is currently squeezed into the right-hand run of readouts. Clicking it should open a calendar.

And when something is playing, the centre should say what. That is the other thing worth a glance, and it has nowhere to appear at the moment.

waybar 0.15 here links libplayerctl, so the mpris module is available rather than needing a custom script. btop, playerctl, pavucontrol and nmtui are all installed and declared already, so this should add no packages.

Worth deciding while doing it: whether a click that opens a window should toggle it - clicking the clock twice ought to close the calendar rather than open a second one - and whether that wants one shared helper rather than a launcher per module.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Every module in the bar does something relevant when clicked, and what each one does is written down rather than only discoverable by clicking
- [x] #2 The focused window's title is gone from the bar
- [x] #3 The date and time occupy the centre, and clicking them shows a calendar
- [x] #4 When a player is playing, what it is playing appears in the bar, and the playback can be controlled from there
- [x] #5 Clicking a module that opens a window twice does not leave two windows open
- [x] #6 Any window opened this way is floating and sized to its contents rather than tiling and shoving the workspace around
- [x] #7 No new packages are needed, and checks/sway-commands.sh still accounts for every command the bar invokes
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verification evidence.

AC1 - checks/session.sh enumerates the modules the bar displays and fails if
any lacks a click action; it reports all 10 responding. What each does is
tabulated at the top of config.jsonc.tmpl.

AC2/AC3 - the window title module is removed; screenshots show the centre
reading "Fri 21 Aug   05:36". Clicking the clock was driven in waybar's own
environment and produced a floating calendar window, screenshotted: three
months with today highlighted.

AC4 - tested against a real MPRIS player rather than assumed. Nothing here
plays media (no mpv, no vlc; ffplay is not an MPRIS client), and a hand-rolled
MPRIS stub was not possible because PyGObject is absent, so dbus-python has no
main loop. A tone played in qutebrowser puts Qt WebEngine on the bus, which
playerctl and the module both saw. Screenshotted playing (note glyph, bright)
and paused (pause glyph, dimmed, no glow).

AC5/AC6 - each click command was run twice in waybar's real environment, taken
from /proc/<pid>/environ rather than reconstructed. All three opened exactly
one floating window on the first click and zero on the second. Worth recording
that an earlier `env -i` harness with a hand-picked subset of variables
produced two false failures - it was not faithful enough to be evidence.

AC7 - checks/sway-commands.sh clean. btop, pavucontrol, playerctl and foot are
declared directly; nmtui comes from networkmanager and cal from util-linux,
both reachable from the manifests, confirmed against the same pactree set the
check builds.

Two bugs found and fixed during the work, both silent:

The first was mine and is now a skill entry. Five of seven scripted edits to
the waybar config did nothing, because the match strings contained pasted Nerd
Font glyphs that had not survived being typed - and str.replace matching
nothing is not an error. It surfaced two steps later in a screenshot. Redone
by matching on key names and editing by line, with the glyph set compared
before and after.

The second was real: ~/.local/bin is not on waybar's PATH, so every click
command naming a helper by bare name was inert. Fixed by templating the config
for absolute paths, which then exposed the calendar helper calling its own
sibling by bare name too.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Every module in the bar now does something relevant when clicked, and the
centre carries the date, the time and whatever is playing instead of the
focused window's title.

cpu and memory open btop, network opens nmtui, the clock opens a three-month
calendar, battery swaps to the time remaining, and pulseaudio gained mute and
a capped volume scroll. Windows opened this way toggle through one shared
helper, so clicking twice closes rather than duplicating.

The media display is waybar's built-in mpris module - this build links
libplayerctl - following whichever player is active and drawing nothing when
none is. Its own click bindings are left alone because the manual already
binds play-pause, previous and next, and its bindings act on the player it is
following.

Verified by driving every click in waybar's real environment taken from
/proc, and the media module against a real MPRIS player rather than an
assumption. checks/session.sh gained three checks covering the two ways this
can fail invisibly - a click command not on waybar's PATH, and an app_id
with no matching floating rule - both confirmed to fail when they should.
57 passed, 0 failed. No new packages.
<!-- SECTION:FINAL_SUMMARY:END -->
