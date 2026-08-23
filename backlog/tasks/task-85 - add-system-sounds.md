---
id: TASK-85
title: add system sounds
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 14:35'
updated_date: '2026-08-23 17:15'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 87000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
I.e. when a notification is recieved
when a limit is reached e.g. trying to turn the volume up past 100%
when a terminal has finished executing some long task e.g. claude response, or long curl command.
system sound level should be controllable through the main system sound volume, unless there's a better way or you think it should be controlled separately.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A notification arriving makes a sound
- [x] #2 Pressing volume-up when already at 100% makes a sound rather than doing nothing silently; likewise volume-down at zero
- [x] #3 A long command finishing in a terminal you are not looking at makes a sound
- [x] #4 System sound level follows the main system volume, and each event has its own fixed level relative to it
- [x] #5 There is one command that plays a sound, one place that defines the set, and a way to substitute a file of your own
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. ~/.local/bin/sounds - a python3 stdlib generator, mirroring ~/.local/bin/wallpaper. One table of recipes (frequency, envelope, level) produces WAVs into ~/.local/share/sounds/. Nothing binary tracked. Subcommands: --ensure, --regenerate, --list, --preview, and `sounds set <event> <path>` to substitute a file of your own.
2. ~/.local/bin/play-sound <event> - the only thing that makes a noise. Resolves the event to a file, generates it on demand if missing, plays it detached through pw-play (pipewire, already declared) at the event's own level, and returns immediately. Silent while mako is in dnd mode, so Do Not Disturb means it.
3. Four events: notify (subtle), alert (prominent, for a dialog waiting on you), complete (a long task finished), limit (a control that has hit its ceiling).
4. Notifications: mako on-notify=exec, which mako supports. Urgency drives it - low is silent, normal is notify, critical is alert. mako runs as a user service so the path must be absolute; config.tmpl is already a template.
5. Dialogs: for_window [app_id="polkit-gnome-authentication-agent-1"] exec ~/.local/bin/play-sound alert. Verified at runtime that for_window accepts exec and that this is the polkit agent's app_id.
6. Volume ceiling: ~/.local/bin/volume replaces the raw wpctl calls on XF86AudioRaise/LowerVolume. It reads the level first, and plays limit instead of changing anything when the step would be a no-op.
7. Long task finished: preexec/precmd hooks in .zshrc ring the terminal bell when a non-interactive command took longer than a threshold. foot already turns a bell into a desktop notification when unfocused, so this needs no new plumbing - a mako [app-name=foot] criterion gives it the complete sound.
8. Documentation: manual chapter, DECISIONS.md entry, checks/session.sh coverage.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Shares an implementation with TASK-143, which asks for the same notification sound plus a distinct dialog sound. Built together in one branch; both tickets are closed by the same work.

Implemented with TASK-143; one mechanism serves both.

Four sounds, generated on the machine by ~/.local/bin/sounds (python3, standard
library only, ~350 lines) from a table of frequencies and envelopes, cached in
~/.local/share/sounds/. Nothing audio-shaped is tracked, matching the wallpaper
decision; checks/session.sh fails if anything ever is.

~/.local/bin/play-sound is the only thing that makes a noise. Shell rather than
python: it runs on every notification, and python3 startup measured 30ms here
against about 2 for this. It rate-limits to one sound per event per 250ms so a
burst does not sound like a fault, and exits silently while mako is in dnd.

VERIFIED, against the running system rather than the files:
- Notification routing, by watching the actual pw-play invocation (the sink
  monitor was unusable - focus-music was playing): ordinary -> notify, critical
  -> alert, low -> silence, app-name=foot -> complete. 4/4.
- Do not disturb: notification, critical and a direct play-sound call all
  silent while dnd is on. 3/3.
