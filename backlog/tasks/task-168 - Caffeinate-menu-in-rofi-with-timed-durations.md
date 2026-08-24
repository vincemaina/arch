---
id: TASK-168
title: Caffeinate menu in rofi with timed durations
status: Done
assignee:
  - '@vincemaina'
created_date: '2026-08-24 14:19'
updated_date: '2026-08-24 18:34'
labels: []
dependencies: []
ordinal: 175000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Right now the only way to caffeinate (keep the screen from locking/sleeping) is waybar's built-in idle_inhibitor module, which is a plain on/off toggle with no way to set a duration and no way to control it except clicking the bar module. Replace it with a custom caffeinate control: a rofi menu (reachable without touching waybar) offering off, on indefinitely, and a few fixed durations (e.g. 1h/2h/4h/8h), and a bar module that shows the current state including remaining time when timed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A rofi menu lists: turn off, turn on indefinitely, and several fixed durations; choosing one takes effect immediately
- [x] #2 The menu's prompt or rows show the current state: off, caffeinated indefinitely, or caffeinated with time remaining
- [x] #3 The menu is reachable from rofi (e.g. a script under dot_local/bin, launchable like bluetooth/power-profile) without needing to click the bar
- [x] #4 A timed session automatically reverts to normal idle behaviour (locking/sleeping) when its duration elapses, with no leftover process or timer once it has
- [x] #5 The waybar module reflects state at a glance: distinguishable icon/colour for off vs indefinitely-on vs timed, and remaining time visible for a timed session (text or tooltip)
- [x] #6 Clicking the bar module opens the same rofi menu rather than blindly toggling
- [x] #7 checks/session.sh and checks/sway-commands.sh pass
- [x] #8 docs/manual/ is updated if it documents the old idle_inhibitor bar module or caffeinate behaviour
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add setup/dotfiles/dot_local/bin/executable_caffeinate. Mechanism: caffeinated == swayidle.service stopped, normal == running (swayidle already owns all locking/idle behaviour, so stopping it is the whole effect - no Wayland idle-inhibit protocol client needed). A small state file at $XDG_RUNTIME_DIR/caffeinate/state (mirrors focus-timer's state file) holds MODE=indefinite|timed and, for timed, UNTIL=<epoch seconds>. Auto-expiry is a transient systemd --user timer (systemd-run --user --unit=caffeinate-timer --on-active=<secs> -- <script> off), so it fires even if waybar is not running; state() always treats swayidle.service's real ActiveState as ground truth (verify against the running system, not the file) and falls back to indefinite if the state file is stale/missing while swayidle is stopped. Subcommands: (none)=menu, on=indefinite, off, 1h/2h/4h/8h=timed, status=human sentence, --bar=JSON {text,tooltip,class} for waybar, -h/--help. requires: header lists systemctl, systemd-run, rofi, date.
2. Menu (rofi -dmenu -no-custom -replace, prompt carries live state like power-profile/bluetooth do): rows are 'Turn off' (only when caffeinated), 'Caffeinate indefinitely', 'Caffeinate for 1 hour/2 hours/4 hours/8 hours'.
3. waybar: replace the native idle_inhibitor module with custom/caffeine in config.jsonc.tmpl (modules-right list, the module block: exec caffeinate --bar, return-type json, interval ~30, on-click caffeinate, both via {{ .chezmoi.homeDir }}), and update the header comment table and the idle_inhibitor prose comment block.
4. style.css.tmpl: rename every #idle_inhibitor selector to #custom-caffeine (custom/name -> #custom-name per the arch-logo comment's rule already documented there), keep resting muted / active warning colour, add a timed class if the text differs enough that no extra class is needed - reuse .on/.timed both warning, off has no class (muted default).
5. docs/manual/02-the-desktop.md: update the Caffeine table row (Shows/Click) to describe the rofi menu and time-remaining display instead of the old toggle-only idle_inhibitor.
6. Run checks/session.sh, checks/sway-commands.sh, checks/sway-bindings.sh; render the waybar template with chezmoi to a scratch destination to check the JSON/CSS actually renders; use the desktop-verification skill to screenshot the bar in off/indefinite/timed states and trial the rofi menu live before finalizing.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation: ~/.local/bin/caffeinate (new script). Mechanism: caffeinated == swayidle.service stopped; auto-expiry via a transient 'systemd-run --user --unit=caffeinate-timer --on-active=<dur>' timer, so it fires even if waybar is closed. A small $XDG_RUNTIME_DIR/caffeinate/state file (MODE/UNTIL, same idiom as focus-timer's ENDS field) supplies remaining-time detail; swayidle.service's real ActiveState is always the ground truth for on/off. waybar's native idle_inhibitor module replaced with custom/caffeine (config.jsonc.tmpl + style.css.tmpl, #idle_inhibitor -> #custom-caffeine). docs/manual/02-the-desktop.md bar table row updated.

Bug caught and fixed during live verification: cancel_timer() originally stopped both caffeinate-timer.timer AND .service - when a timed session's own timer fires, 'caffeinate off' runs AS caffeinate-timer.service, so stopping that unit from inside itself killed the process before it reached 'systemctl start swayidle.service', leaving the screen stuck caffeinated through a whole real timed session. Fixed to stop only the .timer (a oneshot .service exits on its own and never needs stopping). Confirmed with a live 6s --on-active timer: swayidle.service correctly returned to active with no leftover caffeinate-timer units.

Verified live on the actual session (not just read back): on/off/2h/status/--bar all exercised directly against the real swayidle.service, restored to normal (active, no state file, no timer) afterward. Rofi menu and both bar states (off muted, timed warning+'1h 59m') screenshotted via a throwaway waybar+headless-output instance per the desktop-verification skill, then torn down (focus restored to Virtual-1, HEADLESS output unplugged, no processes left behind). chezmoi render to a scratch destination (--exclude=scripts) succeeded for all themes both before and after a follow-up comment edit. checks/session.sh (125 passed/0 failed), checks/sway-commands.sh, checks/sway-bindings.sh and checks/manual.sh all pass.

Separate finding, not fixed here: U+F0F4 (used for the icon, carried over unchanged from the old idle_inhibitor module) renders as a desktop/monitor glyph on the JetBrainsMono Nerd Font actually installed on this machine, not a coffee cup - confirmed by isolating the codepoint with pango-view. This predates TASK-168 (the old module used the identical codepoint) and is out of this task's scope; left both the script and a comment flagging it for whoever picks the icon mismatch up.

Follow-up fix, same session: the user reported caffeinate wasn't reachable from the launcher after merge. AC #3 said 'reachable from rofi ... like bluetooth/power-profile' but I only made it a standalone script (like power-profile, which has no launcher entry) rather than adding a .desktop entry (like bluetooth, which does) - power-profile was the wrong model to have actually verified against, since it IS bar-only by design. Added setup/dotfiles/dot_local/share/applications/caffeinate.desktop.tmpl (same pattern as bluetooth.desktop.tmpl: absolute Exec via chezmoi homeDir). Applied live with 'chezmoi apply' and confirmed 'Caffeinate' now appears via rofi -show drun -filter caffeinate on a throwaway headless output, with the preferences-desktop-screensaver icon rendering. docs/manual/02-the-desktop.md notes the launcher entry alongside the bar table.

Also found and fixed a real gap in checks/session.sh while re-running it: the session-units check unconditionally fails when swayidle.service is stopped, with no awareness that caffeinate stops it on purpose - it flagged FAIL against the user's own real 4-hour caffeinate session they'd just started to try the feature. Fixed the swayidle case to ask '~/.local/bin/caffeinate status' (mirroring what the bar module already asks) before failing, captured into a variable rather than piped through 'grep -q' per the scripting-traps skill. checks/session.sh: 126 passed, 0 failed with that real caffeinate session still running - left it running rather than turning it off, since it is the user's own deliberate state, not test leftover.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Replaced waybar's native idle_inhibitor toggle with a rofi-driven caffeinate feature. New ~/.local/bin/caffeinate script offers a menu (off / indefinite / 1h / 2h / 4h / 8h), reachable independent of the bar; it stops/starts swayidle.service (the repo's existing single source of idle policy) and schedules a systemd --user transient timer for auto-expiry, so a timed session reverts on its own even without waybar running. waybar's custom/caffeine module polls the same script for state and shows remaining time for a timed session. Verified live against the real session (on/off/timed cycles, a real timer expiry, rofi menu and bar screenshots via a throwaway headless-output instance, all torn down afterward) and with checks/session.sh, checks/sway-commands.sh, checks/sway-bindings.sh and checks/manual.sh all passing. docs/manual/02-the-desktop.md updated to match. One pre-existing, out-of-scope finding flagged in the code and to the user: the coffee-cup codepoint carried over from the old module actually renders as a desktop icon on this machine's installed font.
<!-- SECTION:FINAL_SUMMARY:END -->
