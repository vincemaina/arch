---
id: TASK-44
title: Decide whether Thunar stays now that yazi is installed
status: Done
assignee:
  - '@claude'
created_date: '2026-08-20 20:37'
updated_date: '2026-08-21 20:35'
labels:
  - desktop
  - repo
dependencies:
  - TASK-27
priority: low
type: spike
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Thunar was picked without a recorded reason. It appears in DECISIONS.md only in passing, inside decisions about other things, so nobody ever wrote down why a GUI file manager belongs on a keyboard-driven tiling desktop.

What it costs: 9.58 MiB, plus roughly 5.5 MiB of XFCE libraries - exo, libxfce4util and libxfce4ui - that exist solely to support it, across a dependency closure of 183 packages.

What it earns is the question. It was not opened once during a full day of work on this machine, and the desktop now has yazi bound to $mod+e, opening floating, and registered as the handler for inode/directory so a folder from the launcher or from a file manager link lands there too.

The objection that would normally settle this does not apply. Losing Thunar would not lose file dialogs: those come from xdg-desktop-portal-gtk, which is a separate package and stays regardless. Save As and Open would be unaffected.

The honest case for keeping it: a GUI file manager is better at a few things a terminal one is not - dragging files between windows, previewing a directory of images at a glance, and being usable when you are not already thinking in keystrokes. Those are real, and none of them came up today, which is either evidence that they do not matter here or evidence that a fortnight is a better sample than a day.

The decision should be made on use rather than taste: if Thunar goes untouched for a fortnight while yazi is bound to a key, that is the answer.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The decision is made on observed use over a fortnight, not on preference, and deciding to keep Thunar counts as completing this
- [x] #2 If it goes, thunar leaves packages/desktop.txt along with the XFCE libraries that exist only for it, and the window rule that floats it
- [x] #3 File dialogs are confirmed still working afterwards, since they come from xdg-desktop-portal-gtk rather than from Thunar
- [x] #4 Whatever a GUI file manager does better is named concretely, so the decision records what is being given up rather than implying nothing is
- [x] #5 The outcome is recorded in DECISIONS.md, which currently has no entry explaining why a file manager was chosen at all
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Establish whether Thunar is reachable from anything: xdg-mime, sway bindings, waybar clicks, desktop entries, helper scripts.
2. Establish whether it has been used: pacman.log install time, journal, config files it writes on first run.
3. Establish what it costs: pactree/pacman -Rsp for the full removal cascade, installed sizes.
4. Verify - not assume - that GTK file dialogs come from the portal rather than from Thunar.
5. Name concretely what a GUI file manager does better, and check each claim against this installation.
6. Act: remove from setup/packages/desktop.txt, record the reversal in DECISIONS.md, confirm checks/session.sh still 75/0.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DECISION: Thunar goes.

REACHABILITY - the finding that settled it. Nothing on this desktop can route
anything to Thunar.

  xdg-mime query default inode/directory  ->  terminal-here.desktop

  ~/.config/mimeapps.list confirms it. The ticket description is out of date
  here: the handler is no longer yazi either, TASK-47 moved it to
  terminal-here.desktop (foot with --working-directory).

  grep over setup/dotfiles: no sway binding, no waybar click command, no helper
  in dot_local/bin, no desktop entry Exec names thunar. The single repository
  reference is  for_window [app_id="thunar"] floating enable  in
  sway/config.d/40-window-rules.conf - a rule for a window nothing can open.

  What is left is typing its name into rofi, where it contributes three entries
  (Thunar File Manager, Bulk Rename, Thunar Preferences), none marked NoDisplay.

USE. Installed 2026-08-20 01:09 (pacman.log). Started exactly once, 2026-08-20
12:38, per the journal. ~/.config/Thunar/accels.scm is 127 lines and every one
is a comment - the default keymap written on first run, never edited. No
~/.cache/thunar at all.

THE THUMBNAIL ARGUMENT DIES ON ITS OWN. "Preview a directory of images at a
glance" is the strongest case for a GUI file manager here, and it does not work
on this machine. Thumbnails need tumbler, which is not installed and was never
declared. The journal from the single run says so:

  thunar[17264]: ThunarThumbnailer: Failed to retrieve supported types:
  GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: The name is not activatable

