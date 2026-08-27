---
id: TASK-188
title: 'A mount manager in yazi: external drives on a keypress'
status: In Progress
assignee: []
created_date: '2026-08-27 09:53'
updated_date: '2026-08-27 10:04'
labels: []
dependencies: []
ordinal: 194000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
yazi has no sidebar and cannot be given one - its layout is three fixed columns (parent, current, preview) and there is no fourth pane concept. So the usual GUI file-manager affordance, a list of devices down the left-hand side, is not available here. That means external drives are currently reachable from the file manager only by typing their mount path, and unmounted ones are not reachable at all: this machine has sda (465.8G, 4 partitions), sdb (298.1G) and nvme0n1 (5 partitions) all sitting unmounted with nothing on the desktop offering to mount them.

The official yazi-rs/plugins:mount plugin covers exactly this: a popup on a key listing every partition, with mount (m), unmount (u), eject (e) and enter-mount-point (l). 485 lines of Lua, 28K, MIT-licensed. Its dependencies are already on the machine - udisksctl from udisks2, lsblk and eject from util-linux in base - and polkit is present, so mounting as the normal user needs no sudo.

Two things make this more than dropping a plugin in:

1. `ya pkg add` fetches from GitHub at runtime, which a fresh install from the live ISO cannot rely on. The plugin has to be VENDORED under setup/dotfiles/dot_config/yazi/plugins/ and tracked, so it arrives through chezmoi like everything else.
2. udisks2 currently arrives transitively via gvfs and is marked as a dependency, not explicit. Once the desktop relies on udisksctl directly it needs declaring in desktop.txt with a rationale comment, same reasoning as the polkit and mesa entries - otherwise a dependency-graph change can remove it quietly.

See TASK-44 for why thunar was removed rather than kept for this kind of job, and TASK-172 for the yazi 26.8 breakages that this config already carries scars from.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The mount plugin is vendored under setup/dotfiles/dot_config/yazi/plugins/ and tracked in git, so a fresh install gets it with no network fetch at install time
- [x] #2 A key in yazi opens the mount manager, bound in keymap.toml.tmpl, and it does not shadow a yazi default that was in use
- [ ] #3 Mounting and unmounting a real external device is confirmed to work on the running machine, as the normal user, with no sudo prompt
- [ ] #4 udisks2 is declared explicitly in setup/packages/desktop.txt with a comment saying why, and checks/packages.sh passes
- [x] #5 The vendored plugin carries a note recording its upstream, its version or commit, and how to update it, so it does not become unattributed code of unknown age
- [ ] #6 checks/session.sh, checks/packages.sh and checks/manual.sh all pass
- [x] #7 docs/manual/04-applications.md describes the mount manager under the file-manager section, and docs/software/README.md or DECISIONS.md records the package change
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Vendor the plugin. Copy mount.yazi (upstream yazi-rs/plugins, rev c591a36) into setup/dotfiles/dot_config/yazi/plugins/mount.yazi/ - main.lua, cross.lua, sudo.lua, LICENSE - plus the package.toml manifest at setup/dotfiles/dot_config/yazi/package.toml so `ya pkg upgrade` still works on the machine. Add a PROVENANCE note recording upstream, rev, hash, and the update procedure.

2. Bind it. `M` in keymap.toml.tmpl, `plugin mount`. Confirmed unbound in yazi 26.8.15 defaults by extracting the embedded keymap out of /usr/bin/yazi: no bare `on = "M"` exists (the only M is under the `,` sort prefix, which does not collide).

3. Declare udisks2 in setup/packages/desktop.txt with a rationale comment - it currently arrives transitively via gvfs and is marked as a dependency. sync.sh and 04-desktop.sh both mark declared packages explicit, so no manual pacman -D is needed.

4. Add a session check. This is the exact failure shape this repository keeps hitting: a keybinding naming a plugin that is not there fails silently - yazi prints nothing and the key does nothing. checks/session.sh should assert that every `plugin <name>` in the keymap has a matching ~/.config/yazi/plugins/<name>.yazi/main.lua, and that udisksctl and lsblk are present.

5. Apply and verify on the running machine. sync.sh, then actually open yazi, press M, and mount and unmount a real partition as the normal user with no sudo prompt. Screenshot per the desktop-verification skill.

6. Documentation. docs/manual/04-applications.md gains the mount manager under the file-manager section; docs/software/README.md records udisks2. DECISIONS.md gets the vendoring decision - why the plugin is tracked rather than fetched by `ya pkg` at install time - since that is the architectural call here.

