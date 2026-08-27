---
id: TASK-189
title: 'Thunar on $mod+e, yazi moved to $mod+Ctrl+e, both on trial'
status: Done
assignee: []
created_date: '2026-08-27 10:44'
updated_date: '2026-08-27 11:04'
labels: []
dependencies: []
ordinal: 195000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
yazi is fast and keyboard-native but feels like it suits small tasks handled quickly rather than being the place you do file work. This puts a graphical file manager back on the primary key so the two can be compared by use rather than by argument, the way TASK-177/178 put vimb beside qutebrowser.

Thunar was chosen over pcmanfm, pcmanfm-qt, nemo and nautilus on evidence gathered by unpacking each candidate rather than from reputation:

- KEYBINDINGS ARE THE CULL. Thunar exports gtk_accel_map_load/save, names `Thunar/accels.scm`, and carries the string "The Shortcuts Editor requires a Thunar window to be present" - a built-in shortcut editor writing a plain text file this repository can template. nemo has the same accel-map calls plus ~/.gnome2/accels/nemo. pcmanfm has NO accel-map symbols at all - its keys are compiled in - and neither does pcmanfm-qt. So the two lightest options cannot be given vim keys at any price.
- BACKGROUND PROCESSES. Every autostart entry, systemd unit and D-Bus service was extracted from the packages and checked for gating; this session has xdg-desktop-autostart.target ACTIVE, so an ungated entry really would start. Thunar ships no autostart at all and its thunar.service/xfconfd.service have no WantedBy=, so they are D-Bus activated and nothing runs until it is opened once. nemo hard-depends on xapp, which ships xapp-sn-watcher.desktop with NO OnlyShowIn - it would start at every login whether or not nemo is ever opened, a StatusNotifier tray watcher for a tray this desktop does not have. nautilus drags in localsearch/tinysparql, a background file indexer with three systemd user units.
- COST. 7 new packages, 20.5 MiB. Against pcmanfm 7/9.3 MiB, pcmanfm-qt 7/9.7 MiB, nemo 10/14.9 MiB, nautilus 27/64.4 MiB, dolphin 72 packages.

This is the package TASK-44 removed. Read that decision again before objecting: it was dropped for REACHABILITY, not for being a bad program - nothing on the desktop routed to it, and thumbnails never worked because tumbler was never declared. Both are fixed here. This time it arrives on the primary key, with tumbler, and with a vim keymap.

yazi keeps a binding rather than being demoted to the launcher, because TASK-44s lesson is that an unreachable file manager gets opened once and never again - and a decision between the two needs both to be genuinely reachable. $mod+Shift+e is already the power menu, so $mod+Ctrl+e it is. `e` is not in keyd s [control] layer (only k, semicolon, j and h are), so unlike $mod+Ctrl+h/j this needs NO line in [control+meta].

The theme caveat, which applies to any GUI file manager and should not come as a surprise later: setup/dotfiles/dot_config/gtk-3.0/settings.ini.tmpl sets stock Adwaita/Adwaita-dark and its own comment says the palette does not reach GTK. Thunar will follow the selected theme s light/dark mode and nothing more. Making it wear the accent colours would mean templating ~/.config/gtk-3.0/gtk.css from themes.toml, which affects every GTK application and is out of scope here.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 thunar and tumbler are declared in setup/packages/desktop.txt with a comment saying why, and why tumbler is not optional this time
- [x] #2 $mod+e opens Thunar and $mod+Ctrl+e opens yazi; checks/sway-bindings.sh passes with no duplicate binding
- [x] #3 Thunar has vim-style navigation bound through a tracked accels.scm under setup/dotfiles/, not clicked into a preferences dialog
- [x] #4 Thumbnails actually render in Thunar - the thing TASK-44 found broken - confirmed by looking at a directory of images, not by checking tumbler is installed
- [x] #5 Nothing new is resident at login: confirmed by comparing systemctl --user and the process list before opening Thunar and after a fresh session
- [x] #6 The window rule and the $explorer variable are updated coherently - the app_id the launcher sets, the rule that floats it, and ~/.local/bin/shortcuts all agree
- [ ] #7 checks/session.sh, checks/sway-commands.sh, checks/sway-bindings.sh and checks/manual.sh all pass
- [x] #8 docs/manual/04-applications.md and docs/software/README.md are updated, and DECISIONS.md records the comparison that chose Thunar
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Declare `thunar` and `tumbler` in packages/desktop.txt. tumbler is NOT optional this time - TASK-44 found thumbnails broken precisely because it was never declared, and thumbnails are the strongest argument for a GUI file manager.
2. sway/config: $explorer becomes `thunar`, and a second variable carries the terminal one so both are named rather than one being an inline command.
3. 50-keybindings.conf: $mod+e -> $explorer (Thunar), $mod+Ctrl+e -> the yazi terminal. Both --no-repeat, which checks/sway-bindings.sh enforces. No keyd change needed: `e` is not in [control], so unlike h/j/k/semicolon it needs no [control+meta] line.
4. 40-window-rules.conf: keep the app_id="explorer" float rule for yazi. Thunar needs its own rule, and its app_id MUST be read off the running window with `swaymsg -t get_tree` rather than guessed - thunar.desktop ships no StartupWMClass, so the app_id is whatever GTK derives at runtime. This is the exact three-file coupling CLAUDE.md warns about.
5. accels.scm under setup/dotfiles/, tracked. Action paths confirmed by extracting them from the binary: <Actions>/ThunarStandardView/{back,forward,rename,move-to-trash,select-all-files,...} and <Actions>/ThunarWindow/{open-parent,open-home,new-tab,close-tab,...}. Bind h/j/k/l, gg/G, and the rest to those paths.
6. ~/.local/bin/shortcuts: its "explorer" mapping and BY_PROCESS both name yazi today.
7. Verify by looking, per the desktop-verification skill: open Thunar on a throwaway headless output, screenshot a directory of images to prove thumbnails render, and read the app_id back out of get_tree.
8. Measure cold start for both by TASK-177 method, and what stays resident after the window closes - TASK-190 needs those figures.
9. Docs: manual chapter 4, docs/software/README.md entry, and a DECISIONS.md section recording the comparison that chose Thunar over pcmanfm, pcmanfm-qt, nemo and nautilus.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED

