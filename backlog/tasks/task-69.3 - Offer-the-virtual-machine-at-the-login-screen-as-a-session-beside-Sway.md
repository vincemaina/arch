---
id: TASK-69.3
title: 'Offer the virtual machine at the login screen, as a session beside Sway'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-23 15:58'
updated_date: '2026-08-23 21:19'
labels: []
dependencies:
  - TASK-69.2
parent_task_id: TASK-69
ordinal: 162000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Pick "Virtual machine" at the login screen and boot straight into the guest, with no desktop session behind it.

This is the cheapest part of TASK-69, because the architecture already anticipated it. setup/system/greetd/regreet.toml says in as many words: "That is also what will make a second desktop selectable if one is ever added." ReGreet builds its picker by scanning the wayland-sessions directories, and greetd/config.toml already forces XDG_DATA_DIRS so that /usr/local/share is searched first.

Scope - three files, one of them a single added line:

  * setup/system/wayland-sessions/vm.desktop - the entry ReGreet will find.
  * setup/system/bin/vm-session - the launcher. cage hosts it, exactly as it hosts ReGreet, so the kiosk compositor costs no new package. Precedent for the install path: setup/system/bin/xdg-terminal-exec already reaches /usr/local/bin this way.
  * One line in the file map in setup/system/apply-config.sh, so the entry reaches both the installer and sync. Adding it to only the installer means it can never reach a running machine - a bug this repository has already had, and one checks/session.sh caught.

Deliberately NOT via uwsm. uwsm exists to reach wayland-session@sway.target and start waybar, mako, swayidle and the polkit agent. This session wants none of them; that absence is the entire point. The lifecycle falls out for free: when qemu exits, cage exits, the session ends, and greetd returns to the picker.

Two things to get right rather than discover:

  * The launcher must be referenced by absolute path from /usr/local/bin, not by bare name and not from ~/.local/bin. A greetd-launched session does not get an interactive shell's PATH - the same trap documented for waybar's click commands in CLAUDE.md.
  * ReGreet caches the last session per user (user_to_last_sess), so the boot after a VM session defaults back to VM rather than Sway. Confirm that is wanted; regreet.toml also has skip_selection, which interacts with it.

Known UX difference from the original request, accepted rather than fixed: ReGreet shows the picker on the login form beside the username, not as a separate prompt after the password. Same choice, different order. Making it strictly post-password would mean patching ReGreet and is not worth it.

Also verify: whether key passthrough actually improves. The claim is that sway grabs every $mod combo so a guest never sees Super+Enter, and cage grabs almost nothing. Sway does implement keyboard-shortcuts-inhibit, so a display client using it could work around this inside sway too - unverified either way, and it is the strongest argument for this task, so it should be measured rather than asserted. Load the desktop-verification skill before checking.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A Virtual machine entry appears in the login screen beside Sway
- [ ] #2 Selecting it boots the guest full-screen with no sway, waybar, mako or swayidle running
- [ ] #3 Exiting the guest returns to the login screen rather than a blank or broken session
- [ ] #4 The entry reaches a running machine through sync.sh, not only through a fresh install
- [ ] #5 Key passthrough into the guest is measured under cage and under sway, and the result is written down
- [ ] #6 checks/session.sh passes, and docs/manual/ describes the new session
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. setup/system/wayland-sessions/vm.desktop - a real, selectable entry (unlike sway.desktop, which is a Hidden suppression of the packaged one). Exec names the launcher by absolute path directly, matching sway-uwsm.desktop's own reasoning for not going through a desktop-entry-ID lookup.

2. setup/system/bin/vm-session (executable, installed via apply-config.sh's EXECUTABLES array like xdg-terminal-exec) - resolves the real user's home via `getent passwd` rather than trusting $HOME, for the same reason build-vm-image.sh had to stop trusting it: a greetd-launched session's environment is not something to assume correct when settling it costs one command. Sets WLR_NO_HARDWARE_CURSORS=1 (the same reason ReGreet's own cage invocation does, documented in greetd/config.toml). Runs `cage -s -- <real-home>/.local/bin/vm` with no arguments, reusing the existing menu (list/create/run, including the "no machines yet, clone from base" path) rather than duplicating machine-selection logic - it already works, proven in TASK-69.1.

3. Two lines in apply-config.sh's existing arrays: vm.desktop into CONFIG_FILES (mode 644, like the other wayland-sessions entries), vm-session into EXECUTABLES (mode 755, like xdg-terminal-exec). Reaches both install.sh and sync.sh from one place, which is the whole reason those arrays exist.

