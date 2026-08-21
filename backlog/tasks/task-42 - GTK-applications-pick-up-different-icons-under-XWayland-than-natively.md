---
id: TASK-42
title: GTK applications pick up different icons under XWayland than natively
status: Done
assignee: []
created_date: '2026-08-20 15:30'
updated_date: '2026-08-21 11:13'
labels:
  - desktop
  - feel
dependencies: []
priority: low
type: bug
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Found while measuring XWayland scaling for TASK-20, and separate from it. The same GTK application launched twice on the same output - once with GDK_BACKEND=wayland, once with GDK_BACKEND=x11 - rendered with different icons: a blue-grey checkmark where the native window had green, and triangle dropdown arrows where the native one had chevrons. Both windows were dark, so GTK_THEME is reaching X11 clients; the icon theme appears not to be.

settings.ini sets gtk-icon-theme-name=Papirus-Dark, and GTK_THEME=Adwaita:dark in environment.d forces the theme but says nothing about icons. The likely cause is that GTK resolves settings differently by backend - under Wayland through the xdg-desktop-portal settings interface, under X11 through XSETTINGS, with no XSettings daemon running here to answer - but that is a hypothesis formed from the symptom, not something confirmed. Confirming it needs python-gobject, or an equivalent way to ask a running GTK application which icon theme it actually resolved, rather than reading the configuration back and assuming.

How much this matters depends entirely on whether anything ever runs under XWayland, which today nothing does: qutebrowser, Thunar and pavucontrol all run natively, and XWayland was not even running until an application was deliberately forced onto it.

That changes the moment one of these is installed, and they are common enough to be worth naming:

Electron applications - VS Code, Discord, Slack, Obsidian, Signal - default to XWayland unless explicitly launched with Wayland flags, and are the most likely thing to arrive here first.

JetBrains IDEs, and Java desktop applications generally. Wayland support is still not the default in the JetBrains Runtime. Note that environment.d already carries _JAVA_AWT_WM_NONREPARENTING=1 for exactly this class of application, so the possibility was anticipated before this ticket.

Steam, and most games run through it or through Wine and Proton.

Zoom, Teams and similar conferencing clients.

GIMP 2.x, which is GTK2 and has no Wayland backend at all. GIMP 3 is GTK3 and does.

The severity is therefore conditional rather than low: it is zero until one of the above is installed, and immediately visible afterwards - an application that looks wrong next to everything else, in a setup whose whole point is that it does not. Worth fixing before that happens rather than diagnosing it while also trying to use the new application.

Worth checking at the same time whether an XSettings daemon is the right answer or whether it adds a daemon to work around something the portal should already handle, since DECISIONS.md is explicit that new tooling has to earn its place.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Whether GTK actually resolves a different icon theme under X11 is confirmed by asking a running application, not inferred from the rendered difference
- [ ] #2 The mechanism is identified - portal, XSETTINGS or something else - rather than worked around blind
- [ ] #3 A GTK application forced onto XWayland renders with the same icon theme as the same application running natively
- [ ] #4 Any daemon added to achieve this is justified against the DECISIONS.md standard that new tooling earns its place, or the decision not to add one is recorded
- [ ] #5 checks/session.sh or a note records how to reproduce the comparison, so this is not rediscovered from scratch
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Closed without a fix, deliberately.

The impact is zero rather than small. Nothing in this setup runs under
XWayland - every declared GUI application is a native Wayland client, and
Xwayland is not a running process on an idle machine. It starts on demand and
exits with the last X11 client. The difference was only ever seen by forcing an
application onto X11 to look for it.

When it does eventually bite it is cosmetic: checkmarks and dropdown arrows in
the wrong shape inside one application's dialogs. The theme itself reaches X11
clients correctly, because GTK_THEME is an environment variable.

The usual remedy is running xsettingsd, a daemon whose only job would be to tell
X11 clients which icon theme to use. Weighed against DECISIONS.md's standard
that new tooling earns its place, that is a poor trade for icon shapes - which
is AC #4, answered as "no daemon", with the reason recorded.

AC #1 is explicitly NOT met and should not be presented as though it were. The
hypothesis in this ticket - that GTK resolves settings through the portal under
Wayland and XSETTINGS under X11 - was never confirmed, and there is reason to
doubt it: ~/.config/gtk-3.0/settings.ini does set gtk-icon-theme-name=Papirus-Dark
and GTK reads that file on both backends, so the absence of an XSettings daemon
does not obviously explain the difference. Confirming it needs python-gobject,
which is not installed, to ask a running application what it actually resolved.

The valuable part of this ticket was never the fix, it was knowing which
applications drag in XWayland. That has been moved to where it will actually be
read: a comment beside xorg-xwayland in packages/desktop.txt, headed "READ THIS
BEFORE ADDING THE FIRST X11 APPLICATION", naming Electron, JetBrains, Steam,
Wine, Zoom and GIMP 2.x, describing the symptom, and pointing back here. Nobody
reads a closed ticket before installing VS Code; they do read the manifest they
are adding a line to.
<!-- SECTION:FINAL_SUMMARY:END -->