- Volume ceiling: at 100% -> limit and the level stays 1.00; at 0 on the way
  down -> limit; at 140% -> limit AND walked back to 1.00 (the -l 1.0 call
  still runs, which is what corrects an over-loud machine); mid-range steps
  silent, 3/3 on a retry after a stray notification from another session
  landed in the first window. Sink muted throughout so nothing loud reached
  the headphones; volume and brightness restored afterwards.
- Brightness ceiling: at 100% -> limit, no change; a step down silent.
- Long task: the installed .zshrc emits exactly one BEL after a long command
  and none after a short one or an ignored program, driven with a real
  interactive zsh (4/4). Then end to end: a real BEL in an UNFOCUSED foot
  window produced a mako notification with App name: foot and played
  complete.wav.
- Sounds reach the actual output device: recorded the bluetooth sink's monitor
  while playing alert - silence, two onsets, peak 23592 matching the file's own
  peak exactly, clean decay, no clipping.
- System volume governs them: pw-play appears as an ordinary sink-input on the
  default sink with media.role=event and its own stream volume at 100% / 0.00
  dB, so no per-stream attenuation - the sink's volume is the only one.
- Relative levels are by construction and measured: peaks 0.30 notify, 0.42
  limit, 0.50 complete, 0.72 alert, endpoints at zero so no clicks.
- sounds set <event> <file> / --default round-trips, and play-sound was
  observed picking the overriding file from ~/.config/sounds.

FOUND AND FIXED ALONG THE WAY, both real and both pre-existing in kind:
- checks/sway-commands.sh resolved a dependency closure with pactree but never
  stripped the version constraints pactree prints, so a package reached only as
  `name=1:2.3-4` never matched its own name. pw-play surfaced it. Fixed.
- The same check reads the sway config as text and collected the word after
  `exec` from COMMENTS too, so a sentence explaining that "sway accepts exec in
  a command list" produced a demand for a program called `in`. Full-line
  comments are now dropped.
- A zsh trap worth knowing: ${${(z)1}[1]} returns the first CHARACTER when the
  line is a single word, because a one-element inner expansion collapses to a
  scalar. `claude` became `c`, so every ignore-list entry run with no arguments
  quietly rang the bell anyway. Multi-word test cases all passed and proved
  nothing. Recorded in the scripting-traps skill.

Checks: session.sh 116 passed / 0 failed (11 of them new), sway-commands clean,
sway-bindings clean, manual 8/0.

OUTSTANDING, needs a password this session does not have:
  sudo pacman -D --asexplicit pipewire-audio
pipewire-audio is newly declared in desktop.txt because pw-play is now
load-bearing and pacman had it marked as a dependency of pipewire-pulse - the
exact state that lets a graph change remove it silently. ./sync.sh does this
automatically on both install paths; checks/packages.sh reports it until then.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The desktop now makes four sounds - notify, alert, complete and limit - generated on the machine from a table of frequencies and envelopes rather than shipped, so nothing audio-shaped is tracked. A notification pings, a critical one alerts, a low-urgency one is silent; the volume and brightness keys play a low blunt note when a press would change nothing instead of failing silently; and a command over twenty seconds rings the terminal bell, which foot turns into a notification only when you are not looking at the window. One player (~/.local/bin/play-sound), one definition (~/.local/bin/sounds), and `sounds set <event> <file>` to substitute your own. The system volume is the only volume: pw-play was confirmed to run as an ordinary sink-input at 100% with no per-stream attenuation. Verified against the running session by watching the real pw-play invocations (11/11 routing cases) and by recording the sink monitor to prove the audio reaches the device. Fixed two real bugs in checks/sway-commands.sh found on the way - unstripped pactree version constraints, and commands harvested out of config comments - and recorded a zsh scalar-subscript trap in the scripting-traps skill. session.sh 116/0, sway-commands, sway-bindings and manual all clean. One follow-up needs a password: sudo pacman -D --asexplicit pipewire-audio, which ./sync.sh does on its own.
<!-- SECTION:FINAL_SUMMARY:END -->
