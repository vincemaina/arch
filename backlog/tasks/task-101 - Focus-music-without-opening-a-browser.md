---
id: TASK-101
title: Focus music without opening a browser
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 01:59'
updated_date: '2026-08-22 02:20'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 103000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Playing background music currently means opening qutebrowser and finding a tab, which is a browser, a window and a set of keystrokes for something that should be one keypress and then invisible.

WHAT PROMPTED IT. cliamp (github.com/bjarneo/cliamp) - a Winamp-style terminal player with a spectrum visualiser, a 10-band EQ, and yt-dlp-backed playback of YouTube, SoundCloud, Bandcamp and Spotify URLs. It answers the request almost exactly.

It is not usable here as things stand, and the reason is the packaging rule rather than the tool: it is not in the official Arch repositories, and its documented install is 'brew install bjarneo/cliamp/cliamp', a Homebrew tap. On Arch that means the AUR or a hand-built Go binary outside the manifests - the same objection that ruled out Mason on TASK-73 and sqls on TASK-84, and the same position as SwayFX and Brave. Revisiting it means revisiting TASK-43, not this ticket.

THE CRITERION THAT MATTERS MOST IS NOT FEATURES. waybar already carries an mpris module in modules-center, wired to play/pause on click, back on middle-click and forward on right-click, and the media keys in 52-media-keys.conf go through playerctl. Anything chosen here should appear there and answer those keys, or it is a music player the desktop cannot see - which is the 'configured and does nothing' shape this repository keeps finding.

CANDIDATES, all in extra and all sized:
  mpv 6.5M + mpv-mpris + yt-dlp 31M   not a music app at all, which is the point:
                                      a URL and a helper holding a few streams.
                                      No TUI, no daemon, no library.
  spotify-player 31M / ncspot 16M     real playlists, native MPRIS, needs Premium.
  cmus 852K                           by far the smallest, but local files - it does
                                      not answer the streaming case.
  mpd + ncmpcpp                       a daemon and a client for a local library;
                                      more machinery than the problem.

Worth deciding what 'focus music' actually means before picking: a handful of known lofi or ambient streams reached instantly, or a real library to browse. The first is a helper over mpv and costs almost nothing; the second is a client for a service and costs a login.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Music plays and pauses from the bar and the media keys, verified by pressing them rather than by the tool claiming MPRIS support
- [x] #2 Starting it takes one keypress or one launcher entry, and it does not leave a window that has to be managed
- [x] #3 Whatever is chosen comes from the official repositories, or TASK-43 is explicitly reopened rather than quietly worked around
- [x] #4 The chosen tool follows the theme, or its inability to is stated - it will sit next to tools that all do
- [x] #5 If a helper holds a list of streams, that list is in the repository so a rebuilt machine has it
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Declare mpv, mpv-mpris and yt-dlp in packages/desktop.txt.
2. Load the mpris plugin from an mpv config, so every mpv is visible to the bar rather than only this helper's.
3. Track the stream list as data, not inside the helper, so adding one is not editing a script.
4. Helper: rofi picker, toggle-off when already playing, started in its own scope so closing the launcher does not take it.
5. Launcher entry. No keybinding - the launcher satisfies the criterion and the binding table is already at 70.
6. Verify what can be verified without the packages, and say plainly what needs the user's sync.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED, and the half that cannot be verified from here is named rather than assumed.

mpv, mpv-mpris and yt-dlp declared in packages/desktop.txt, all three from extra, so TASK-43 stays closed and cliamp stays out on the packaging rule rather than on its merits.

mpv rather than a music application, which is the whole design: it plays a URL and exposes itself over MPRIS, so the bar's media module and the playback keys control it from then on and the helper is not involved again. No library, no daemon, no second window.

THE ONE LINE THAT MATTERS is script=/usr/lib/mpv-mpris/mpris.so in ~/.config/mpv/mpv.conf. Without it mpv plays perfectly and nothing on the desktop can see it - the bar shows nothing and every playback key controls nothing. That is precisely the shape of bug this repository keeps finding, and it is one line away. The path was read out of the package rather than guessed: the plugin ships at a fixed location, not in a directory mpv scans.

Stations are DATA, in ~/.config/focus-music/stations, so adding one is not editing a script. SomaFM direct URLs rather than a YouTube lofi channel, deliberately: they need no yt-dlp, no resolving step that can fail independently of the player, and no video id that changes when a channel restarts. All six were checked returning HTTP 206 and audio/mpeg before being written down. yt-dlp is still declared so a pasted YouTube or SoundCloud link works; it is just not what the defaults depend on.

mpv is started with systemd-run --user --scope, for the reason the workspace greeter learned expensively: a child of whatever spawned it sits in that cgroup, and systemd's default KillMode is control-group. Music that stops when the launcher closes, or when an unrelated unit restarts, is not worth having.

--force-media-title so the bar shows the station name. A radio stream's own metadata is the current track and changes under you - useful inside a player, confusing as the answer to 'what am I listening to'.

VERIFIED HERE: the picker renders all six stations in the launcher's own styling, screenshotted (AC4 - it is rofi, so it follows the theme by construction; mpv itself has no UI to theme). The desktop entry passes desktop-file-validate and its icon exists in the installed Papirus theme. The station list is tracked (AC5). All three packages are from official repositories (AC3). session.sh 89 passed, 0 failed.

NOT VERIFIED, AND CANNOT BE FROM HERE: AC1 and AC2. mpv, mpv-mpris and yt-dlp are declared and not installed - there is no sudo in this session - so nothing has actually played, the bar has never shown it, and no playback key has been pressed at it. checks/packages.sh and checks/sway-commands.sh both report them missing, which is those checks working. After ./sync.sh the test is: open Focus Music from the launcher, pick a station, and confirm the bar's media module names it and the play/pause key stops it.

AC1 and AC2 CONFIRMED BY THE USER after ./sync.sh: the station name displays in the bar's media module and the play/pause keys control it. That is the criterion as written - verified by pressing the keys rather than by the tool claiming MPRIS support - and it was the right criterion to insist on, since the whole design turns on one line loading the mpris plugin.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
mpv, mpv-mpris and yt-dlp with a tracked SomaFM station list and a launcher entry. mpv rather than a music application, so the bar's media module and the playback keys control it and the helper is never involved again - which turns entirely on script=/usr/lib/mpv-mpris/mpris.so, without which mpv plays perfectly and the desktop cannot see it. Stations are data rather than code, chosen as direct URLs so no resolving step can fail independently of the player. Confirmed working by the user: the station name shows in the bar and the play/pause keys stop it.
<!-- SECTION:FINAL_SUMMARY:END -->