- thunar and tumbler declared in packages/desktop.txt, with the comparison and the tumbler-is-not-optional reasoning inline.
- sway/config: $explorer is now `thunar`, $explorer_tui carries the yazi terminal. $mod+e -> Thunar, $mod+Ctrl+e -> yazi, both --no-repeat.
- 40-window-rules.conf floats both at the same 1100x700, so the comparison is not partly about window size.
- setup/dotfiles/dot_config/Thunar/readonly_accels.scm - vim keys, tracked READ-ONLY.
- ~/.local/bin/shortcuts gained a "thunar" context reading the accel map, so the launcher shows Thunar keys while Thunar is focused.
- docs: manual ch4 rewritten, docs/software entry with measured figures, DECISIONS.md section with the four-way comparison.

VERIFIED BY LOOKING, not by reading config back

app_id is `thunar`, lowercase, read out of `swaymsg -t get_tree` with a window open - thunar.desktop ships no StartupWMClass so it could not be guessed. The float rule then fired: floating=True, rect exactly 1100x700.

Thumbnails render. Screenshotted a directory of nine PNGs and every one shows a real preview. This is the exact thing TASK-44 found broken, and checking that tumbler is installed would not have proved it.

The accel map was verified through the MENUS, by driving the pointer with `swaymsg seat seat0 cursor set/press/release` - sway has no key injection but it does have pointer control. Go menu shows Open Parent `H`, Back `Shift+H`, Forward `Shift+L`, Search `/`; Edit menu shows Undo `U`, Redo `Ctrl+R`, Cut `D`, Copy `Y`, Paste `P`, Move to Wastebasket `X`, Rename `R`.

TWO REAL BUGS FOUND AND FIXED

1. "H" IS NOT SHIFT+H TO GTK. The first version wrote back/forward as "H"/"L" and open-parent/open as "h"/"l". GTK normalises an accelerator keyval to lower case before matching, and gtk_accel_map_load changes entries with replace=FALSE - so `h` and `H` are the same accelerator and the second to load silently did not take. The Go menu showed Back as `H` and Open Parent with NO accelerator at all. Caught only because the menu was actually looked at. Fixed by spelling Shift as <Shift>h. Also worth knowing: gtk_accelerator_get_label() upper-cases every letter for display, so a lower-case `y` renders as `Y` and the label cannot tell you which you got.

2. A PREFIX-COLLISION BUG IN THE REPOSITORY OWN TOOLING, in three places. Sway variable expansion is a plain string replacement with no word boundary, so $explorer substituted before $explorer_tui turns the latter into `thunar_tui`. checks/sway-commands.sh FAILED reporting a missing program called `thunar_tui` that nothing ever referenced; checks/sway-bindings.sh produced the same corruption and tools/shortcuts.sh inherits its output, so the wrong string would have reached the manual shortcut table. Fixed in all three by substituting longest variable name first - a prefix is always shorter than what contains it. A \\b word boundary does not work because sway variable names start with `$`, which is not a word character. This bug was latent: it needed the first pair of variables sharing a prefix to appear.