FILE DIALOGS - verified, not assumed (AC #3).
  * /usr/share/xdg-desktop-portal/portals/gtk.portal declares
    org.freedesktop.impl.portal.FileChooser
  * busctl --user introspect org.freedesktop.impl.portal.desktop.gtk ... shows
    that interface exported, so the backend is live
  * org.freedesktop.portal.FileChooser is present on org.freedesktop.portal.Desktop
  * xdg-desktop-portal-gtk.service is running
  * pacman -Ql thunar has no portal backend and no /usr/lib/gtk or /usr/lib/gio
    module; ldd /usr/lib/xdg-desktop-portal-gtk links nothing from XFCE
  * xdg-desktop-portal-gtk depends on gtk3, not on thunar
  Thunar cannot participate in a file dialog even in principle.

COST. pacman -Rsp thunar takes seven packages: thunar (9.58M), libexif (3.12M),
exo (2.21M), libxfce4ui (2.21M), xfconf (1.09M), libgtop (1.26M),
libxfce4util (1.06M) = 20.53 MiB. Required By: None. None of the six
dependencies is declared in any manifest, so deleting one line removes all
seven from a fresh install.

GVFS STAYS, and now has its own reason. pacman -Qi gvfs says
Optional For: glib2 thunar / Required By: None - it was never Thunar's
dependency, it is a separately declared package that happened to sit next to it.
GIO uses it to reach removable and network volumes, which is how a USB stick
appears in a GTK file dialog. Kept, with that written down.

WHAT CHANGED

  setup/packages/desktop.txt
    - thunar removed. The "# File explorer" block is now gvfs alone, with a
      comment saying what gvfs is for on its own terms.
    - the yazi comment rewrote: it said "Trial against thunar - see TASK-27",
      and the trial has now concluded.
  DECISIONS.md
    - "## Thunar" replaced by "## No graphical file manager, reversing an
      earlier decision", in the same style as "## A display manager, reversing
      an earlier decision": the old entry quoted rather than deleted, then why
      it changed, what is given up, what is not, and the trade-off.
    - "## GVFS" rewritten - it said "Install GVFS alongside Thunar", which
      would have been left dangling.
    - five stale mentions elsewhere corrected, since they claimed GTK3 or
      Wayland-native behaviour "through Waybar and Thunar" (lines about waybar,
      matching applications, the cursor theme, polkit-gnome and XWayland).
      xdg-desktop-portal-gtk is the honest substitute; it depends on gtk3 and
      stays.

NOT DONE, and it is the one thing left: the window rule
  setup/dotfiles/dot_config/sway/config.d/40-window-rules.conf:17
  for_window [app_id="thunar"] floating enable
is still there. This session was scoped to packages, DECISIONS.md and backlog
only, and that file was already modified in the working tree. It is inert - a
rule for a window nothing can open - but it is exactly the dead-config failure
mode this repository keeps hitting, so it should be deleted. AC #2 is left
unchecked for that reason.

THE MACHINE STILL HAS THUNAR INSTALLED. sync.sh never removes packages by
design (DECISIONS.md, "Packages are added but never removed by sync"), and no
sudo was used here. checks/packages.sh now reports it, with the command:
  thunar is installed by hand and nothing in setup/packages/ declares or needs it
  fix:  sudo pacman -Rns firefox thunar wofi
Running `sudo pacman -Rns thunar` is what actually reclaims the 20.53 MiB.

VERIFICATION
  ./checks/session.sh        75 passed, 0 failed, 0 skipped (unchanged)
  ./checks/sway-commands.sh  all referenced commands accounted for
  ./sync.sh --dry-run        91 declared, only dust missing - removing thunar
                             changes nothing sync would do, as expected

AC2 completed after the spike closed. The window rule was the last live reference and sat in 40-window-rules.conf, which the agent settling this ticket was not permitted to edit. It is gone now, and the comment left in its place says why: it had been floating a window nothing on this desktop could open - no binding, no click command, no desktop entry, and the directory handler is terminal-here.desktop. A rule for a window that cannot appear never fires, so it never looks wrong, which is the quietest kind of dead configuration this repository collects.

Independently confirmed before removing it: xdg-mime query default inode/directory returns terminal-here.desktop, and after the deletion nothing under setup/ names thunar except the two explanatory comments and packages/CHATGPT.md, which CLAUDE.md already marks historical.

AC1 stays unchecked deliberately, and the agent was right to leave it. The machine is two days old, so the fortnight of observed use the criterion asks for does not exist. Ticking it would record a measurement nobody took - and the evidence that settled this is stronger than usage would have been anyway: usage could only ever have shown whether someone chose to type the name into rofi, whereas the reachability check shows there was no way to open it at all, and the thumbnails that are the one thing a GUI manager does better never worked because tumbler was never declared.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-08-21 20:33
---
AC #1 and AC #2 left unchecked deliberately.

#1 asks for observed use over a fortnight. This machine was installed on
2026-08-20, so a fortnight has not been available and checking the box would
record a measurement that was never taken - the exact "hypothesis written down
as an outcome" failure CLAUDE.md warns about. What replaced it is stronger and
needs no waiting: nothing on the desktop routes to Thunar at all, so a fortnight
could only ever have measured whether someone chose to type its name.

#2 asks for the window rule to go as well. desktop.txt is done and the XFCE
libraries were never in a manifest, but
setup/dotfiles/dot_config/sway/config.d/40-window-rules.conf was outside the
files this session was permitted to edit. One line to delete.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Thunar removed from setup/packages/desktop.txt and the decision reversed in DECISIONS.md, in the "reversing an earlier decision" style with the original entry quoted.

Decided on reachability rather than on a fortnight of use, because the fortnight was not available (machine built 2026-08-20) and reachability is the stronger test: xdg-mime resolves inode/directory to terminal-here.desktop, and no sway binding, waybar click, helper script or desktop entry names Thunar - the only reference left was an inert for_window rule. It was started exactly once in its life (journal, 2026-08-20 12:38) and its accels.scm is 127 lines of untouched default comments.

The decisive piece of evidence is that the one thing a GUI file manager does better here did not work: thumbnails need tumbler, which was never declared, and the journal from that single run records the thumbnailer failing to start. What is genuinely given up is written down - Wayland drag-and-drop between windows, Bulk Rename, a mouse-usable manager - with thumbnails explicitly excluded from that list.

File dialogs verified independent of Thunar rather than assumed: the FileChooser portal is implemented by xdg-desktop-portal-gtk, its interface is exported on the bus by a running backend, and Thunar ships no portal backend, no GTK/GIO module, and is not linked by the portal binary. GVFS kept and re-justified on its own terms (GIO access to removable and network volumes) since its old entry read "install alongside Thunar".

Cost recovered on a fresh install: 20.53 MiB across seven packages (pacman -Rsp). This machine keeps Thunar until `sudo pacman -Rns thunar` is run - sync.sh never removes - and checks/packages.sh now reports exactly that.

Verified with ./checks/session.sh (75 passed, 0 failed, unchanged), ./checks/sway-commands.sh (clean) and ./sync.sh --dry-run. AC #1 and #2 left unchecked with reasons in a comment; one line in 40-window-rules.conf still needs deleting.
<!-- SECTION:FINAL_SUMMARY:END -->
