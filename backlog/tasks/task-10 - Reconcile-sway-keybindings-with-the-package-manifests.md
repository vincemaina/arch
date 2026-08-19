---
id: TASK-10
title: Reconcile sway keybindings with the package manifests
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 18:15'
updated_date: '2026-08-19 22:21'
labels:
  - foundation
  - desktop
dependencies: []
priority: high
type: bug
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Several bindings in setup/dotfiles/dot_config/sway/config call commands the install never provides, so they fail silently. playerctl is bound for media keys at lines 212-216 but is absent from setup/packages/desktop.txt. The screenshot bindings at lines 245-246 write into ~/Pictures, which nothing creates. polkit is installed but no authentication agent runs, so any GUI privilege prompt fails. The general problem is that the dotfiles and the manifests can drift apart without anything noticing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Media keys control playback on a fresh install
- [x] #2 Both screenshot bindings save a file successfully on a fresh install
- [ ] #3 A GUI action requiring elevated privileges shows a working authentication prompt
- [x] #4 Every external command referenced by the sway config resolves to a package listed in a manifest
- [x] #5 The check for the criterion above is automated so future drift is caught rather than discovered in use
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add the missing packages: playerctl for the media keys, xdg-user-dirs so a screenshot directory exists, polkit-gnome as the authentication agent, and libpulse explicitly since the config calls pactl directly even though pipewire-pulse pulls it in as a dependency.
2. Run the polkit agent as a systemd user unit following the pattern established by TASK-11, rather than as a sway exec line.
3. Move the three screenshot bindings into a helper script that resolves the pictures directory through xdg-user-dir, creates it if absent, and handles the full-screen, region and clipboard cases. That removes the duplicated date and grim invocations and fixes the actual bug, which is writing to a directory nothing creates.
4. Write checks/sway-commands.sh, outside setup/ because it is repository tooling rather than machine payload. It extracts every command the session invokes and verifies each is owned by a package declared in a manifest.
5. Cover three surfaces: exec targets in the sway config with set variables expanded, absolute ExecStart paths in the session units, and the external commands used by helper scripts, which are declared in a "# requires:" header so they can be checked without parsing arbitrary shell.
6. Make the check enforce its own convention: a helper script with no requires header is a failure, so the declaration cannot be quietly skipped.
7. Verify extraction offline with a stub pacman, since resolving a command to its owning package needs a real Arch system.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Added playerctl, xdg-user-dirs, polkit-gnome and libpulse to desktop.txt, plus pacman-contrib to dev.txt for pactree, which the check needs to resolve dependency closure.

polkit-gnome runs as a session unit following the TASK-11 pattern. Chosen over the Qt agents because the desktop already pulls GTK3 through Waybar and Thunar; noted in DECISIONS.md that it is unmaintained upstream and mate-polkit is the drop-in replacement if that becomes a problem.

Screenshots moved into ~/.local/bin/sway-screenshot, which resolves the pictures directory through xdg-user-dir, falls back to ~/Pictures, and creates it. That fixes the actual bug and removes the duplicated grim and date invocations across three bindings. Bindings call it by path because ~/.local/bin is not guaranteed to be on the PATH sway inherits, and a binding that silently does nothing is exactly what this replaced.

checks/sway-commands.sh lives outside setup/ as repository tooling. It resolves each command to its owning package with pacman -Qoq and accepts anything within the dependency closure of the manifests via pactree, so coreutils commands like date are correctly accepted through base without being listed.

Verified: extraction produces the expected command set from all three surfaces, with set variables expanded ($term to foot, $menu to wofi). The resolution logic was exercised against stubs across all five branches - repo helper present, repo helper missing, command not installed, owned by an undeclared package, owned by no package at all - producing exactly the expected four failures. The missing-header rule was tested separately and correctly fails a script without one.

AC #1, #2 and #3 need the VM: whether media keys, both screenshot bindings and a privilege prompt actually work end to end. AC #4 is verified only as far as the checker logic goes; running it for real needs pacman and pactree.

checks/sway-commands.sh run by the user on the VM against a real package database: all referenced commands accounted for, exit clean. That verifies AC #4 directly, and implies the new packages are installed, since the check resolves every command through command -v before looking up its owning package - playerctl, xdg-user-dir, polkit-gnome and libpulse would each have failed as "not installed" otherwise.

Still outstanding: AC #1, #2 and #3 are behavioural rather than resolvable by the checker. A command existing and being declared does not prove the binding fires, that grim writes a file, or that the agent renders a prompt.

checks/session.sh on the VM found the screenshot helper writing to /home/vincemaina/ rather than a pictures directory. Cause: when XDG user directories have never been set up, xdg-user-dir answers with $HOME instead of failing, and the fallback only triggered on an empty answer. Fixed by treating an answer equal to $HOME as unconfigured. Verified against a stub xdg-user-dir that returns $HOME, which now lands the file in ~/Pictures.

User confirms volume and media keys working, and notes volume was working before this change. That is correct, and worth recording precisely because the original task description conflated the two.

The volume keys call pactl, provided by libpulse, which pipewire-pulse has always pulled in as a dependency. They were never broken. Adding libpulse to desktop.txt is manifest honesty about a command the config invokes directly, not a fix.

The playback keys call playerctl, which was in no manifest and not installed, so those genuinely could not have worked. The failure was invisible because play-pause does nothing observable unless an MPRIS-capable player is running, which makes a missing binary and an idle system look identical.

AC #1 is therefore only partly verified: the volume half is confirmed, and playerctl is confirmed installed and resolvable by checks/sway-commands.sh, but controlling actual playback has not been observed against a running player.

Print and Shift+Print confirmed working by the user, verifying AC #2: both screenshot bindings save a file. That covers the binding path as well as the helper, which the check exercises directly.

Remaining: the polkit agent. checks/session.sh can confirm the agent process is running but not that polkit actually routes a request to it, which needs an interactive prompt. The manual step now names the exact command, pkexec --disable-internal-agent true, rather than describing the situation vaguely. The flag matters: plain pkexec on a tty falls back to its own text-mode agent and would say nothing about the graphical one.
<!-- SECTION:NOTES:END -->
