---
id: TASK-143
title: make a noise whenever a dialog pops up
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 11:13'
updated_date: '2026-08-23 17:15'
labels: []
dependencies: []
priority: medium
type: enhancement
ordinal: 147000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
in fact for both notifications, as well as popup dialogs that require my input e.g. password, or confirmation, id like to hear a sound. probably two different sounds. the notification one should probably be more subtle, and the dialog one a bit more prominent, as it means some process is waiting for me to do something before it can continue
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A notification arriving plays a short, quiet sound
- [x] #2 A dialog that is waiting for input - the polkit password prompt - plays a distinctly more prominent sound than a notification
- [ ] #3 The two sounds are audibly different from each other and recognisable as belonging to one family
- [x] #4 Do Not Disturb silences the sounds as well as the popups
- [x] #5 Nothing binary is tracked in the repository: the sounds are generated on the machine, like the wallpapers
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
Implemented together with TASK-85 - the notification sound is the same sound,
and splitting the work would have meant two mechanisms.

The two sounds asked for:
  notify  one high note, quiet   (peak 0.30, 0.34s)  a notification arrived
  alert   two notes rising C6->F6, bright and loud
                                 (peak 0.72, 0.52s)  something is WAITING

Both are built from one timbre table, so the difference between them is
deliberately count, register and level rather than a different instrument.

Notifications go through mako's on-notify=exec, chosen by urgency: low silent,
normal notify, critical alert. The password prompt goes through
  for_window [app_id="polkit-gnome-authentication-agent-1"] exec ... alert
which needed no daemon - it was verified at runtime that sway accepts exec in a
for_window command list and fires it on the window appearing, and the app_id was
read off a live dialog with swaymsg -t get_tree rather than guessed.

Ordinary dialogs deliberately stay silent: a file chooser or save prompt is
opened BY you a fraction of a second earlier, and announcing a window you are
already looking at is noise. Only the prompt that means a process has stopped
and will wait forever gets a sound.

WHAT MAKO CANNOT DO, measured rather than assumed: honour the freedesktop
sound-name hint. foot already SENDS it - its default notification command passes
--hint STRING:sound-name and --hint BOOLEAN:suppress-sound - but makoctl list -j
returns only id, app_name, app_icon, category, desktop_entry, summary, body,
urgency and actions, and hints are not criteria fields either. Reading them
would need a second daemon eavesdropping on the session bus to choose between
four sounds. Urgency and app-name do the job; this is written down in the mako
config and in DECISIONS.md so it is not rediscovered.

Do not disturb silences everything, and the check lives in play-sound rather
than in mako's [mode=dnd] block on purpose: two of the three callers never touch
mako, and a rule in two files drifts.

VERIFIED by watching the real pw-play invocation on the running session:
ordinary -> notify, critical -> alert, low -> silence, polkit dialog -> alert
(triggered on a throwaway headless output so the user's screen was never
touched, with focus and the output restored afterwards). dnd silenced all three
paths. Audio was confirmed to reach the real output device by recording the
sink monitor.

AC 3 is left UNCHECKED on purpose. That the two sounds are measurably different
and share a timbre is proven; whether they are pleasant and read as one family
is a judgement no script has, and it needs a listen: `sounds --preview`. If they
are wrong, `sounds set <event> <file>` takes a file of your own, or the SOUNDS
table in ~/.local/bin/sounds is the one place the generated ones are defined.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Notifications and the password prompt now make different sounds: notify is one high quiet note, alert is two rising notes at more than twice the peak level, and they are built from one timbre table so the difference is count, register and loudness rather than a different instrument. Notifications are routed by mako's on-notify=exec on urgency (low silent, normal notify, critical alert); the polkit dialog is routed by a for_window ... exec rule, which needed no daemon - that sway fires exec on a window appearing was verified at runtime, and the agent's app_id was read off a live dialog rather than guessed. Ordinary dialogs stay silent deliberately, since you opened those yourself. Do not disturb silences everything, checked in play-sound rather than mako because two of the three callers never touch mako. Established by measurement that mako cannot honour the freedesktop sound-name hint that foot already sends - makoctl exposes no hints and they are not criteria fields - and wrote that down so it is not rediscovered. Verified on the running session: all four routing cases correct, dnd silent on all three paths, the polkit case triggered on a throwaway headless output with focus and the output restored. AC 3 is left unchecked on purpose: that the sounds differ and share a timbre is proven, but whether they are pleasant is a listen, not a check - run `sounds --preview`.
<!-- SECTION:FINAL_SUMMARY:END -->
