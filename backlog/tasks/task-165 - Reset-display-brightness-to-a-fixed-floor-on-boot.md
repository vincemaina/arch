---
id: TASK-165
title: Reset display brightness to a fixed floor on boot
status: Done
assignee:
  - '@claude'
created_date: '2026-08-24 09:40'
updated_date: '2026-08-24 09:52'
labels:
  - desktop
dependencies:
  - TASK-162
priority: medium
ordinal: 172000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-162 found that ~/.local/bin/brightness (executable_brightness) writes straight to the kernel backlight sysfs interface via brightnessctl - real hardware/kernel state that is never reset by logout, a crash, or a reboot. If brightness is left near zero and the session then ends unexpectedly (crash, dead battery), the panel stays at that same near-black level through boot and into the greeter, which looks like a dead screen rather than a login prompt with brightness turned down. Fix this at the root: always set brightness to a fixed floor (around 70%) early in boot, before ReGreet/greetd starts, rather than trusting whatever level was last set. This intentionally overrides even a deliberately low setting from the previous session - simplicity and guaranteed visibility win over preserving an intentional low value across reboots.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 On every boot, before the greeter is shown, brightness is set to a fixed floor of approximately 70%, regardless of what it was set to when the machine last shut down or crashed
- [x] #2 This does not fight the existing brightness keybinding once a session is running - the floor only applies at boot, not continuously
- [x] #3 Works whether the previous shutdown was clean or the machine crashed/lost power, since kernel backlight state persists either way
- [x] #4 Documented in docs/manual/ alongside the existing brightness section
- [ ] #5 checks/session.sh still passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a new system unit setup/system/systemd/brightness-floor.service: a oneshot root service running 'brightnessctl set 70%', ordered Before=greetd.service so it runs before the greeter is shown, WantedBy=multi-user.target (same pattern as earlyoom/keyd) so it is pulled into the boot transaction. No explicit After= needed for the backlight restore: systemd-backlight@.service is Before=sysinit.target (DefaultDependencies=no), and multi-user.target is only reached after sysinit.target/basic.target, so this unit always starts after any backlight-restore unit completes, whatever its instance name (hardware-specific, so not hardcoded).
2. Wire it into setup/system/apply-config.sh: add the file to CONFIG_FILES (installs to /etc/systemd/system/brightness-floor.service) and add brightness-floor to ENABLE_UNITS so both install.sh (04-desktop.sh) and sync.sh enable it. Deliberately not started with --activate (that would change the running session's brightness mid-sync, which is the keybinding's job, not this unit's) - it only needs to be *enabled* for next boot.
3. Add a checks/session.sh check: the unit file is installed and enabled, and its ordering (Before=greetd.service) is present via systemctl show.
4. Document in docs/manual/ alongside the existing brightness material (04-applications.md brightness section / 02-the-desktop.md limit-sound section) - state the floor, why it always overrides (kernel state, TASK-162's finding), and that it applies once at boot only, not continuously.
5. Verify: install/enable on this real machine via sync.sh or manual systemctl enable, confirm systemctl status/journal shows it ran successfully, and confirm via brightnessctl -m that it actually applied 70%. Note that a genuine reboot is needed to prove Before=greetd.service actually holds true at real boot time - flag this as unverified-without-reboot in the report.
6. Run checks/session.sh and checks/manual.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added setup/system/systemd/brightness-floor.service: Type=oneshot root service running 'brightnessctl set 70%', Before=greetd.service, WantedBy=multi-user.target (same enablement pattern as earlyoom/keyd). No explicit After= for backlight restore is needed: systemd-backlight@.service is Before=sysinit.target with DefaultDependencies=no on this real machine, and multi-user.target is only reached after sysinit.target/basic.target - confirmed by inspecting the real greetd.service, systemd-backlight@.service and the multi-user.target dependency chain on this machine with systemctl cat/list-dependencies, not assumed. Wired into setup/system/apply-config.sh's CONFIG_FILES and ENABLE_UNITS, so both install.sh and sync.sh reach it - deliberately NOT started with --activate, since starting it mid-sync would change the running session's brightness, which is the keybinding's job, not this unit's; it only needs to be enabled for the next boot. Added a 'Brightness floor (TASK-165)' section to checks/session.sh verifying the unit is installed, enabled, ordered Before=greetd.service (via systemctl show -p Before), and Type=oneshot (so it cannot fight the brightness keybinding). Documented in docs/manual/04-applications.md immediately after the existing TASK-162 VM-guest/greeter brightness material, cross-referencing TASK-162's finding that backlight is kernel state that carries over regardless of shutdown type. Verified with checks/manual.sh: 8/8 passed, manual builds cleanly.

Verification, and its honest limits (no root/sudo access in this sandboxed session - sudo requires an interactive password not available here, and I deliberately did not trigger the machine's graphical polkit prompt or reboot the user's live session without asking): (1) 'systemd-analyze verify setup/system/systemd/brightness-floor.service' run directly against the REAL installed system (not a throwaway root) returns exit 0 with zero warnings/errors - this resolves Before=greetd.service against the real, already-installed greetd.service on this machine and confirms /usr/bin/brightnessctl exists and is executable, so the unit is genuinely loadable and its ordering directive is valid, not just syntactically well-formed. (2) bash -n on the edited apply-config.sh passes. (3) checks/session.sh run on this real machine: 124 passed, 4 failed - all 4 failures are the new brightness-floor checks themselves, failing for the expected reason that the unit is not yet installed on THIS machine (no root available to run sync.sh --activate or install the file to /etc/systemd/system/), not because of any logic bug - confirmed no other check regressed. (4) NOT verified: the unit actually installed and running on a real system (systemctl status/journal, brightnessctl -m reading before/after), and the true end-to-end claim of AC1 (applies before the greeter on an actual boot, clean or crashed) - both need root to install and, for the boot-order claim, an actual reboot, neither of which this session can do. Left explicitly open for a human with sudo access: run 'sudo ./sync.sh' (interactive password), then 'systemctl status brightness-floor', 'journalctl -u brightness-floor', 'brightnessctl -m' to confirm the 70% floor applied, and re-run checks/session.sh to see it go 128/0. A genuine reboot is the only way to fully confirm AC1's 'before the greeter, every boot, clean or crashed' claim live. Same honest-gap pattern as TASK-160's VM-guest verification.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added a systemd system unit, setup/system/systemd/brightness-floor.service, that runs 'brightnessctl set 70%' once, Before=greetd.service, so the panel is never left near-black through boot and into the greeter (TASK-162's finding that backlight is real kernel state that survives logout, crash, or reboot). Wired into setup/system/apply-config.sh (CONFIG_FILES + ENABLE_UNITS) so it reaches install.sh and sync.sh identically, enabled but never started by --activate (starting it mid-sync would fight the running session's brightness). It is Type=oneshot with no session-scoped [Install] target, so it cannot fight the brightness keybinding once a session is running. Documented in docs/manual/04-applications.md next to the existing TASK-162 brightness material. Added a checks/session.sh section verifying install, enable, Before=greetd.service ordering, and Type=oneshot.

Verified: systemd-analyze verify against the real installed system returns exit 0 with zero warnings (Before=greetd.service resolves against the real unit, /usr/bin/brightnessctl exists and is executable). checks/manual.sh: 8/8 passed. checks/session.sh: 124 passed, 4 failed - the 4 failures are exactly the new brightness-floor checks, failing only because this sandboxed session has no root/sudo to actually install the unit onto this real machine (no interactive password available, and I deliberately avoided triggering the machine's graphical polkit prompt or rebooting the user's live session without asking). AC1 (applies on every boot, before the greeter, clean shutdown or crash) and AC5 (checks/session.sh passes) are therefore left unchecked - they need a human with sudo to run './sync.sh' and, for AC1's boot-order claim specifically, an actual reboot, neither of which this session could do. AC2 (does not fight the keybinding), AC3 (works regardless of clean/crashed shutdown, by design - the unit unconditionally overwrites to a fixed value and never reads prior state), and AC4 (documented) are checked on direct evidence. Same honest-gap pattern TASK-160 used for its VM-guest verification.
<!-- SECTION:FINAL_SUMMARY:END -->
