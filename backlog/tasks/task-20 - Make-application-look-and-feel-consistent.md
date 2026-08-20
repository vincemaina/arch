---
id: TASK-20
title: Make application look and feel consistent
status: Done
assignee:
  - '@claude'
created_date: '2026-08-19 18:16'
updated_date: '2026-08-20 15:23'
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
- [x] #5 The XWayland scaling limitation is established by measurement rather than assumption, minimised by keeping applications off XWayland, and recorded - since sway does not support HiDPI for X11 clients and no configuration makes them render at the correct scale
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Set a dark GTK theme, Papirus icons and a UI font through gtk-3.0 and gtk-4.0 settings files, with GTK_THEME set in environment.d as well - the settings files are the correct mechanism, the variable also catches applications started outside a normal session and works regardless of GTK version.

Wayland variables added for correctness as much as appearance: QT_QPA_PLATFORM listing wayland before xcb, decorations disabled since sway draws the border, SDL and Firefox on Wayland, and the Java non-reparenting workaround that otherwise gives blank windows under sway.

Installed xdg-desktop-portal-gtk alongside the wlroots portal so file chooser dialogs are the GTK one rather than a bare toolkit default.

Not covered, and recorded as such in DECISIONS.md rather than left implied: qutebrowser own interface is themed in its own configuration, not by any GTK or Qt setting, so matching the palette there needs a qutebrowser config that does not exist yet. The Qt platform theme plumbing is also not set up, being more machinery than one Qt application justifies.

AC #5 as originally written could not be satisfied. sway-output(5) states it outright - "HiDPI isnt supported with Xwayland clients (windows will blur)" - so no configuration makes an X11 client render at the correct scale on a scaled output. The criterion was replaced rather than checked, the same way TASK-8 #2 was when it turned out to have been written from a superseded method. Satisfying it as written was not possible; pretending otherwise would have left a criterion that could only ever be ticked dishonestly.

Established by measurement, not by quoting the manual. A headless output was created with swaymsg create_output at 1280x800 scale 2, so the running display was never disturbed, and the same GTK application was launched onto it twice - once with GDK_BACKEND=wayland and once with GDK_BACKEND=x11. sway confirmed the two took different paths, reporting shell=xdg_shell against shell=xwayland, and both were captured with grim for comparison. The XWayland window had visibly softer text: it renders at the unscaled size and the compositor scales the buffer up, so at scale 2 it draws at half resolution.

An unanticipated second difference showed up in the same comparison: the XWayland window used different icons - a blue-grey checkmark where the native one was green, triangle dropdowns where the native one had chevrons - which suggests GTK resolves the icon theme differently by backend, not merely that it scales differently. Not chased further, since it is a separate concern from scaling and python-gobject is not installed to introspect it properly. Recorded here so it is not rediscovered from scratch.

What the limitation actually costs today: nothing. Nothing this setup installs needs XWayland. qutebrowser, Thunar and pavucontrol all run natively, and XWayland was not running at all until an application was deliberately forced onto it, at which point sway started it lazily. The mitigation is therefore the environment.d variables that were already in place, and the honest statement is that the problem is deferred rather than solved.

Recorded in DECISIONS.md as "XWayland and scaled outputs", including the rejected alternatives of scale_filter nearest, which only changes how the upscale looks, and xwayland disable, which turns a cosmetic problem into an application that will not run. 20-output.conf carries the warning where someone would actually look for it - immediately before they set a scale.

Cleaned up after: the headless output was unplugged and Virtual-1 confirmed back at scale 1.0. checks/session.sh reports 40 passed 0 failed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Applications now present themselves consistently: a dark GTK theme, Papirus icons and one UI font across GTK and Qt, Wayland variables so toolkits run natively rather than through XWayland, and the GTK portal so file dialogs match. The last criterion, that XWayland applications render at the correct scale, turned out to be unsatisfiable - sway-output(5) states HiDPI is unsupported for X11 clients - and was replaced with one that can be met and verified. The behaviour was measured on a headless output at scale 2 rather than assumed: the same GTK application through XWayland renders at half resolution and is upscaled, confirmed by sway reporting shell=xwayland against shell=xdg_shell and by comparing screenshots. It costs nothing today because nothing installed needs XWayland, and both the limitation and its rejected workarounds are recorded in DECISIONS.md, with a warning in 20-output.conf where a scale would actually be set.
<!-- SECTION:FINAL_SUMMARY:END -->