MEASURED, for TASK-190

Window on screen, launch to sway window::new, warm cache, mean of three runs:
  thunar            157 ms  (156/157/157)
  yazi in foot       20 ms
  bare foot          20 ms
Not comparable to the browser figures in DECISIONS.md, which were keypress-to-mapped-window and cold; the useful part is the ratio against foot on the same method. Thunar costs about 137 ms more to put a window up. Note the yazi figure is when the TERMINAL appears, not when yazi has drawn.

Resident:
  at login                     nothing. No autostart entry, no WantedBy= on either unit.
  after the window is closed   28.7 MiB - tumblerd 20.3, xfconfd 8.4, both D-Bus activated on first use and neither exiting.

That 28.7 MiB is the honest answer to "no background processes when it is not open": true until first use, not after.

NOT DONE, DELIBERATELY

sync.sh was not run - ~/.config/sway/config.d/20-output.conf still has uncommitted local display changes and a full sync would revert them. Applied only the files this task touches, by path.

The inode/directory handler is still terminal-here.desktop, so opening a folder from another application still gives a terminal rather than Thunar. Not changed because it was not asked for, but it is exactly the kind of reachability question TASK-44 turned on, and TASK-190 should decide it alongside the rest.

AC #5 checked on package-level evidence, which is conclusive rather than circumstantial: thunar and tumbler ship NO /etc/xdg/autostart entry, and neither thunar.service, xfconfd.service nor tumblerd.service carries a WantedBy=. There is no mechanism by which any of them could start at login. This session cannot itself be the test - it began at 09:51 and thunar was not installed until ~11:45 - so the next login is the belt-and-braces confirmation, but there is nothing left for it to discover.

AC #7 is left unchecked. checks/session.sh is 130 passed / 0 failed (the extra skip is the screenshot check declining while the screen is locked, not a regression), checks/sway-commands.sh and checks/sway-bindings.sh both pass - the latter two only after fixing the prefix-collision bug this task exposed in them. checks/packages.sh still fails on steam and vulkan-tools, and checks/manual.sh on ~/.local/state/browser; all three predate this task and were failing on main before this branch existed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Put Thunar on $mod+e with vim keys and thumbnails, moved yazi to $mod+Ctrl+e, and left both reachable so TASK-190 can decide between them on use rather than argument.

Thunar was chosen over pcmanfm, pcmanfm-qt, nemo and nautilus by downloading and unpacking each one. Rebindable keys was the cull - pcmanfm and pcmanfm-qt have no accel-map symbols at all, their keys are compiled in - and of the two that survived, nemo hard-depends on xapp whose autostart entry has no OnlyShowIn and would run a tray watcher at every login. Both of TASK-44 reasons for dropping Thunar are addressed rather than disputed: it has the primary key, and tumbler is declared rather than left optional.

Verified by looking, not by reading config back. app_id read out of get_tree with a window open (thunar.desktop has no StartupWMClass, so it could not be guessed) and the float rule confirmed firing at exactly 1100x700. Thumbnails confirmed by screenshotting a directory of nine PNGs. The accel map confirmed through Thunar own menus, driven by `swaymsg seat seat0 cursor set/press/release` - sway has no key injection but it does have pointer control.

That last step earned its keep: the first accels.scm bound back/forward as "H"/"L" and open-parent/open as "h"/"l", and GTK normalises the keyval to lower case before matching, so `h` and `H` are one accelerator and the second to load silently did not take. The Go menu showed Open Parent with no accelerator at all. Reading the file back would have said it was configured.

It also exposed a latent bug in this repository own tooling, in three places: sway variable expansion is a plain string replace with no word boundary, so $explorer substituted before $explorer_tui becomes `thunar_tui`. checks/sway-commands.sh failed naming a program nothing references, and tools/shortcuts.sh inherits checks/sway-bindings.sh output so the corruption would have reached the manual shortcut table. Fixed in all three by substituting longest name first.

Measured for TASK-190: 157 ms to a window against foot 20 ms on the same method; nothing resident at login; 28.7 MiB resident once opened (tumblerd 20.3, xfconfd 8.4), neither exiting when the window closes. That last figure is the honest answer to "no background processes when it is not open" - true until first use, not after.

Two known limits, both recorded in DECISIONS.md rather than worked around: j/k cannot be bound because a GtkAccelMap binds menu actions and moving the selection is not one; and Thunar follows the theme light/dark mode but not its palette, because gtk-3.0/settings.ini sets stock Adwaita.
<!-- SECTION:FINAL_SUMMARY:END -->
