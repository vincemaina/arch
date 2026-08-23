---
id: TASK-150
title: A finished queue looks like focus-music crashed
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 13:55'
updated_date: '2026-08-23 14:05'
labels: []
dependencies: []
ordinal: 157000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Reported as "the process just crashed". It had not: mpv was alive on its socket with a seven track queue still listed, all of it played out, nothing marked current. What the user saw was the music stop, the bar clear, and focus-music reopen showing the plain station picker as though the queue had never existed - because the menu that knows about a queue is only reached when something is playing.

Two things are wrong. The finished queue is invisible and unreachable: there is no way to see it, replay it, or clear it, and the only route back is to start something new. And starting something new appends to those dead entries rather than replacing them, so every finished track stays in the playlist and the list grows for as long as mpv lives.

mpv going idle at the end of a finite queue is correct and deliberate - it is what stops the bar advertising music that stopped, decided in TASK-149. What is missing is that focus-music has nothing to say about that state.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 With a finished queue, focus-music says so rather than showing a bare station picker
- [x] #2 From that state the queue can be played again, viewed, or stopped
- [x] #3 Starting something new after a queue has finished replaces the dead entries rather than appending to them
- [x] #4 Playing something when mpv is not running at all still starts it, as before
- [x] #5 Skipping past the last track no longer stops playback outright
- [x] #6 checks/session.sh, checks/manual.sh and checks/sway-commands.sh pass, and the manual describes the finished state
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Establish the mechanics before changing behaviour: confirmed on the live machine that mpv was running, idle, with seven finished entries and nothing current, and confirmed by probe that playlist-clear empties the list outright when nothing is current while keeping only the current entry when something plays. One command therefore covers both resets.
2. Give focus-music a third top-level state. It currently branches on playing or not; add running-but-idle-with-entries, which is a finished queue, and say so in the prompt.
3. From that state offer: play the queue again (playlist-play-index 0), open the queue view, play something else, or stop.
4. Clear a finished playlist before starting anything new, so dead entries cannot accumulate across a session.
5. Change playlist-next from force to weak: the probe shows force stops playback outright when it runs off the end of the queue, which is not what skipping a track should ever do.
6. Test each state against a throwaway silent mpv - finished queue, replay, reset on new selection, and mpv absent entirely.
7. Update the manual's queue section to describe what happens when the music runs out.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Not a crash. On the live machine mpv was running on its socket, idle, holding seven finished YouTube entries with nothing marked current - so focus-music, which only reached its queue-aware menu when something was playing, fell through to the bare station picker as though nothing had ever been queued.

Three distinct causes, found by reproducing the state rather than reading the code.

First, there was no branch for the state at all: running, not playing, playlist non-empty. That is a finished queue and it now has its own menu.

Second, and this is the one that will have looked most like a crash: pause is a property of the player, not of the file, and it survives. A queue that ends on a kept-open track leaves mpv paused on its last frame. Load the next thing on top of that and it arrives paused too - probe shows time-pos frozen at 0.023 across four seconds while the title changes and the bar lights up, so it looks like it is playing and makes no sound. Anything meant to start playback now clears pause explicitly. This applies to both starting a new track and replaying the queue.

Third, "playing" was defined as "not idle", which counted a track parked at its own EOF as playing. A queue can run out in two shapes - a finite track goes idle, a kept-open one sits paused at eof-reached - and both mean the music stopped.

Also changed playlist-next from force to weak on the evidence of a boundary probe: force succeeds on the last track by stopping playback entirely and going idle, so skipping past the end silenced the music instead of doing nothing. weak errors harmlessly and stays put. playlist-prev weak behaves the same way at the front.

Starting something new while not playing now resets the playlist outright. playlist-clear was not sufficient: it keeps whatever is current, which is right mid-listen and wrong when replacing a finished queue, where the leftover would survive into the next one. The new reset removes from the front until the list is empty, bounded by the count.

Validation: 16 assertions covering a queue playing out, replaying it, letting it finish again, starting something new over the dead entries, skipping off the end, previous, and mpv absent entirely - all against throwaway silent mpv instances. The earlier suites still pass unchanged: 21 on the IPC helper, 26 on the menu flow. checks/session.sh 92/0, checks/manual.sh 8/0, checks/sway-commands.sh clean.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
What was reported as a crash was a finished queue with nothing to say for itself, plus a track that loaded silent.

mpv was alive and idle, still holding seven played-out entries, and focus-music only reached its queue-aware menu when something was playing - so it fell through to the plain station picker, which is indistinguishable from having lost everything. There is now a third state: it reports how many tracks finished and offers to play the queue again, open the queue, start something else, or stop. Starting something else resets the playlist rather than stacking onto the dead entries.

The silent part was worse and better hidden. pause belongs to the player rather than the file and survives across loads, so a queue ending on a kept-open track left mpv paused on its last frame - and the next thing played arrived paused, showing its title in the bar with time-pos frozen and no sound. Starting playback now clears pause explicitly. Relatedly, "playing" no longer counts a track parked at its own EOF as playing, since a queue can run out in two different shapes.

Skipping past the last track also used to stop the music outright, because playlist-next force succeeds by going idle; it is weak now, so it does nothing at the boundary.

Verified with 16 new assertions across every state - finished, replayed, finished again, replaced, skipped past the end, previous, and mpv absent - against throwaway silent mpv instances, with the existing 21 and 26 assertion suites still passing. checks/session.sh 92/0, checks/manual.sh 8/0, sway-commands clean. The manual now describes what happens when the music runs out.
<!-- SECTION:FINAL_SUMMARY:END -->