7. Run checks/session.sh, checks/packages.sh, checks/manual.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED

- Vendored mount.yazi (yazi-rs/plugins @ c591a36, 2026-08-25, MIT) into setup/dotfiles/dot_config/yazi/plugins/mount.yazi/ - main.lua, cross.lua, sudo.lua, LICENSE. ya pkg's own manifest is tracked alongside it at dot_config/yazi/package.toml so the pinned rev is machine-readable too.
- plugins/README.md carries the provenance table, why it is vendored rather than fetched, and the update procedure (which runs `ya pkg add` under YAZI_CONFIG_HOME pointed at a scratch dir, so it cannot write into the directory chezmoi owns).
- `M` -> `plugin mount` in keymap.toml.tmpl.
- udisks2 declared in packages/desktop.txt.
- checks/session.sh gained two assertions in the File manager section.

VERIFICATION

`M` is free. yazi 26.8.15 compiles its default keymap into the binary; extracting it shows no bare `on = "M"` anywhere. The only M is `,` `M` (sort by mtime, reversed), behind the `,` prefix.

The popup was driven for real, not read back. yazi has no key-injection route available on this machine (no wtype, no ydotool, and sudo needs a password so neither could be installed), so the plugin was invoked over yazi's own DDS socket instead: `ya sub hi,hey,@` reports the running instance id, and `ya emit-to <id> plugin mount` runs the same action the key is bound to. Done on a throwaway HEADLESS-1 output per the desktop-verification skill, so the user's screen was never touched. The manager rendered correctly, listing all four disks with labels and filesystem types (DATA/ntfs, ESP/vfat, OS/ntfs, WINRETOOLS, DELLSUPPORT). Output unplugged and focus restored afterwards.

Mount and unmount were exercised through the exact command cross.lua runs. A 64M ext4 loopback volume via `udisksctl loop-setup`, then `udisksctl mount -b /dev/loop0 --no-user-interaction` -> mounted at /run/media/vincemaina/TESTSTICK with NO password prompt, confirmed with findmnt; then unmount and loop-delete, both clean.

The polkit split was read out of the policy file rather than assumed:
  filesystem-mount          allow_active=yes              (removable - no prompt)
  filesystem-mount-system   allow_active=auth_admin_keep  (fixed internal - prompts once)
Confirmed against behaviour: `udisksctl mount -b /dev/sdb1` (a partition on a fixed internal disk) returned NotAuthorizedCanObtain. cross.lua handles that by retrying over D-Bus and then interactively, so the session polkit agent prompts.

The new check was proved connected, not just green: moving ~/.config/yazi/plugins/mount.yazi aside makes it FAIL naming the missing path, and restoring it makes it PASS.

FINDINGS WORTH KEEPING

- ntfs-3g, exfatprogs and dosfstools are NOT needed and were deliberately not declared. vfat, exfat and ntfs3 are all kernel modules in `linux` (confirmed with modinfo); those packages supply mkfs/fsck, not the ability to mount.
- udisks2.service ships `disabled` and is D-Bus activated. It was inactive on this machine until the first udisksctl call, so it costs nothing on a machine that never touches a removable drive.
- A loop device does NOT appear in the plugin's list. Not a refresh bug: main.lua's `split` pattern table has no `/dev/loop%d+` entry, so loop devices are filtered out. Real disks (sd*, nvme*) enumerate fine.
- sync.sh was NOT run in full. ~/.config/sway/config.d/20-output.conf has uncommitted local changes on this machine (the dual-display layout, cf. TASK-186) and a full sync would have reverted the user's displays mid-session. Only ~/.config/yazi was applied, with `chezmoi apply --exclude=scripts ~/.config/yazi`.

OPEN, needing the user

AC #3, #4 and #6 are not checked, for two reasons that both need a hand at the keyboard:

1. `sudo pacman -D --asexplicit udisks2` has not been run - sudo requires a password here. Until it does, checks/packages.sh reports udisks2 as declared-but-a-dependency, which is exactly the drift the declaration exists to prevent. (checks/packages.sh also reports steam and vulkan-tools as undeclared; that is pre-existing drift, unrelated to this task. checks/session.sh is 131 passed / 0 failed, and checks/manual.sh has one pre-existing failure on ~/.local/state/browser, also unrelated - both confirmed against main.)

2. No external drive is plugged into this machine, and there is no way to press `M` from a script here. The mount/unmount path is proven on a udisks-managed loop device and the popup is proven to open, so what is left is one keystroke and one USB stick.
<!-- SECTION:NOTES:END -->