4. AC5 (key passthrough measurement) cannot be done safely right now: /dev/uinput is root-only (no root available this session) and I will not risk stealing real keyboard input from the user's actual session while they are using it for something else. Fall back to the strongest evidence obtainable without those: cage's own --help/man confirm no keybinding configuration mechanism exists at all (no config file, no bind flags), which is a structural rather than assumed argument - sway explicitly registers ~76 bindings that intercept before a client ever sees them; cage has no equivalent mechanism to register any. Documented as the reasoning, with the live measurement explicitly left open pending either root access or a live login-screen test.

5. What IS safely testable without root or touching the user's real input/screen: cage hosting the real ~/.local/bin/vm menu, nested inside the current sway session on a throwaway headless output (not the real screen) - proves rofi renders correctly under cage's compositor, which is a real, previously-unverified assumption (rofi's own theme/config is user-level and compositor-agnostic in principle, but "in principle" is not evidence).

6. checks/session.sh, checks/manual.sh cannot see the new session as REACHING a machine until sync.sh actually runs, which needs root - deferred to when the user is available. What CAN be checked now: syntax, checks/sway-commands.sh (the launcher's own command dependencies), and that the desktop entry itself is well-formed.

7. Manual: chapter 2 (the desktop / login) is the likely home for describing session selection at the login screen - check what's already there before adding, per the "should not restate" rule.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented, not yet verified live (needs root for sync.sh, or a real login-screen test - neither available this session; user asked not to be prompted for a password while watching a movie).

FILES:
  - setup/system/wayland-sessions/vm.desktop - real, selectable entry (unlike sway.desktop's Hidden suppression)
  - setup/system/bin/vm-session - the launcher, installed via apply-config.sh's EXECUTABLES array
  - apply-config.sh: one line each in CONFIG_FILES and EXECUTABLES

DESIGN CHANGED MID-TASK, for a real reason found by testing rather than assumed: the original plan was `cage -s -- ~/.local/bin/vm` (the existing interactive menu, reusing all of TASK-69.1's logic). Tried it directly - cage cannot host rofi at all. Confirmed via the actual error: "Rofi on wayland requires support for the layer shell protocol", and cage implements no wlr-layer-shell (matches its own --help/man, which document no config mechanism of any kind). This would have crashed immediately at the real login screen.

Redesigned around cage's actual model ("runs a single, maximized application"): vm-session boots one fixed, conventionally-named machine ("login"), cloning it from the base image the first time and simply running it every time after - no menu, no rofi. If cloning fails (most likely: no base image built yet), it falls back to a plain `foot` window showing the error rather than silently bouncing back to the login screen with nothing explained - `set -e` is deliberately NOT relied on for this one branch, the failure is caught and handled visibly on purpose.

VERIFIED SAFELY (no root, no real guest, no risk to the user's own session):
  - syntax of both new/changed scripts
  - checks/session.sh 122/0, checks/manual.sh 8/0 (both read-only, run against the CURRENT unsynced system - correctly do not yet see the new session, since sync.sh has not run)
  - the fallback path's LOGIC, via filesystem trace: pointed XDG_DATA_HOME at an empty scratch dir, ran vm-session, confirmed `login/` was never created under it (meaning `vm new login` correctly failed and the fallback branch was taken) - the ONE genuine mistake this session: an early ad hoc test of the `foot -e sh -c ...` construction was run without targeting a headless output and briefly appeared on the user's REAL session for a few seconds before self-exiting. Apologised; every test after that point explicitly targeted a headless output.

FOUND AND FIXED A REAL TESTING-INFRASTRUCTURE GAP along the way, added to the desktop-verification skill: a freshly created headless output can be powered off, and grim fails outright ("no supported format found") until `swaymsg output HEADLESS-N dpms on` is run. Beyond that, grim was found to sometimes return a flat, uniform capture for a client (a plain foot window, not nested in cage) that swaymsg's own get_tree confirms is genuinely present, correctly sized, and erroring at nothing - cross-checked with forced, unambiguous colours (red background, black text) to rule out a theme contrast coincidence, which also came back flat. The same class of failure the keyd uinput probe in scripting-traps describes: an apparatus that looks like it is measuring and is not. Not fully explained - a qemu GTK window captured cleanly under the identical recipe in TASK-69.1 - so this is a real, open limitation of the test method for at least some clients, not evidence against vm-session's own correctness. Documented rather than worked around blindly.

STILL NEEDS, once the user is free and comfortable with root actions / a live test:
  - AC1: entry actually appears in ReGreet - needs sync.sh
  - AC2: guest boots full-screen with nothing else running - needs sync.sh, then picking the session at a real login
  - AC3: exiting returns to the login screen - same
  - AC4: entry reaches a running machine via sync.sh, not only a fresh install - this literally IS the sync.sh run, so it and AC1 close together
  - AC5: key passthrough measurement - needs either a uinput probe (root) or a live login-screen test with a real keyboard; the structural argument (cage has no keybinding mechanism at all) is written up in DECISIONS.md, honestly marked as reasoned rather than measured
<!-- SECTION:NOTES:END -->
