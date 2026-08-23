---
id: TASK-149
title: 'Queue in focus-music: play now, play next, add to queue, and manage the queue'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 13:05'
updated_date: '2026-08-23 13:24'
labels: []
dependencies: []
ordinal: 156000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
focus-music plays exactly one thing. Every start kills whatever was playing, so there is no way to line up a few tracks, and choosing something while music is on is always destructive. Now that anything on YouTube is one search away, that limit is the thing standing between the helper and normal use.

Adding a queue changes the model: mpv stops being a process that gets killed and restarted per station, and becomes one long-lived instance with a playlist, driven over its JSON IPC socket. That brings a second benefit worth naming, because it fixes a real bug rather than adding a feature: the helper currently stops music with `pkill -x mpv`, which kills every mpv the user has running, including one playing an unrelated video. Talking to our own socket makes the target unambiguous.

The choice of what a selection does - play it now, play it next, or put it at the end - should only be asked when something is already playing. With nothing on, the only sensible answer is play it, and a menu asking would be noise.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Choosing a station or a search result while something is playing asks whether to play now, play next, or add to the end
- [x] #2 Choosing one while nothing is playing just plays it, with no extra prompt
- [x] #3 Play now keeps the rest of the queue rather than discarding it
- [x] #4 A queue view lists what is lined up, marks what is playing, and can play, reorder, remove, and clear entries
- [x] #5 Queued entries show their real titles, not their URLs
- [x] #6 The queue advances on its own when a track ends
- [x] #7 Stopping affects only the music this helper started, never an unrelated mpv the user is running
- [x] #8 A saved search: station can be queued like anything else
- [x] #9 checks/sway-commands.sh, checks/session.sh and checks/manual.sh pass, and the manual and software record describe the queue
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify the mechanics before designing around them: mpv's loadfile modes (append, insert-next, insert-next-play), playlist-move/remove/clear, per-file titles, and above all whether keep-open=yes - which mpv.conf sets - stops a queue advancing at the end of a track.
2. Add ~/.local/lib/mpv_queue.py as the only thing that speaks mpv's JSON IPC, following the desktop_config.py precedent of one owner per external state. Subcommands for running, add, list, count, current, play, move, remove, clear, next, quit.
3. mpv only knows a title for the entry it is playing; pending entries report their URL. So the helper keeps a url-to-title map beside the socket, used purely for display - mpv's playlist stays the source of truth for order and membership, and the map is pruned against it on every read, so it cannot drift into lying.
4. Start mpv once, idle, with --input-ipc-server, and load everything through IPC so the first track and the tenth take the same path.
5. Ask now/next/queue only when something is already playing.
6. Add a queue view: entries with the current one marked, and per-entry play, move up, move down, remove, plus clear.
7. Stop talks to our socket instead of pkill -x mpv, which today kills every mpv the user has. Keep a narrow legacy path so an mpv started before this change can still be stopped once.
8. Test against a throwaway mpv on its own socket with --ao=null, so nothing is heard and the running session is untouched.
9. Update the manual, the software record and the stations documentation; run every check.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Three behaviours were established by testing rather than by reading, and two of them contradicted what the source looked like it did.

mpv loadfile flags: the -play suffix means "start playback if nothing is playing", not "switch to this now". insert-next-play therefore put the track in the right place and, with music already on, left it sitting there - "Play now" would have silently behaved like "Play next" while reading correctly in the source. Playing now is insert-next followed by an explicit playlist-next force.

keep-open=yes, which mpv.conf sets so a dropped stream does not end the music, does NOT stop a queue advancing between tracks - that was the risk worth checking first, and three sampled runs show one track handing over to the next unaided. It does bite at the end of the queue: the last track finishes and mpv sits on it paused at EOF with media-title still set, so the bar would go on advertising music that stopped. mpv.conf is the users global mpv config and governs watching films too, so rather than change it, finite tracks are queued with keep-open=no as a per-file option. Measured both ways: with the flag, mpv goes idle-active and reports nothing playing; without it, the ghost persists.

mpv only knows a title for the entry it is playing - everything queued behind comes back as a bare URL. Hence the url-to-title map, which is a lookup only and is pruned against the playlist on every read, so it can be incomplete but cannot make the queue misreport its own contents.

A third bug was caught before it shipped: the legacy-cleanup matcher used pgrep -x with -f, which demands the entire command line match exactly, so it would never have fired and the first play after an update would have left two streams running.

Validation. 21 assertions against mpv_queue.py driving a throwaway silent mpv (append order, insert-next placement, play-now switching while keeping the queue, move, remove, play-by-index, clear keeping the current entry, title map pruning, and a title containing a comma surviving mpvs option parser via the %n% length prefix). 26 assertions driving the real bash functions with rofi stubbed - resolve_target reporting finite for a recording and not for radio, the no-question path when nothing is playing, all three modes, ask_mode, pick_something index mapping, the queue view marking the current row 0100, queue_menu removing an entry and clearing while keeping what plays, and stop leaving no mpv. Then one real end-to-end: a saved search: station resolved through yt-dlp and played actual audio (time-pos 3.036, so moving rather than merely loaded) with a second station queued behind it.

checks/sway-commands.sh accounts for every command including the new python3 and pgrep; checks/manual.sh 8 passed 0 failed; checks/session.sh 91 passed 0 failed 1 skipped - the skip is the screenshot check declining to run while the screen is locked, which is environmental and unrelated. ./sync.sh --dry-run shows both .local/bin/focus-music and the new .local/lib/mpv_queue.py reaching the machine.

Not exercised: the rofi menus as pixels. Every menu was driven through its real function with rofi stubbed, so the wiring is covered, but nobody has looked at them on screen - the machine was locked and playing music throughout.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
focus-music gained a queue, and mpv stopped being a process that gets killed and restarted.

Choosing a station or a search result while music is on now asks where it goes: Play now, Play next, or Add to queue. Play now keeps everything already queued behind it rather than discarding the queue. With nothing playing there is no question at all - it simply plays. Queue (n) opens the queue itself, marking what is playing, with play-this-now, move up, move down, remove per entry, and a clear that keeps the current track so tidying up does not stop the music. Skip to next is in the same menu.

The queue is mpvs own playlist. mpv is started once, idle, on a JSON IPC socket, and everything afterwards is a message to it through ~/.local/lib/mpv_queue.py, the only thing that speaks it. Nothing here keeps a second copy of the running order, so nothing can drift out of step with what is actually playing. Titles are the one exception and are kept in a map that is pruned against the playlist on every read - it can be incomplete, never wrong about order or membership.

That also fixed a real bug rather than only adding a feature: stopping was pkill -x mpv, which killed every mpv the user had running, including one playing a film. Only the instance holding this socket is touched now.

Verified against throwaway silent mpv instances: 21 assertions on the IPC helper, 26 driving the real menu functions with rofi stubbed, and one genuine end-to-end where a saved search: station resolved through yt-dlp and played real audio with a second queued behind it. Testing overturned two things the source looked like it did - mpvs insert-next-play does not switch to the track when music is already playing, so Play now would have behaved like Play next; and keep-open=yes leaves the last track of a queue paused at EOF forever, so finite tracks are now queued with keep-open=no per file rather than changing the global config that also governs films.

Documented in manual chapter 6 (a new queue section and the corrected menu description), the software record, and a DECISIONS.md entry covering the socket, the title map, the keep-open trade-off and the insert-next-play trap.
<!-- SECTION:FINAL_SUMMARY:END -->
