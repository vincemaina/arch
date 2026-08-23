---
id: TASK-146
title: add bluetooth support
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 12:21'
updated_date: '2026-08-23 15:15'
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
- [x] #1 bluez and bluez-utils are declared in setup/packages/desktop.txt, and nothing in the repository enables bluetooth.service - so a machine with no bluetooth runs no bluetooth process
- [x] #2 Turning bluetooth on and off is one command, reachable from the launcher, that both starts/stops the daemon now and decides whether it starts at boot
- [x] #3 The waybar module is entirely invisible when no controller is present - daemon stopped, or no bluetooth hardware - and visible whenever the daemon is running; both states verified by screenshot
- [x] #4 Daemon running with nothing connected is visually distinct from connected, so a process running unnecessarily is noticeable
- [x] #5 Clicking the module opens the bluetooth menu, and checks/session.sh, sway-commands.sh, packages.sh and manual.sh all pass
- [x] #6 The manual, docs/software/README.md and DECISIONS.md record how to use it and why blueman was rejected
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented on branch worktree-task-146-bluetooth (commit ebfa5d8).

WHAT WAS BUILT
- setup/packages/desktop.txt: bluez + bluez-utils, with the reasoning that installing a package and enabling a service are two decisions, not one.
- setup/dotfiles/dot_local/bin/executable_bluetooth: on/off/status/--current, plus a rofi menu. enable --now / disable --now via polkit, not sudo, because it is launched from a menu where a terminal sudo prompt would hang.
- Waybar bluetooth module with format-no-controller set to the empty string, plus #bluetooth styling: secondary when connected, warning when the daemon is up with nothing connected, muted when powered off or rfkilled.
- bluetooth-tui window rule, and a launcher entry - the only way back to the switch when the module is hidden.
- checks/session.sh: a Bluetooth section asserting nothing in setup/ enables the service and that format-no-controller stays empty.
- Manual ch2 (a Bluetooth section and a bar-table row) and ch5, docs/software/README.md, DECISIONS.md.

VERIFIED
- Module hidden with no controller: proven live before any of this was written, with a throwaway waybar on a headless output. waybar logged 'no bluetooth controller found' and the module was absent entirely - no empty pill.
- Rendered config parses as JSON; the icons decode to U+F293 / U+F294, both confirmed inside JetBrains Mono Nerd Font's f000-f385 range. My literal escape sequences were twice silently converted to the raw character en route to disk, so they are now written by building the escape from parts and asserting afterwards that no raw private-use character was introduced.
- Both new check assertions were broken on purpose and watched go red. That caught a real bug: the bluez-declared check was matching the MANIFEST COMMENT about bluez rather than the declaration, and passed with the packages deleted. Now anchored to a whole line.
- The pairing window's app_id is written out literally at both sites, not held in a variable, because checks/session.sh enforces the toggle/--app-id/for_window agreement by reading the file as text and a variable is invisible to it.
- session.sh 95 passed / 0 failed; sway-bindings clean; manual.sh 8/8.

NOT YET VERIFIED - needs the packages installed
bluez is not on this machine and sudo needs a password, so the states where the module is VISIBLE (on, and connected) have not been seen. That is the half that cannot be proven by reasoning: whether waybar's bluetooth module notices a controller appearing at runtime, and whether the CSS class names .on/.off/.connected are what waybar actually sets. checks/sway-commands.sh and packages.sh each fail on exactly this, and only this.

Also unmeasured: bluetoothd's resident cost, recorded as a named gap in docs/software/README.md rather than left silent.

VERIFICATION ON REAL HARDWARE (2026-08-23)

bluez was installed via pkexec mid-task, which turned the two unverifiable claims into measured ones and found two bugs reasoning had missed.

- bluez ships the service DISABLED: 'systemctl is-enabled bluetooth.service' returned 'disabled' and 'inactive' immediately after install, before anything touched it. That is the premise the whole design rests on and it is now observed rather than assumed.
- Module absent -> present -> absent, all three with the REAL rendered config and stylesheet on a throwaway waybar pinned to a headless output, with the bar running throughout. So waybar notices a controller appearing AND disappearing at runtime; the module does not merely start correct. Screenshots in the job tmp dir.
- 'bluetooth on' worked end to end through polkit (symlinks created, daemon started), 'bluetooth off' reversed it exactly. The helper's status line was correct in every state.
- The .on state renders in the warning amber, plainly distinct from the muted-grey network module beside it and the blue cpu module after it. Glyph U+F293 renders as a real icon, not tofu.
- The menu renders correctly under the theme, prompt and rows as intended.

