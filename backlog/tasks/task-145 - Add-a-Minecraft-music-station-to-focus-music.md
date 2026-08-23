---
id: TASK-145
title: Add a Minecraft music station to focus-music
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 12:10'
updated_date: '2026-08-23 12:13'
labels: []
dependencies: []
ordinal: 152000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The focus-music station list has no video-game music at all, and no source of the Minecraft soundtrack, which is a common choice for background music while working. No dedicated Minecraft internet radio station exists: radio-browser returns nothing for the tag or the name, and both laut.fm stations called "minecraft" are mislabelled (one plays chart pop, one plays NoCopyrightSounds). So the only source that actually plays this music is YouTube, which makes this the first station whose URL is not a direct audio stream and the first that depends on yt-dlp resolving at start. That trade-off, and the choice of a fixed upload over a live stream, is the substance of this task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The station list contains a Minecraft music entry that plays when selected from the focus-music picker
- [x] #2 The entry follows the existing naming convention: descriptor first, source second
- [x] #3 The chosen URL is a form whose identifier does not change when a channel restarts a broadcast
- [x] #4 The stations file records why this one station is not a direct audio URL, so a later reader does not remove it as a mistake
- [x] #5 docs/manual/06-working.md and docs/software/README.md no longer state that focus-music never resolves a URL, since that is no longer true
- [x] #6 checks/session.sh and checks/manual.sh pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Confirm no direct-URL Minecraft station exists (radio-browser by tag and name, laut.fm, Zeno) and record the evidence.
2. Rule out a YouTube live stream by evidence, not by preference: check whether a channel /live URL is stable in content and whether the broadcasting channel recycles video ids.
3. Pick a long, well-established fixed upload of the soundtrack, whose id is permanent, and verify mpv decodes it with --ao=null so the test makes no sound.
4. Add one entry to setup/dotfiles/dot_config/focus-music/stations under a new heading, with a comment block explaining why this single station resolves and why it is a fixed video rather than a live one.
5. Correct docs/manual/06-working.md and docs/software/README.md, both of which currently assert focus-music never resolves a URL.
6. Run checks/session.sh and checks/manual.sh, then sync.sh --dry-run to confirm the change reaches the machine as expected.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Evidence gathered before choosing a URL, because the obvious answer was wrong twice.

No direct-stream source exists. radio-browser returns nothing for tag "minecraft" or name "minecraft"; searches for videogame/video game/soundtrack tags surface Fallout.fm, VGM Radio, RPGamers, Gamesboro, RadioSEGA and Rainwave, none of them Minecraft. Both laut.fm stations named for the game are mislabelled - laut.fm/station/minecraft-radio/current_song returned a chart pop track, and laut.fm/station/minecraft is a NoCopyrightSounds gaming feed.

Live stream ruled out by evidence rather than by the file s existing preference. The channel behind the obvious 24/7 broadcast recycles ids: its streams tab lists one live minecraft id plus several dead ones under the same title, and its /live URL resolved to an unrelated lofi stream at the time of checking. So neither the video id nor the channel URL is stable, which is precisely the failure the stations file warns about.

Chose a fixed 10-hour upload of the soundtrack (id ZUIT_rQIR5M, ~1.5M views). A published video id does not move; the cost is that it ends after ten hours rather than never, which is recorded in the file.

Validation: the picker parser (grep -P on tab) lists all 12 stations including the new one; the URL lookup grep -P with \Q returns the right URL; mpv played it with --ao=null --vo=null --length=6 and exited 0, so it decoded without making a sound on the machine. checks/session.sh 92 passed 0 failed; checks/manual.sh 8 passed 0 failed; ./sync.sh --dry-run shows the new station and the header block reaching ~/.config/focus-music/stations.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added one station, "Minecraft soundtrack · YouTube", to setup/dotfiles/dot_config/focus-music/stations, and corrected the two documents that said focus-music never resolves a URL.

It is the first station that is not a direct audio stream, because no internet radio station carries this music: radio-browser has nothing under the tag or the name, and both laut.fm stations called "minecraft" play something else entirely. It is a fixed upload rather than a live stream because the channel running the obvious 24/7 broadcast recycles its video id on every restart and its /live URL pointed at an unrelated stream when checked - the exact silent breakage the file was written to avoid. The stations file now carries a THE ONE EXCEPTION block recording all of that, so the entry is not removed later as a mistake.

docs/manual/06-working.md no longer states that the URL has to be a direct stream, and docs/software/README.md no longer claims yt-dlp is off the default path - it now earns its 31.66 MiB through one tracked station as well as pasted links.

Verified: the picker parser lists 12 stations including the new one and the URL lookup resolves it; mpv decoded the source silently (--ao=null, exit 0); checks/session.sh 92/0 and checks/manual.sh 8/0; ./sync.sh --dry-run shows the change reaching the machine.
<!-- SECTION:FINAL_SUMMARY:END -->
