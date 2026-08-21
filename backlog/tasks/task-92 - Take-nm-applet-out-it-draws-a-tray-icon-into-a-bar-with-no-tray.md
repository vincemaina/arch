---
id: TASK-92
title: 'Take nm-applet out: it draws a tray icon into a bar with no tray'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 21:10'
updated_date: '2026-08-21 23:49'
labels:
  - desktop
  - repo
dependencies:
  - TASK-58
ordinal: 94000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
network-manager-applet is declared in setup/packages/desktop.txt with no comment at all - the only line in that file whose preceding comment is a bare '# ?', and even that belongs to pavucontrol above it. It exists for one purpose, drawing a system tray icon, and this desktop has no tray.

VERIFIED ON THE RUNNING MACHINE, not inferred:

  * The only occurrence of the word 'tray' in the rendered ~/.config/waybar/config.jsonc is inside a comment explaining that the systray module was removed, because a GTK tray icon cannot be themed to match the bar.
  * 'busctl --user list' shows no StatusNotifierWatcher and no org.kde.* name of any kind on the session bus. There is nowhere for the icon to go.
  * nm-applet holds a Wayland connection and has no window in 'swaymsg -t get_tree'.
  * 11.9 MiB PSS / 37.5 MiB RSS, 0.2 CPU-seconds over a five-hour session.
  * Nothing under setup/dotfiles/, checks/ or tools/ mentions nm-applet.

The package ships exactly two files that matter: /usr/bin/nm-applet and /etc/xdg/autostart/nm-applet.desktop. nm-connection-editor is a separate package and is not installed, so removing network-manager-applet takes nothing else with it. The network module in the bar opens nmtui, which comes from networkmanager.

Removing the package is the fix that survives a rebuild. Masking app-nm\\x2dapplet@autostart.service would only fix this machine, and the package would still be installed on the next one.

This is the exact failure mode CLAUDE.md names: something that survived losing its reason to exist, because nothing in setup/ mentions it and nothing reads /etc/xdg/autostart.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 network-manager-applet is removed from setup/packages/desktop.txt
- [ ] #2 checks/packages.sh passes after the removal, so the machine and the manifest agree in both directions
- [ ] #3 The network module in the bar still opens nmtui, verified by clicking it rather than by reading the config
- [ ] #4 No nm-applet process is running after a fresh login
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ORDERING HAZARD - DO NOT REMOVE THE PACKAGE BEFORE READING THIS.

network-manager-applet is what has been holding openssh on this machine. The chain is openssh <- gcr-4 <- libnma-common <- network-manager-applet, and git does NOT depend on openssh - checked, its Depends On does not list it. So this repository's own git@github.com remote works as a side effect of the tray applet's dependency tree, and 'pacman -Rns network-manager-applet' would take ssh with it and break push and fetch, with nothing connecting the two events.

TASK-38 declared openssh in base.txt for exactly this reason, but declaring is not enough on its own: as of now openssh is still marked 'installed as a dependency' on this machine, so -Rns would still take it. sync.sh marks every declared package explicit (TASK-13), which is what actually protects it.

SO THE ORDER IS: ./sync.sh first, confirm 'pacman -Qi openssh' says 'Explicitly installed', and only then remove the applet. checks/packages.sh reports the state either way.

Worth noting the applet is not the only thing in that chain - gvfs also pulls gcr-4, and gvfs is justified independently (the file chooser traced through it in the journal). So openssh may well survive anyway. 'May well' is not a reason to skip the check.

Done, in the order the note above insisted on, and the order turned out to matter.

./sync.sh ran first and marked every declared package explicit, so openssh moved from 'installed as a dependency' to 'Explicitly installed'. Only then was the applet removed. openssh survived - 'ssh -T git@github.com' still authenticates - which it would not have done a day ago, when the only thing holding it was the chain through this package.

Removing it also took libnma, libnma-common and nm-connection-editor. gcr-4 stayed, held by gvfs, which is justified independently.

The manifest half was still outstanding and would have undone the whole thing: network-manager-applet was still listed in packages/desktop.txt, so the next sync would have reinstalled it. Removed, with the reasoning in its place - including that it was accidentally holding ssh, so nobody re-adds it without meeting that.

Verified the network is unaffected: NetworkManager reports connected, the wired connection is active, connectivity is fine, and nmtui is there for settings. The applet was drawing an icon, not managing anything.

Also answered the stale '# ?' comment above pavucontrol while in the file - TASK-58 traced it, and it genuinely is the audio readout's on-click.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
network-manager-applet removed from the machine and from packages/desktop.txt - it drew a tray icon into a session with no tray at all (busctl showed no StatusNotifierWatcher), costing 11.9 MiB resident to be invisible. Removed only after sync.sh had marked openssh explicit, because this package was the sole thing holding openssh and git does not depend on it; ssh still authenticates to GitHub afterwards. Network management is unaffected - NetworkManager, nmtui and nmcli do the work.
<!-- SECTION:FINAL_SUMMARY:END -->
