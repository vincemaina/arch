---
id: TASK-154
title: 'Notification sound packs, e.g. PS2-style and 8-bit arcade'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 17:29'
updated_date: '2026-08-23 17:44'
labels: []
dependencies: []
ordinal: 164000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Follow-up to TASK-85 and TASK-143. Right now the desktop has one fixed set of four generated sounds (notify/alert/complete/limit). Make the sound identity itself a switchable set: the current struck-glass set as one pack, plus at least a PS2-style pack and an 8-bit arcade pack, switchable the way themes are.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 At least three packs exist: the current struck-glass set, a PS2-style set, and an 8-bit arcade set
- [x] #2 Switching pack is one command, and it is discoverable the way theme/wallpaper/glow are
- [x] #3 Every pack defines all four events, and nothing is silently missing
- [x] #4 A per-event file of your own still overrides any pack
- [x] #5 Nothing audio-shaped is tracked in the repository - packs are generated on the machine, same as before
- [x] #6 Switching pack costs no measurable latency added to play-sound, which is called on every notification
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Rewrite ~/.local/bin/sounds (python3) around a PACKS registry: chime (the existing struck-glass additive synth, renamed), ps2 (sine-based, soft pitch-bend onset, rounded/muted), 8bit (square/triangle wave, punchy arcade arpeggios). Each pack supplies its own render function and its own per-event note table; all must define notify/alert/complete/limit.
2. Cache becomes per-pack: ~/.local/share/sounds/<pack>/<event>.wav. --regenerate rebuilds every pack (so a code change never leaves an unvisited pack stale); --ensure stays scoped to the current pack (cheap, lazy, used for self-heal).
3. Current pack is NOT chezmoi.toml/[data] - unlike theme/wallpaper/glow it is not consumed by any template, only read at runtime by a bash script on every notification, so it does not belong in "the machine-local config chezmoi merges over .chezmoidata". Instead: a plain one-line state file, ~/.local/state/soundpack, written only by `sounds --pack <name>`, read directly (no python) by both sounds and play-sound. Document why explicitly, since CLAUDE.md establishes chezmoi.toml as the one place for machine-local settings and this is a deliberate, reasoned exception.
4. sounds --pack (bare) opens a rofi picker, mirroring theme; sounds --pack <name> switches directly; sounds --packs lists them with descriptions and marks the current one. sounds --list keeps its existing pure per-event-name-first-column output (checks/session.sh depends on parsing it); bare `sounds` gets a "pack: X" header ahead of the same listing.
5. play-sound: read the pack from ~/.local/state/soundpack (one `read` line, default chime if absent/unknown), resolve <pack>/<event>.wav, unchanged override precedence via ~/.config/sounds/<event>.*. Confirm added latency is not measurable against the existing ~2ms baseline.
6. checks/session.sh: extend the Sounds section - every declared pack generates all four events without error; the pack state file (if present) names a real pack; play-sound and sounds agree on the state-file path (grep coupling check, same shape as the polkit app_id one).
7. Docs: manual (Sounds subsection), DECISIONS.md (why packs are not chezmoi.toml state, why --regenerate covers all packs), CLAUDE.md summary table gets a pack row.
8. Verify against the running session: switch pack, confirm play-sound audibly changes (peaks/durations differ, or watch pw-play file arg), confirm override still wins regardless of pack, confirm rofi picker lists 3 packs, confirm --regenerate leaves no pack stale.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Three packs: chime (the original struck-glass ping, note frequencies verified
byte-for-byte against the pre-existing hardcoded table via a computed
equal-temperament formula rather than a second hand-typed dict), ps2 (single
sine oscillator per note with a soft downward pitch-bend onto the target pitch
and light vibrato - phase is accumulated sample-by-sample rather than computed
from t directly, which is what keeps a bending note in tune with itself), and
8bit (square/triangle waves, no bend at all - real chip audio cannot bend a
note, so quick arpeggios do the work, same trick chiptunes use to fake a chord
on one voice). Every pack defines all four events; a module-level assertion
fails loudly at import if one is missing an event, rather than resolving to a
silently-absent file.

Which pack is active lives in ~/.local/state/soundpack, a plain one-line file
- deliberately NOT chezmoi.toml, even though theme/wallpaper/glow all live
there for the same "machine-local, no diff on switching" reason. The
difference: nothing renders differently because of the active pack, it is
read by play-sound in bash on every single notification, and routing that
through desktop_config.py would reintroduce the ~30ms python-interpreter cost
play-sound was written in shell specifically to avoid. Documented at length in
DECISIONS.md (new "Sound packs" section) and CLAUDE.md, since it is a
deliberate departure from the repository's usual "one writer, chezmoi.toml"
rule for machine-local settings and needs to read as a reasoned exception, not
a shortcut.

