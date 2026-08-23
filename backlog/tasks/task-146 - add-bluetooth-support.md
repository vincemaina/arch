---
id: TASK-146
title: add bluetooth support
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-23 12:21'
updated_date: '2026-08-23 14:01'
labels: []
dependencies: []
priority: medium
type: feature
ordinal: 153000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
not every device running this system will have bluetooth.
so this is something the user should configure.
i.e. no point starting up the process (is it called blueman?) every time on a pc that doesn't have bluetooth
also if bluetooth is off, then we don't need the process to be running.
further more blueooth should be in the waybar if being used e.g. if connected to a device. actually better yet if the bluetooth process is running then it should show in the waybar. that way if you're not using it and you can see it in the waybar then you know you're using the process unnecessarily.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 bluez and bluez-utils are declared in setup/packages/desktop.txt, and nothing in the repository enables bluetooth.service - so a machine with no bluetooth runs no bluetooth process
- [ ] #2 Turning bluetooth on and off is one command, reachable from the launcher, that both starts/stops the daemon now and decides whether it starts at boot
- [ ] #3 The waybar module is entirely invisible when no controller is present - daemon stopped, or no bluetooth hardware - and visible whenever the daemon is running; both states verified by screenshot
- [ ] #4 Daemon running with nothing connected is visually distinct from connected, so a process running unnecessarily is noticeable
- [ ] #5 Clicking the module opens the bluetooth menu, and checks/session.sh, sway-commands.sh, packages.sh and manual.sh all pass
- [ ] #6 The manual, docs/software/README.md and DECISIONS.md record how to use it and why blueman was rejected
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Packages: declare bluez + bluez-utils in setup/packages/desktop.txt. NOT blueman - it draws a tray icon into a desktop with no tray, exactly what TASK-92 removed network-manager-applet for, and costs gtk3 + libnm + python-gobject. Record that pipewire-audio already depends on bluez-libs and ships every bluez5 codec, so audio needs nothing extra.
2. Opt-in is the SERVICE, not the package. bluetooth.service ships disabled; apply-config.sh must never enable it. A machine with no bluetooth pays ~5.5 MiB of disk and zero processes.
3. Helper ~/.local/bin/bluetooth: 'on' = systemctl enable --now (polkit prompts via the polkit-gnome agent), 'off' = disable --now, 'status', and no-arg = a rofi menu whose contents depend on state. Pairing a new device opens bluetoothctl in foot via sway-toggle-window - the same shape as network -> nmtui - rather than reimplementing an agent.
4. Waybar 'bluetooth' module in modules-right, after network. format-no-controller is the empty string, which hides the module entirely - verified live before writing anything. Icons as \uf293 / \uf294 Font Awesome escapes, both confirmed in the JetBrains Mono Nerd Font charset. Leave format-connected-battery out: it needs bluez Experimental=true and would otherwise be config that looks meaningful and does nothing.
5. Stylesheet: #bluetooth as a pill, @secondary at rest and when connected, @warning for .on (daemon up, nothing connected - the 'running unnecessarily' state the task is about), @muted for .off/.disabled. Verify the CSS class names live rather than trusting the man page.
6. Desktop entry bluetooth.desktop.tmpl with an absolute templated Exec, so it is reachable from rofi when the module is hidden.
7. checks/session.sh: assert the repository does not enable bluetooth.service anywhere, and that the module's on-click resolves. Break each on purpose before believing it passes.
8. Docs: manual chapter, docs/software/README.md, DECISIONS.md.
<!-- SECTION:PLAN:END -->
