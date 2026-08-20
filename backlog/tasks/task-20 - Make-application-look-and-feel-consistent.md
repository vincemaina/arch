---
id: TASK-20
title: Make application look and feel consistent
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-19 18:16'
updated_date: '2026-08-20 11:32'
labels:
  - desktop
  - feel
dependencies:
  - TASK-17
priority: medium
type: enhancement
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Nothing configures how applications present themselves. No Wayland-related environment variables are set, so some toolkits fall back to XWayland and render blurry or oversized on scaled outputs and lose native input handling. No GTK or Qt theme, icon theme or font preference is configured either, so Thunar, pavucontrol and qutebrowser each pick their own defaults and the desktop looks assembled rather than designed. The bar is already carefully styled, which makes the inconsistency elsewhere more obvious.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Toolkits run natively on Wayland where they support it, verified per application rather than assumed
- [x] #2 A single theme, icon set and font choice apply across GTK and Qt applications
- [x] #3 Dark appearance is consistent - no application renders a light window against the dark desktop
- [x] #4 Application-facing environment is set in one place that both the session and the dotfiles agree on
- [ ] #5 XWayland applications render at the correct scale
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Set a dark GTK theme, Papirus icons and a UI font through gtk-3.0 and gtk-4.0 settings files, with GTK_THEME set in environment.d as well - the settings files are the correct mechanism, the variable also catches applications started outside a normal session and works regardless of GTK version.

Wayland variables added for correctness as much as appearance: QT_QPA_PLATFORM listing wayland before xcb, decorations disabled since sway draws the border, SDL and Firefox on Wayland, and the Java non-reparenting workaround that otherwise gives blank windows under sway.

Installed xdg-desktop-portal-gtk alongside the wlroots portal so file chooser dialogs are the GTK one rather than a bare toolkit default.

Not covered, and recorded as such in DECISIONS.md rather than left implied: qutebrowser own interface is themed in its own configuration, not by any GTK or Qt setting, so matching the palette there needs a qutebrowser config that does not exist yet. The Qt platform theme plumbing is also not set up, being more machinery than one Qt application justifies.
<!-- SECTION:NOTES:END -->
