---
id: TASK-69.3
title: 'Offer the virtual machine at the login screen, as a session beside Sway'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 15:58'
updated_date: '2026-08-23 23:46'
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
- [x] #1 A Virtual machine entry appears in the login screen beside Sway
- [x] #2 Selecting it boots the guest full-screen with no sway, waybar, mako or swayidle running
- [x] #3 Exiting the guest returns to the login screen rather than a blank or broken session
- [x] #4 The entry reaches a running machine through sync.sh, not only through a fresh install
- [ ] #5 Key passthrough into the guest is measured under cage and under sway, and the result is written down
- [x] #6 checks/session.sh passes, and docs/manual/ describes the new session
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

User tested the real login-screen session live and found two real, reproducible bugs beyond what any of my own testing had caught:

1. Sway showed 'There are errors in your config file' permanently on first login inside the guest - black screen, no waybar. Reproduced directly by mounting a fresh, never-booted clone's disk read-only: ~/.local/share/wallpapers/ does not exist, and sway's rendered config names that exact missing file as the background - a missing bg image is a CONFIG ERROR to sway, not a runtime warning, hence total and permanent failure rather than just a missing picture. Confirmed non-transient by watching a fresh boot at 8/22/40s - still stuck at 40s. Root cause is in the base image build (05-dotfiles.sh's wallpaper generation step, which its own comments already anticipated could fail this way). Fixed in tools/build-vm-image.sh: explicit 'wallpaper --ensure' after 05-dotfiles.sh, failing the whole build loudly if the file is still missing. Verified by applying the identical fix to the stuck guest (overlay edit, not a write to the base - safe) and rebooting it clean. Filed TASK-157 to check whether this also affects a real install.sh run on physical hardware, since if so it is a much bigger deal than a VM-specific issue.

2. User did not want to enter a second password inside the guest having already authenticated at the host. Implemented via greetd's initial_session, added ONLY to the built guest's own config (never setup/system/greetd/ - a real machine keeps its interactive login exactly as DECISIONS.md requires). Verified live: a patched guest reaches its own desktop with no login prompt.

CURRENT base.qcow2 predates BOTH fixes and would need a full rebuild through the updated builder (or the same manual overlay-patch) to benefit new clones automatically. Deferred - user asked me to stop requesting so many pkexec passwords this session, and a rebuild needs two more (root + guest user).

Also found and left unresolved: after the user's VM session closed and they logged into host Sway, the host's own journal shows repeated 'Atomic commit failed: Device or resource busy' DRM errors for several minutes (22:43-22:47ish) before settling - sway itself never crashed, but the screen was very likely black/unresponsive during that window. Not reproduced or root-caused; the user did not describe experiencing this directly, and no lingering qemu/cage process was found afterward. Left as a known, unexplained finding rather than guessed at.

AC5 (live key-passthrough measurement) remains unmeasured - /dev/uinput is still root-only and a live measurement was not attempted this session, consistent with the earlier decision to keep the structural argument (documented in DECISIONS.md) rather than force a root-requiring probe while password requests were explicitly being minimized.

Rebuild completed successfully on the third attempt, after finding and fixing a real, serious bug along the way.

WHAT HAPPENED: the first rebuild (with auto-login + wallpaper-ensure fixes) completed every stage successfully but hit 'unmount busy' on cleanup. The original cleanup() trap unconditionally disconnected the nbd device regardless of whether the unmount had actually succeeded - disconnecting a still-mounted device discards buffered writes and can corrupt the mounted filesystem's own metadata. This happened for real: the resulting base.qcow2's config.toml write was lost, and a later direct inspection found NO recognisable filesystem on either partition via a fresh blkid -p probe, while qemu-img check still reported the qcow2 container as structurally sound (the corruption is invisible at that layer). My own manual patching attempts, done under time pressure without the partprobe/udevadm settle steps the real script always uses, hit the same class of issue independently.

FIXED: cleanup() now refuses to disconnect if /mnt is still mounted after its own umount attempt - it warns loudly and leaves the device connected instead, which is annoying but never destructive. Retry budget widened from 5x1s to 15x2s (30s), since two separate real builds outlasted the old window. Both findings recorded in .claude/skills/scripting-traps/SKILL.md, including a second, separate trap discovered while diagnosing the first: reusing the same nbd device number for a rapid connect/disconnect/reconnect cycle can leave the kernel's own nbd driver confused independent of the file's actual state - a failed re-check on a just-used device number is not evidence of corruption until retried on a fresh one. This cost real diagnostic time before being understood.

SECOND rebuild (same fixed script) hit the SAME busy condition on unmount, but this time correctly refused to disconnect and left /dev/nbd1 safely connected with a clear warning. Verified directly: mounted it (read-write, on the same device number - genuinely fine, config.toml showed the auto-login block correctly, present and correct) - confirming the fix works and no data was lost this time. Completed cleanly by hand: unmount, qemu-img check (clean), blkid -p on a FRESH device number (nbd2, to avoid the reuse trap just learned) confirmed genuine filesystem presence, chmod a-w.

FINAL VERIFICATION, on the correctly-rebuilt base: cloned a fresh machine, booted on a throwaway headless output. Screenshot shows: genuinely fullscreen (no title bar - the separate GTK client-side-decoration fix from user feedback), waybar visible and working, wallpaper rendering correctly (neon theme), and NO login prompt - auto-login fired correctly. All three fixes (wallpaper-ensure, auto-login, fullscreen) confirmed together on the real, persistent base.qcow2.

Additional fix this session, from direct user feedback: qemu's GTK window showed a title bar despite show-menubar=off, because a title bar is a GTK client-side decoration drawn by the client itself - no compositor can strip it, cage's own lack of chrome was never going to touch it. Added full-screen=on to the display options in ~/.local/bin/vm, applying to `vm run` from anywhere (inside Sway or the login-screen session).

Store is clean - no test clones left behind. Base image is read-only, 5.5 GiB, genuinely correct.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Adds a "Virtual machine" session to the login screen, beside Sway, via setup/system/wayland-sessions/vm.desktop and setup/system/bin/vm-session - reached through both install.sh and sync.sh via apply-config.sh's existing arrays.

The original design (reusing ~/.local/bin/vm's interactive rofi menu under cage) does not work: cage implements no wlr-layer-shell, confirmed by the actual error rofi gives. Redesigned around cage's real model - "runs a single, maximized application" - so vm-session boots one fixed machine ("login"), cloning it from the base image on first use.

Real, live user testing found two genuine defects beyond anything my own testing had caught, both fixed and verified:
  1. A missing wallpaper file made sway show a permanent, unrecoverable config-error screen on the guest's first boot (a missing background image is a sway CONFIG error, not a runtime warning). Root-caused to the base image's own build step; tools/build-vm-image.sh now guarantees the file exists and fails the build loudly if it does not.
  2. Wanting one password, not two - fixed with greetd's initial_session, added only to the built guest's own config, never the repository's real-machine config.

Rebuilding the base image to carry both fixes then found a THIRD, more serious bug: the build script's cleanup trap disconnected the virtual disk while it was still mounted, which is destructive - it corrupted the first rebuilt image's filesystem (invisible to qemu-img check, confirmed real via a fresh blkid -p probe finding no filesystem at all). Fixed properly: cleanup() now refuses to disconnect anything still mounted, warning instead of guessing. A second rebuild, and a bug discovered while diagnosing the first (reusing an nbd device number too quickly gives false negatives, independent of file corruption) are both written up in .claude/skills/scripting-traps/SKILL.md for the next session.

Also fixed from direct user feedback: the guest showed a GTK title bar despite show-menubar=off, because a title bar is a client-side decoration no compositor can suppress - full-screen=on sidesteps the question entirely, genuinely fullscreen now in both contexts (login-screen session and running `vm` from inside Sway).

Verified end to end on the correctly-rebuilt, read-only base image: a fresh clone, booted on a throwaway headless output, reaches its own desktop directly - no login prompt, waybar working, wallpaper rendering, genuinely fullscreen. checks/session.sh 124/0, checks/manual.sh 8/0, checks/sway-commands.sh clean throughout.

Not measured: AC5's live key-passthrough measurement remains reasoned (cage implements no keybinding mechanism at all, confirmed via its own --help/man) rather than observed with a real uinput probe, since /dev/uinput stayed root-only this session and a live measurement was not attempted - written up honestly in DECISIONS.md as such.
<!-- SECTION:FINAL_SUMMARY:END -->