TWO BUGS FOUND BY VERIFYING, BOTH SILENT
1. The menu passed -mesg and it never displayed. The rofi theme sets window children to [inputbar, listview, textbox-footer] and 'message' is not among them, so rofi accepts the option, styles the element, and places it nowhere. Removed; written up in the scripting-traps skill.
2. Earlier, the 'bluez is declared' check passed with the packages deleted, because it matched the manifest COMMENT about bluez. Anchored to a whole line. Found only by breaking it deliberately.

Also worth recording: my literal \u escape sequences were converted to raw private-use characters twice on the way to disk. The config's icons are now written by composing the escape from parts, with an assertion afterwards that no raw private-use character was introduced by the edit.

AC 4 IS NOT CHECKED, DELIBERATELY
The 'daemon running, nothing connected' state is verified. The CONNECTED state is not: no bluetooth device was available to pair, so nothing has ever exercised format-connected or the .connected class. Both are documented in waybar 0.15.0's own man page and the CSS parsed without error (waybar would have died otherwise), so the risk is cosmetic - a connected device showing in the default colour rather than secondary. It needs one real device and about a minute to close.

Machine left with bluetooth OFF (disabled and stopped), which is the state it was in before this task.

AC 4 closed 2026-08-23 after the merge. A real speaker (DM-40BT) was paired, trusted and connected; it arrived in PipeWire as the default sink, confirming that bluetooth audio needs no extra packages because pipewire-audio already carries the bluez5 plugin and codecs. The connected state renders as the glyph plus the device alias in @secondary magenta, plainly distinct from the @warning amber of the idle .on state and the @info blue of cpu beside it. Every state the module can display has now been observed.

The change was then applied to the live machine with chezmoi apply and waybar restarted: checks/session.sh went from 95/0/1 to 98 passed, 0 failed, 0 skipped, the previously skipped assertion being the one that needed the module present in the rendered config.

Two pairing lessons, neither changing the code: bluez expires unpaired devices seconds after discovery stops, so pairing must happen while a scan is running and after the device has been seen in it - otherwise it fails with 'Device not available', which reads like a rejected pairing and is not one. And bluetoothctl reads stdin, so inside a 'while read' loop it eats the loop's input and the loop stops after one iteration; every call needs </dev/null. Both are reasons the helper hands pairing to an interactive bluetoothctl rather than scripting it.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Bluetooth is now declared on every machine and enabled on none, with the bar module acting as the indicator that the daemon is running at all.

The insight the implementation turned on is that installing a package and enabling a service are two separate decisions wearing one name. bluez and bluez-utils go in desktop.txt unconditionally - 5.41 MiB of disk, zero processes, because bluez ships bluetooth.service disabled - and the daemon is opted into per machine with 'bluetooth on'. That keeps the manifest machine-independent, which is what makes builds reproducible, while the thing that actually costs something stays off until asked for. checks/session.sh fails if anything under setup/ ever enables the service, because 'enable the service you just installed' is exactly the tidy-up a later reader would make and it would work silently on every machine ever built.

The bar module's format-no-controller is the empty string, so with the daemon stopped there is no controller on the bus and waybar hides the module outright. A visible module therefore MEANS a running daemon - which inverts the usual relationship: you are not checking whether bluetooth is on, you are being told, on the machine where you forgot. Running with nothing connected takes the warning colour, since an idle radio is the state the whole arrangement exists to make noticeable.

~/.local/bin/bluetooth is the switch, the status line and the menu; pairing hands off to bluetoothctl in a floating terminal rather than half-reimplementing an agent. A launcher entry exists because when bluetooth is off there is nothing on the bar to click. blueman was rejected for the reason TASK-92 removed network-manager-applet: it is a tray application and this desktop has no tray.

VERIFIED, not asserted: bluez installed mid-task on real hardware, service confirmed disabled out of the package; the module observed absent, then present, then absent again on a live bar with the real rendered config while waybar ran throughout, so both runtime transitions are proven; 'bluetooth on'/'off' driven end to end through polkit. Both new check assertions were broken on purpose and watched go red - which caught one of them silently matching a manifest comment instead of the declaration. Verifying also caught the menu's -mesg rendering nothing, because the rofi theme never places the 'message' widget; that is now removed and recorded in the scripting-traps skill.

checks: session.sh 95/0, packages.sh 6/0, sway-commands.sh clean, sway-bindings.sh clean, manual.sh 8/8.

One acceptance criterion is deliberately unchecked: the CONNECTED state has never been rendered, because no device was available to pair. Risk is cosmetic and it needs one real device to close.
<!-- SECTION:FINAL_SUMMARY:END -->
