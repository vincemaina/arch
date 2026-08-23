---
id: TASK-157
title: >-
  Confirm whether a fresh install's first login can show sway's config-error
  screen too
status: To Do
assignee: []
created_date: '2026-08-23 22:42'
labels: []
dependencies: []
priority: high
ordinal: 166000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found and reproduced while working on TASK-69.3: a virtual machine cloned from a base image built via tools/build-vm-image.sh, on its first-ever boot, shows sway's own "There are errors in your config file" banner - permanently, with a black screen, no waybar, no wallpaper. It does not self-heal.

Root cause, confirmed by mounting a never-booted clone's disk read-only: ~/.local/share/wallpapers/ does not exist. Sway's rendered config names that exact file as the background image (`output * bg .../abyss-mesh.png fill`), and a background image that does not exist is treated as a CONFIG ERROR by sway, not a missing-picture warning - which is why the failure is total and permanent rather than cosmetic.

The wallpaper is supposed to be generated during 05-dotfiles.sh's chezmoi apply, by run_onchange_after_reload-theme.sh.tmpl - its own comment says so explicitly: "the installer runs this in a chroot where there is no sway at all... getting that wrong would mean every fresh machine's first login had no wallpaper." On this build it evidently did not happen, or failed silently: the generation call is backed by `|| echo "...could not generate the wallpaper..." >&2`, a warning that would be trivially lost in a pacstrap-and-apply build's scrollback rather than a hard stop.

tools/build-vm-image.sh now works around this for VM images specifically - it calls `wallpaper --ensure` explicitly after 05-dotfiles.sh and fails the whole build loudly if the file still does not exist. That is a targeted fix for the VM builder, not a diagnosis of the underlying mechanism.

The open question this task is for: is this ALSO true of a genuine `install.sh` run against real hardware? If 05-dotfiles.sh's chezmoi apply has the same gap there, every fresh install of this repository could be hitting this exact failure on first login - a much bigger deal than a VM-specific workaround, and worth knowing regardless of whether TASK-69's VM builder happens to route around it.

Leading hypothesis, not yet confirmed: wallpaper --ensure calls into desktop_config.py, which itself invokes `chezmoi --source ... data` (and `apply --force` for other operations) as a SEPARATE chezmoi process - and this all happens from INSIDE a run_onchange_ script that the OUTER `chezmoi apply` (05-dotfiles.sh's own call) is currently executing. A nested/re-entrant chezmoi invocation, if chezmoi holds any kind of lock during apply, is exactly the shape of failure that would reproduce reliably in a chroot install and not necessarily show up in ad-hoc testing on an already-converged machine (where the run_onchange script does not re-run at all, since nothing about its rendered content changed).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Confirmed whether wallpaper --ensure genuinely fails during a real install.sh run's 05-dotfiles.sh stage, not just assumed from the VM builder's own workaround
- [ ] #2 If it does fail there too, either the root cause is fixed in run_onchange_after_reload-theme.sh.tmpl / desktop_config.py directly, or 05-dotfiles.sh gains the same explicit --ensure-and-verify step tools/build-vm-image.sh now has
- [ ] #3 If a nested chezmoi invocation from within a run_onchange_ script turns out to be the cause, that constraint is written down somewhere a future run_onchange_ script would actually see it
<!-- AC:END -->
