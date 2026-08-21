---
id: TASK-46
title: 'Switchable system-wide themes, chosen from the launcher'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-20 21:35'
updated_date: '2026-08-21 03:14'
labels:
  - desktop
  - feel
  - dotfiles
dependencies:
  - TASK-14
priority: medium
type: feature
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
One palette drives the whole desktop already - .chezmoidata/palette.toml feeds sway, waybar, foot, swaylock, rofi, mako and starship through templates. Changing a colour means editing one file and running sync.sh. What does not exist is more than one palette, or any way to move between them without editing the repository.

The want is several named themes, applied everywhere at once, picked from the launcher like anything else.

The mechanism is the interesting part, because the current design renders at apply time rather than reading colours at runtime. Nothing consuming the palette can be re-themed by setting a variable; every consumer holds a rendered copy. So switching means re-rendering and then persuading each consumer to reload, and they do not all reload the same way:

sway reloads with swaymsg reload. mako has makoctl reload. waybar has no reload - its unit has to be restarted. foot rereads nothing: existing windows keep their colours and only new terminals pick up the change, which is already documented in sync.sh hints. rofi and swaylock read their config on each launch, so they need nothing. GTK applications follow settings.ini and GTK_THEME, which is a separate mechanism again and does not come from the palette at all.

Two shapes worth weighing.

A palette per theme, selected by chezmoi data. Several files, and the active one chosen by a value chezmoi reads, so `chezmoi apply` renders whichever is current. Fits the existing design exactly and keeps everything declarative. The cost is that switching is a chezmoi apply plus a set of reloads, which is not instant.

A theme script that rewrites palette.toml and drives the reloads. Cruder, and it makes the repository state depend on which theme was last chosen, which is the sort of thing that produces a confusing diff later.

Either way the launcher entry is the easy half: a desktop entry per theme, or one entry that opens a rofi list of them, in the same way Notifications and Find Files now work.

Worth deciding at the same time: whether the sixteen ANSI terminal colours travel with the theme or stay fixed, whether the wallpaper is part of a theme, and whether GTK - which currently gets Adwaita:dark regardless - should follow or be left alone. A theme that changes the bar and the terminal but leaves every dialog the same colour would be worse than not having themes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 More than one named palette exists, and switching between them changes sway, waybar, foot, rofi, mako, swaylock and the prompt together rather than some of them
- [ ] #2 A theme is chosen from the launcher, not by editing the repository
- [ ] #3 Each consumer is actually reloaded rather than assumed to reload, with the ones that cannot - foot keeps existing windows, waybar needs a restart - stated rather than silently inconsistent
- [ ] #4 Whether GTK follows the theme is decided; a theme that changes the bar but leaves every dialog unchanged is worse than no themes
- [ ] #5 Whether the ANSI terminal colours and the wallpaper belong to a theme is decided rather than left implicit
- [ ] #6 Switching a theme does not leave the repository holding uncommitted changes that make the next diff confusing
- [ ] #7 The approach is recorded in DECISIONS.md, since it changes what palette.toml means from "the colours" to "the current colours"
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Decisions taken with the user before starting (they settle AC #4 and #5):
  * A theme covers desktop chrome only. GTK dialogs stay Adwaita:dark, which
    constrains every theme to being a dark theme - written down rather than
    left as an accident.
  * The sixteen ANSI terminal colours travel with the theme.
  * The wallpaper travels with the theme.
  * Ship the current palette plus two contrasting ones, so the mechanism is
    actually exercised and a consumer that quietly did not follow is visible.

1. Restructure the data. .chezmoidata/palette.toml becomes themes.toml with a
   [themes.<name>] table per theme, each carrying the role colours, its [term]
   block and its wallpaper. The current palette becomes themes.neon unchanged,
   so nothing shifts colour in this step.

2. Point the seven consuming templates at the selected theme. Each gains one
   line - {{- $palette := index .themes (dig \"theme\" \"neon\" .) -}} - and
   .palette.x becomes \$palette.x. dig gives a default, which matters because
   the installer chroot has no chezmoi config file. Verified: with no config
   the default applies, a config [data] theme overrides it, and an unknown name
   fails loudly at render rather than silently.

3. Record the active theme machine-locally in ~/.config/chezmoi/chezmoi.toml
   under [data]. Deliberately not in the repository, so switching leaves no
   diff (AC #6). This is the same slot TASK-14 wants for a machine profile, so
   it establishes that rather than competing with it.

4. Write the switcher: ~/.local/bin/theme. With no argument it offers the
   themes through rofi; with one it validates the name against the themes
   table, rewrites the chezmoi config, applies, and reloads. A .desktop entry
   puts it in the launcher (AC #2), with the absolute path that
   notification-centre needed - ~/.local/bin is not on the session PATH.

5. Do the reloads in a run_onchange_ script rather than only in the switcher,
   so sync.sh gets them too. Verified reload paths: swaymsg reload (which also
   restarts swaybg, so the wallpaper follows), makoctl reload, a waybar unit
   restart, nothing for rofi or swaylock, and foot keeps its existing windows -
   foot's SIGUSR1 is a dark/light section toggle, not a config reload, so it
   cannot help. Guarded on SWAYSOCK, because chezmoi runs these scripts even
   when rendering to a scratch destination.

6. Add the two new palettes and their wallpapers. Rebuild the wallpaper
   generator - it was never tracked - as tools/wallpaper.py, deriving the image
   from a theme's own colours. Offline tool, outputs committed, so the built
   machine gains no dependency.

7. Cover it in checks/session.sh: the active theme resolves, every theme names
   a wallpaper that exists, and every theme defines every key the templates
   read.

8. Record the approach in DECISIONS.md (AC #7), including what palette.toml
   meant before and why the GTK boundary is where it is.
<!-- SECTION:PLAN:END -->
