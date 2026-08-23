---
id: TASK-69.3
title: 'Offer the virtual machine at the login screen, as a session beside Sway'
status: To Do
assignee: []
created_date: '2026-08-23 15:58'
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
