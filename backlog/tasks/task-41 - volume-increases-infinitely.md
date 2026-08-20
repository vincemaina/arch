---
id: TASK-41
title: volume increases infinitely
status: Done
assignee:
  - '@claude'
created_date: '2026-08-20 15:26'
updated_date: '2026-08-20 15:36'
labels: []
dependencies: []
priority: high
type: bug
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
when increasing the volume, you can increase it infinitely e.g. to 2000%. I'm not sure if this is just a UI glitch but if it's actually increasing the volumne that much I'm wondering if it could damage hardware. probably worth looking into.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Raising the volume with the media key cannot take the sink above 100%
- [x] #2 The volume keys use one tool consistently rather than mixing interfaces to the same audio stack
- [x] #3 A machine already sitting above 100% is brought back down rather than left there
- [x] #4 The package manifest reflects which command the configuration actually calls
- [x] #5 checks/session.sh catches a sink left above 100%, since the symptom is visible on the running system
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Cause: 52-media-keys.conf calls pactl set-sink-volume @DEFAULT_SINK@ +5%, which has no upper bound. PulseAudio and PipeWire both allow software amplification well beyond 100%, so repeated presses keep multiplying digital gain. Confirmed rather than assumed: pactl reported the sink at 105% and 1.38 dB before any change, so it is real gain and not a display artefact.

2. Not a bar problem. waybar pulseaudio module defaults max-volume to 100, so scrolling on the bar was already bounded. No waybar change needed, and confirming that avoids fixing something that was never broken.

3. Switch the volume bindings to wpctl set-volume -l 1.0, whose --limit clamps the resulting volume. Verified live: at 1.05 a limited 5%+ produced 1.00 and stayed there, so it also repairs a machine already above 100%.

4. Use wpctl for mute and mic mute too. Mixing pactl and wpctl against the same stack is two interfaces to one thing; wpctl is the WirePlumber-native one on a PipeWire system and pactl is the compatibility shim.

5. Drop the explicit libpulse entry, whose comment justified it as "pactl, used directly by the volume keys". That stops being true. It stays installed as a dependency of pipewire-pulse and pavucontrol, so nothing is lost.

6. Add a checks/session.sh assertion that the sink is not above 100%, since that is the symptom as seen on a running machine rather than in a config file.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Real, not a display artefact. Before any change pactl reported the sink at 105% with 1.38 dB of gain. Above 100% is software amplification: it does not make the signal usefully louder, it clips the waveform, and sustained clipping is hard on speakers and worse on hearing. At the 2000% that prompted the report it would be severe. So the concern was justified.

Cause: pactl set-sink-volume has no upper bound, and the binding passed +5% with nothing to stop it.

The bar was never part of it. waybar pulseaudio defaults max-volume to 100, so scrolling there was already clamped. Checked before changing anything, which avoided fixing something that was not broken.

Fixed by moving the volume bindings to wpctl set-volume -l 1.0. --limit clamps the resulting volume rather than the step, so it also walks an already-too-loud machine back down instead of merely refusing to go higher. Mute and mic mute moved to wpctl as well: running pactl and wpctl against one audio stack is two interfaces to the same thing, and wpctl is the WirePlumber-native one on PipeWire while pactl is the compatibility shim.

Verified by exercising the exact command the binding runs: from 0.98, three raises produced 1.00 rather than 1.13, and the unbounded pactl form was run once for contrast and immediately took it to 1.05 again, confirming the old behaviour was the cause rather than something coincidental. The sink was left at 1.00.

Note on the limits of that verification. sway exposes no IPC to enumerate bindings - get_config returns only the top-level file, three lines and one include - so nothing can ask the running compositor what a key is bound to. The evidence is that the config reloaded without error and that checks/sway-bindings.sh shows all four bindings in their new form. That gap is exactly why checks/sway-bindings.sh parses the files rather than asking sway.

libpulse was dropped from the manifest: its comment justified it as "pactl, used directly by the volume keys", which stopped being true. It remains installed as a dependency of pipewire-pulse and pavucontrol. checks/sway-commands.sh passes, confirming wpctl resolves to wireplumber, which is declared.

checks/session.sh gained an Audio section asserting the sink is not above 100%, since that is the symptom as it appears on a running machine. 41 passed, 0 failed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The volume keys could raise the sink without limit - the machine was found at 105% and would go to 2000% - because pactl set-sink-volume has no ceiling. Above 100% is digital amplification, which clips rather than usefully increasing loudness, so the report was right to treat it as more than cosmetic. The bindings now use wpctl set-volume -l 1.0, whose --limit clamps the result and therefore also brings an already-too-loud machine back down; mute and mic mute moved to wpctl too, so one tool drives the audio stack instead of two. waybar was checked and needed nothing, its max-volume already defaulting to 100. Verified by running the binding command from 0.98 and getting 1.00 after three raises rather than 1.13, with the old unbounded form reproduced once for contrast. libpulse left the manifest along with the justification for it, and checks/session.sh now fails if the sink is left above 100%.
<!-- SECTION:FINAL_SUMMARY:END -->
