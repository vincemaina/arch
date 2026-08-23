---
id: TASK-147
title: 'Search YouTube from focus-music, and keep searches instead of links'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 12:32'
updated_date: '2026-08-23 12:47'
labels: []
dependencies: []
ordinal: 153000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
focus-music can only play what is already written in its station list, so getting a specific song or a particular live stream means editing a file and running sync. TASK-145 already put one YouTube URL in the list and proved the shape of the problem: a pinned video id is a link that can rot, and a list of them accrues dead entries nobody notices until the music does not start.

This task adds an ad-hoc search - type anything, see what YouTube has, play the audio - and answers the accrual problem in the design rather than with a cleanup chore. Search results are ephemeral: nothing is written down unless it is deliberately kept. What is kept is the search query, not the video id, so the saved entry resolves fresh every time and cannot 404; that also survives a live channel restarting its broadcast under a new id, which is the exact failure TASK-145 documented. A verify mode covers the handful of literal URLs that do exist, so they can be pruned on purpose rather than discovered dead.

Results must show how long a video is, and say plainly when it is a live stream rather than a recording.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Choosing Search from the focus-music picker prompts for text and lists YouTube results for it
- [x] #2 Each result shows its duration, and a live stream is labelled as live rather than showing a duration
- [x] #3 Choosing a result plays its audio through the same mpv-in-a-scope path as any station, with the bar showing its title
- [x] #4 A search result is not written anywhere unless the user explicitly keeps it
- [x] #5 A kept entry stores the search text, not a video id, and still plays after the underlying video id changes
- [x] #6 Kept entries live in a machine-local file that chezmoi does not manage, so applying dotfiles cannot clobber them
- [x] #7 A verify mode reports which entries no longer resolve, covering direct URLs, pinned video ids and saved searches
- [x] #8 The helper declares every external command it calls, and checks/sway-commands.sh, checks/session.sh and checks/manual.sh pass
- [x] #9 The manual and the software record describe searching, keeping and verifying
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Give the stations format a second kind of target: a line whose URL column reads search:<text> is resolved through yt-dlp at play time rather than fetched directly. This is the whole dead-link answer - a query cannot 404, and it re-finds a live stream that restarted under a new id.
2. Read a second, machine-local station file (stations.local) that chezmoi does not manage, so kept entries survive apply and leave no repository diff. Same one-line format.
3. Add a Search entry to the picker: rofi prompts for text, yt-dlp --flat-playlist runs a ytsearch, and results are listed with a badge that is either a duration or LIVE, plus the channel. Select by index (-format i) so a title containing a tab or a dot cannot break the mapping back to an id.
4. Play a chosen result exactly as a station is played - systemd-run scope, force-media-title - and record what is playing in a state file so the next invocation knows whether keeping is even meaningful.
5. Offer Keep this station only while something found by search is playing, writing label + search:<text> to stations.local. Never write a video id.
6. Add --check: resolve every entry in both files and report the dead ones - direct URLs by HTTP status, video ids and searches through yt-dlp. This is what covers the pinned ids that already exist, so pruning is deliberate.
7. Update the requires header, then run checks/sway-commands.sh, checks/session.sh, checks/manual.sh.
8. Rewrite the manual's focus music section and the software record's yt-dlp paragraph, and record the searches-not-links decision in DECISIONS.md.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Two real bugs were found by exercising the code rather than reading it, and both were the silent kind this repository keeps meeting.

yt-dlp does not expand escape sequences in --print. With the template in ordinary single quotes the literal backslash-t survived, so every field arrived in the first variable: the picker showed a column of --:-- with no titles, no error and no exit code. The template is now $. quoted so the tabs are real, and the comment above it says why.

A ytsearch returns channels as well as videos. The first result for "lofi girl" is the channel, ie_key YoutubeTab, with no duration and nothing to play. The parse now carries ie_key as its first field purely to drop those.

A third, smaller one came out of the test harness: rofi -format i returns a position, and a position is used as an array subscript, which bash evaluates as arithmetic - so anything non-numeric arriving there is read as a variable name rather than rejected. Both call sites now test the value against ^[0-9]+$ and against the array length before using it.

Validation. A harness sources every function above the main dispatch and stubs rofi and playback, so nothing appeared on screen and nothing played: 13 assertions pass, covering fmt_duration at the boundaries (0s, 59s, exactly an hour, 11h41m, NA, empty), a URL passing through resolve_target untouched, a search resolving to a real video URL, read_entries merging the tracked and machine-local files, and do_search end to end - which returned 3 LIVE badges and 11 durations for "lofi girl", correctly badged.

--check was run twice: against the real machine list, where all 12 entries resolve and the kinds are correctly identified as stream and youtube; and against a fake XDG_CONFIG_HOME holding four deliberately broken targets, where it reported HTTP 404, NO ANSWER, GONE and FOUND NOTHING respectively, passed the two good entries, and exited 1.

Nothing-is-written was verified directly rather than argued: after a full search-and-play run, ~/.config/focus-music/ still contains only stations. chezmoi managed lists .config/focus-music/stations and not stations.local, so a kept station cannot be clobbered by apply.

checks/sway-commands.sh accounts for every command including the two new ones (yt-dlp, curl); checks/session.sh 92 passed 0 failed; checks/manual.sh 8 passed 0 failed after adding stations.local to the created_on_demand set - it had correctly failed first, naming a file that does not exist until something is kept. ./sync.sh --dry-run shows both changed files reaching the machine.

Not verified end to end: actual playback through systemd-run, because the machine had music playing and starting a second stream would have interrupted it. The systemd-run and mpv line is unchanged from the working version, and the resolved URL was confirmed decoding under mpv separately.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
focus-music can now search YouTube for anything and play its audio, and what it remembers is a search rather than a link.

The picker opens with "Search YouTube...": type anything, and the results come back with a duration each, or LIVE where the result is a live broadcast rather than a recording. Channels are dropped from the results, since they are not a thing that plays. Choosing one goes through exactly the path a station goes through - the same systemd-run scope, the same forced media title, the same bar widget and playback keys.

The accrual problem is answered in what gets stored rather than by a cleanup chore. Nothing is written down unless you choose "Keep this station", and what that writes is the search text, never the resolved video id - so the entry is re-resolved on every play and cannot rot, and it survives a live channel restarting under a new id, which is the exact failure TASK-145 documented. Kept stations go to ~/.config/focus-music/stations.local, which chezmoi does not manage, so keeping one is not a repository diff and apply cannot clobber it. Station lines in the tracked file may now use the same search:<text> form. For the links that genuinely are links, focus-music --check resolves every entry in both files and names the dead ones, exiting non-zero.

Verified by exercising it, which found two silent bugs: yt-dlp does not expand \t in --print, so the whole result parse had collapsed into one field with no error; and a search returns channels as well as videos. Both are fixed and commented. 13 harness assertions pass with rofi and playback stubbed, so nothing appeared on screen; --check was proven against four deliberately dead targets as well as the real list; ~/.config/focus-music/ was confirmed unchanged after a full search-and-play; sway-commands, session (92/0) and manual (8/0) checks pass.

Documented in the manual chapter 6 (searching, keeping, checking), the software record, the stations file header, and a DECISIONS.md entry recording why a kept station is a query and what that trades away.
<!-- SECTION:FINAL_SUMMARY:END -->