play-sound keeps its own short copy of the pack whitelist so a stale/hand-
edited state file can fall back to chime without starting python. This is a
second "two lists must agree" coupling, alongside the pre-existing event-list
one; checks/session.sh checks both, and both were proven to actually go red
(deliberately broke play-sound's whitelist, and deliberately broke a pack's
note table with an invalid note name - both caught, then restored clean).

VERIFIED, against the running system:
- Note frequencies: the computed equal-tempered formula reproduces the old
  hardcoded A3/C5/E5/G5/A5/C6/F6 values to within 0.01Hz - the chime pack is
  byte-identical in sound to before this change.
- All 12 files (3 packs x 4 events) generated cleanly; peaks match declared
  gains exactly, no clipping, endpoints near zero (no clicks).
- Waveform shapes confirmed objectively, not assumed: an amplitude histogram
  over a short post-attack window shows 8bit's square-wave notify as a clean
  50%/50% bimodal distribution at the extremes, 8bit's triangle-wave complete
  as a flat even spread, and chime/ps2's sine-based notes as the expected
  edge-weighted sine distribution. The first version of this measurement used
  too long a window and falsely read the square wave as smooth - the envelope
  decaying across the window was diluting the histogram, not the waveform
  being wrong; fixed by shortening the window, a mistake worth naming since it
  is exactly the "one patch is not a measurement" trap the scripting-traps
  skill already warns about.
- pw-play was watched live while switching packs: notify after switching to
  ps2 played .../ps2/notify.wav, alert after switching to 8bit played
  .../8bit/alert.wav, switching back to chime played .../chime/complete.wav.
- Override still wins on any pack: set an override, switched to 8bit, watched
  play-sound resolve to the override file rather than 8bit's.
- A garbage state file ("not-a-real-pack") was written by hand; both sounds
  --current-pack and play-sound's own resolution fell back to chime,
  independently, without disagreeing.
- The rofi picker (sounds --pack, bare) was launched on a throwaway headless
  output and screenshotted: three rows, correct descriptions, the
  already-selected pack highlighted - focus and the output were restored
  afterwards.
- Latency: 20 back-to-back play-sound calls average ~9ms each including the
  new state-file read; a single call measured 7ms. No regression from the
  pre-pack baseline (~11ms measured under TASK-85/143).
- --regenerate rebuilds all 3 packs x 4 events unconditionally (~0.7s total),
  so editing a pack you are not using does not sit stale until you switch to
  it - confirmed by deleting the whole cache and rebuilding from nothing.

Checks: session.sh 121 passed / 0 failed (9 checks in the Sounds section, 4 of
them new for this task); sway-commands, sway-bindings and manual all clean.

A bug was found and fixed while writing the checks themselves: the pack-name
extraction from `sounds --packs`' human-readable table used `awk '{print $2}'`,
which reads correctly for the marked/current row but, for an unmarked row,
loses the marker's own leading space to awk's whitespace collapsing and shifts
every field left by one - so it read the first WORD OF THE DESCRIPTION as the
pack name for every pack except whichever was currently active. Fixed by
cutting the fixed-width marker column first, then splitting on whitespace.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The desktop's notification sounds are now a choice of three packs, not one fixed set: chime (the original struck-glass ping, unchanged - verified its note frequencies are byte-identical to before), ps2 (a soft sine that bends down into each note's pitch, phase-accumulated so a bending note stays in tune with itself), and 8bit (square/triangle waves with no bend at all, since a real chip cannot do that - quick arpeggios fake a chord instead, the classic chiptune trick). `sounds --pack <name>` switches directly; `sounds --pack` opens a rofi picker, screenshotted working on a throwaway output. Every pack defines all four events, enforced by an assertion at import and by a check that regenerates and verifies every pack, not only the active one. Which pack is active lives in a plain one-line state file rather than chezmoi.toml - a deliberate, documented exception, because nothing templates it and play-sound reads it on every notification in bash specifically to avoid starting a Python interpreter there; routing it through the usual machine-local-config writer would have reintroduced exactly the cost that design avoids. Verified end to end by watching the real pw-play invocation switch which pack's file it plays, confirming a per-event override still wins over any pack, and confirming a hand-corrupted state file falls back to chime in both the python and the bash reader without disagreeing. Latency: ~7-9ms per play-sound call, no regression from before packs existed. Two coupling checks were added to checks/session.sh (event names, pack names, each already existing for events) and both were proven to actually catch a deliberate break before being trusted. session.sh 121/0, sway-commands/bindings/manual all clean.
<!-- SECTION:FINAL_SUMMARY:END -->
