---
id: TASK-101
title: Focus music without opening a browser
status: To Do
assignee: []
created_date: '2026-08-22 01:59'
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
- [ ] #1 Music plays and pauses from the bar and the media keys, verified by pressing them rather than by the tool claiming MPRIS support
- [ ] #2 Starting it takes one keypress or one launcher entry, and it does not leave a window that has to be managed
- [ ] #3 Whatever is chosen comes from the official repositories, or TASK-43 is explicitly reopened rather than quietly worked around
- [ ] #4 The chosen tool follows the theme, or its inability to is stated - it will sit next to tools that all do
- [ ] #5 If a helper holds a list of streams, that list is in the repository so a rebuilt machine has it
<!-- AC:END -->
