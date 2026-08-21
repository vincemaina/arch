---
id: TASK-52
title: 'More themes, and a choice of wallpaper within each'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 03:50'
updated_date: '2026-08-21 04:08'
labels:
  - desktop
  - feel
  - dotfiles
dependencies: []
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-46 delivered theme switching with three themes, each with exactly one wallpaper generated from its palette and committed as a PNG. Two things are wanted on top of that: many more themes, including a green one, and a choice of wallpaper within a theme rather than one fixed image - the generated gradient, or one of several alternatives that carry the theme's colours.

The blocker is size. Three themes at one image each is already 7.8M of tracked PNG. Nine themes at four wallpapers each would be around 94M, which is not something a configuration repository should carry, and it grows every time a theme is added.

So the images should stop being committed and start being generated on the machine, on demand, cached. That inverts the current arrangement: tools/wallpaper.py never reaches the built system, and would have to move into the dotfiles so it does. Adding a theme then costs no bytes at all, which is the property that makes "way more themes" cheap rather than expensive.

The wallpaper choice is per-theme and machine-local, in the same place the theme selection lives, so that switching to a theme returns the wallpaper last chosen for it rather than resetting.

Worth deciding while doing it: whether a user-supplied image (a photograph, say) can be selected the same way, since the mechanism is nearly the same and the alternative is a second mechanism later.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Several more themes exist, including a green one, and every one of them passes the existing key-parity and contrast checks
- [x] #2 Within a theme, more than one wallpaper can be chosen, and the choice is made from the launcher rather than by editing anything
- [x] #3 The wallpaper choice is remembered per theme, so switching away and back does not lose it
- [x] #4 Wallpaper images are no longer committed to the repository, and adding a theme adds no binary files
- [x] #5 Generating a wallpaper on the machine is fast enough not to make switching feel broken, with the measurement recorded rather than asserted
- [x] #6 A wallpaper that has already been generated is not generated again
- [x] #7 Whether a user-supplied image can be chosen the same way is decided rather than left implicit
- [x] #8 checks/session.sh covers the new arrangement, including that the wallpaper on screen matches the theme and style selected
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Stop committing wallpaper images. Move the generator out of tools/ - which
   never reaches the built machine - into the dotfiles, so it can render on
   demand and cache. This is what makes "many more themes" cheap.
2. Speed it up first, since it now runs at switch time rather than offline.
3. Add styles: two smooth, two carrying lines, the line ones upscaling a field
   and computing lines at full resolution so they stay sharp.
4. Record the style per theme in the same machine-local place the theme lives.
5. Five more themes including a green one, contrast-checked while designing.
6. A wallpaper picker and desktop entry alongside the theme one.
7. Extend checks/session.sh; update DECISIONS.md, CLAUDE.md and the wallpapers
   README.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verification evidence.

AC1 - eight themes, key parity and both contrast floors verified by
checks/session.sh (54 passed, 0 failed). verdant is the green one. The
contrast floors were checked while designing the palettes rather than
after, so no theme needed reworking.

AC2/AC3 - switched slate -> verdant -> slate -> verdant with a different
style set for each, confirming by pgrep -a swaybg each time that the image
on screen was the one expected. The wallpaper picker was launched and
screenshotted; it is labelled with the theme it applies to.

AC4 - git ls-files shows no tracked png or jpg. setup/dotfiles went from
7.8M to 304K.

AC5 - measured: 0.6s to switch when the image is cached, about 2.0-2.4s the
first time a theme-and-style pair is used. Generation itself is 1.5s for a
smooth style and 2.3s for a line style, down from 4.2s: profiling showed
6.2M random.uniform calls plus as many min/max clamps dominating, replaced
by one randbytes per row and two lookup tables.

AC6 - the second switch to a previously-used pair printed no "Generating"
line and completed in 0.64s.

AC7 - decided yes. A path is recorded in place of a style name and used as
it stands; the theme's colours do not follow it. Documented in the script,
the wallpapers README and DECISIONS.md.

AC8 - three checks: the generator ships and is executable, nothing
image-shaped is tracked under setup/dotfiles/, and swaybg's actual image
matches the selected theme and style. The last two were confirmed to fail
when they should, by removing a cached image and by planting a png in the
dotfiles.

Bug found and fixed during the work: theme and wallpaper each had their own
TOML writer for the machine-local config, and they disagreed about nested
tables - the theme switcher flattened [data.wallpaper] into a string, after
which every chezmoi apply died inside the sway template. Consolidated into
~/.local/lib/desktop_config.py, which is now the only writer and repairs a
value of the wrong shape rather than crashing on it.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Eight themes, four wallpaper styles each, chosen from the launcher and
remembered per theme.

Wallpapers are no longer committed. Three themes at one image each was 7.8M
of tracked PNG and the requested arrangement would have been about 90M,
growing ~10M per theme - so the generator moved out of tools/ and into the
dotfiles, and renders on demand into ~/.local/share/wallpapers. Tracked
dotfiles fell from 7.8M to 304K and a theme is now nothing but a table of
colours.

Styles come in two kinds: smooth ones evaluated small and upscaled, and line
ones that upscale a field and compute the lines at full resolution so they
stay sharp. An image of your own can be selected in place of a style.

Five new themes - verdant, abyss, orchid, cobalt, mono - all clearing key
parity and both contrast floors, with the semantic four kept distinguishable
from each theme's own accent.

Generation was made ~3x faster first, since it now runs at switch time:
0.6s to switch cached, about 2s when the image must be rendered.

Verified with checks/session.sh (54 passed, 0 failed, three new checks, two
confirmed to fail when they should), live switching confirmed against
pgrep -a swaybg rather than against the config, and screenshots of all eight
themes and of both pickers.
<!-- SECTION:FINAL_SUMMARY:END -->
