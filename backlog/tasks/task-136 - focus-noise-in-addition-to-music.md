---
id: TASK-136
title: focus noise in addition to music
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-23 09:42'
updated_date: '2026-08-23 16:59'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 140000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
right now we music streams for listening to focus music.
what would also be cool is noise alternatives, these would likely be stored on the pc instead of requring a stream. we could have things like brown noise, waves lapping. river sounds. crickets/forest sounds, fire crackling, wind blowing, all the usual ones.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Noise is a target kind in focus-music, not a second player: it plays through the same mpv, so the bar, the media menu, the media keys and the focus timer act on it with no new integration
- [ ] #2 The colour noises and the water/wind ones are generated on the machine from a recipe, never downloaded and never tracked - the same rule wallpapers follow
- [ ] #3 The ones that genuinely need a recording - fire, crickets, forest, thunder - are fetched once into the same cache and played from disk afterwards, so nothing streams on every play
- [ ] #4 Nothing image- or audio-shaped is added to setup/dotfiles, and checks/session.sh still passes its no-binaries rule
- [ ] #5 A noise loops seamlessly rather than ending, and a finished queue is not left showing a track that stopped
- [ ] #6 focus-noise --check reports every entry, what it would do and whether it is cached; focus-music --check keeps working and covers noise entries too
- [ ] #7 Every command used to generate or fetch comes from a declared package
- [ ] #8 checks/session.sh, checks/sway-commands.sh, checks/sway-bindings.sh, checks/packages.sh and checks/manual.sh all pass
- [ ] #9 The manual and DECISIONS.md record why noise is generated rather than shipped, and why some entries are fetched
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a third kind to ~/.local/lib/mpv_queue.py's add: finite, infinite, and now loop, which sets loop-file=inf as a per-file option so a 60-second noise plays for as long as it is wanted without the queue advancing.
2. Write ~/.local/bin/focus-noise, modelled on ~/.local/bin/wallpaper: a table of recipes, a cache under ~/.local/share/focus-noise, and --list/--path/--check/--clear. Synthesised entries are ffmpeg anoisesrc through a filter chain; fetched entries are one yt-dlp search, trimmed and faded, downloaded once.
3. Teach focus-music a noise:<name> target kind that resolves through focus-noise --path, and add a Noise section to the tracked stations file.
4. Declare ffmpeg, which is currently only present as an mpv dependency and would be silently removed with it.
5. Verify: generate every synthesised entry and measure it rather than assume - duration, channels, and that the recipes are actually spectrally distinct from one another.
6. Manual, DECISIONS.md, docs/software, and the five checks.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented and verified. Noise is a third target kind in focus-music (noise:<name>), not a second player, so the bar, media keys, media menu and focus timer act on it unchanged. mpv_queue gained a 'loop' kind setting loop-file=inf. ~/.local/bin/focus-noise holds the recipe table and caches to ~/.local/share/focus-noise. ffmpeg declared - pacman had it as a dependency only, the TASK-13 trap.

Measured rather than assumed:
- All 7 synthesised noises: 60.01s, stereo, 1.1M, -22.0 to -22.9 LUFS.
- Spectrally distinct and monotonic, high-minus-low band RMS: wind -26.8, waves -18.8, brown -11.2, pink -2.7, river +8.3, white +17.3, rain +18.2 dB. That is the evidence the filter chains do what the descriptions claim.
- All 4 fetched noises verified with real downloads: 26-32s each, 11-13M, stereo, exactly 600s, no leftover temp files. Fetched fire measured -22.6 LUFS, inside the synthesised band, so switching between the two kinds does not jump in volume.
- loop-file=inf confirmed applied by a real mpv (--ao=null, own socket, so it made no sound and could not touch what was playing).
- focus-music --check reports all 22 entries ok and does NOT generate or download anything while checking.

Three real bugs found by running it rather than reading it:
1. yt-dlp without -f bestaudio downloads the VIDEO and extracts audio afterwards - ten minutes of downloading produced a partial .webm and no audio.
2. --download-sections makes ffmpeg read sequentially, which YouTube throttles to ~2x real time: 600s of audio took over 5 minutes and had not finished. Downloading whole with yt-dlp's own concurrent-range downloader took 18s for 119 MB. Now fetches whole and trims locally.
3. A fixed duration cap was tuned to the fire results and excluded every crickets result, one of them exactly on the boundary. Replaced by taking the shortest candidate long enough to trim from - no constant, cannot exclude everything, smallest download by construction.

checks/session.sh extended to reject tracked audio as well as images, so the claim that nothing audio-shaped is committed is enforced rather than stated. session.sh 102/0, manual.sh 8/0, sway-bindings clean.
<!-- SECTION:NOTES:END -->
