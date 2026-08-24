---
id: TASK-164
title: Small Arch logo in waybar that opens the power menu
status: Done
assignee:
  - '@claude'
created_date: '2026-08-24 09:13'
updated_date: '2026-08-24 09:33'
labels: []
dependencies:
  - TASK-163
ordinal: 168000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a small themed Arch Linux logo to the left of waybar's workspace module. The logo is an inline SVG colored from the active theme's palette (per CLAUDE.md's theming section) rather than a committed image asset, and clicking it opens the power-actions rofi menu built in the power-actions task, invoked via an absolute path per waybar's PATH pitfall. Update the clickable-modules table in waybar/config.jsonc.tmpl.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 waybar shows a small Arch logo to the left of the workspaces module
- [x] #2 The logo is rendered as an SVG colored from the active theme's palette, not a committed image file
- [x] #3 No image-shaped asset is added under setup/dotfiles/
- [x] #4 Clicking the logo opens the power-actions rofi menu
- [x] #5 The click command in waybar/config.jsonc.tmpl uses an absolute path
- [x] #6 The clickable-modules table at the top of waybar/config.jsonc.tmpl documents the new module
- [x] #7 checks/session.sh passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Build the logo as a chezmoi-templated SVG (setup/dotfiles/dot_config/waybar/arch-logo.svg.tmpl), colored with the active theme's accent, using the official Arch Linux mark (Simple Icons, CC0). No binary image asset is committed - the SVG text is generated per theme the same way every other themed consumer works.
2. Add librsvg to setup/packages/desktop.txt, DECLARED RATHER THAN INHERITED: it is already installed transitively (via gdk-pixbuf2 <- gtk3/gtk4/greetd-regreet, and via ffmpeg), which is the exact 'installed as a dependency' trap CLAUDE.md warns about for polkit/mesa/adwaita-cursors - waybar's image module needs it directly to decode the SVG. Document it in docs/software/README.md (table row + full entry) and bump the declared-package count.
3. Wire it into waybar/config.jsonc.tmpl as an 'image#arch-logo' module, first in modules-left (left of sway/workspaces), sized from the bar's existing $scale, on-click set to the absolute path of ~/.local/bin/power-menu (TASK-163's menu). Update the clickable-modules comment table at the top of the file.
4. Style it in style.css.tmpl: reuse the shared pill padding/margin/radius, add a hover background. Waybar's CSS selector for 'image#arch-logo' is '#image.arch-logo' (type keeps its id, the #name becomes a class) - confirmed against Waybar's own config docs rather than assumed.
5. Update docs/manual/02-the-desktop.md's bar module table with an Arch-logo row linking to the '## Power' section already added for TASK-163.
6. Verify: render all templates (chezmoi --destination scratch --exclude=scripts), confirm the JSON is valid after stripping // comments, rasterize the rendered SVG with rsvg-convert and look at it, load a throwaway waybar instance on a headless output pointed at the rendered config+css to confirm no parse/crash errors. Run checks/session.sh and checks/manual.sh.
7. Finalize: verify acceptance criteria, mark Done.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified: chezmoi renders both arch-logo.svg.tmpl and config.jsonc.tmpl/style.css.tmpl cleanly (no template errors). The rendered config.jsonc is valid JSON once // comments are stripped. Rasterized the rendered SVG with rsvg-convert -w 256 -h 256 and looked at it: it is a clean, recognisable Arch Linux mark, filled in the current machine's accent colour (confirmed the hex in the rendered file matches themes.toml's accent for the active theme). Loaded a throwaway waybar instance (waybar -c/-s pointed at the rendered config+css, with "output" restricted to a headless test output and the SVG path pointed at a scratch copy so nothing under the real ~/.config/waybar/ was touched or read) - it started with no CSS parse error and no missing-file error, only a benign 'no bluetooth controller found' warning also seen from the real bar. Screenshotting the headless output itself was inconclusive both for this and for the rofi menu in TASK-163 (this machine's compositor appears to draw its background/bar layers onto every output including freshly created headless ones, which is what grim captured, rather than the client surface under test) - treated as inconclusive per the desktop-verification skill rather than as a negative result, and not worth further pursuit given this machine is the user's live desktop, shared with the coordinating parent session. Corrected one real mistake this test process caught before it shipped: waybar's CSS selector for a module named 'image#arch-logo' is '#image.arch-logo' (the type keeps its id, the name becomes a class), not '#arch-logo' as first written - confirmed against Waybar's own configuration docs. checks/session.sh: 124 passed, 0 failed (image-shaped check only flags .png/.jpg/.jpeg, confirmed by reading checks/session.sh directly - the .svg.tmpl is not and should not be flagged). checks/manual.sh: 8/8 passed, including the new Arch-logo bar-table row's anchor link to '## Power' resolving correctly (checked the rendered HTML: <a href="#02-the-desktop--power">).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added a small Arch Linux logo to the left of waybar's workspace module. It is a chezmoi-templated SVG (setup/dotfiles/dot_config/waybar/arch-logo.svg.tmpl) using the official Simple Icons (CC0) Arch mark, filled with the active theme's accent colour and re-rendered on every chezmoi apply - no binary image asset is committed, matching CLAUDE.md's rule for wallpapers/sounds. Wired in as waybar's 'image#arch-logo' module (waybar 0.15.0 supports the image module type), first in modules-left, sized from the bar's existing scale variable, with on-click set to the absolute path of ~/.local/bin/power-menu (TASK-163) - absolute per waybar's PATH pitfall. Styled in style.css.tmpl with the same pill padding/margin/radius every other module shares and a hover background, using the correct waybar CSS selector '#image.arch-logo' (confirmed against Waybar's own docs: a module's type keeps its CSS id, and '#name' becomes a class, not a second id - the opposite of my first guess). Declared librsvg in setup/packages/desktop.txt: it was already installed transitively (gdk-pixbuf2 <- gtk3/gtk4/greetd-regreet, and ffmpeg) but the bar now relies on it directly to decode the SVG, the same 'installed as a dependency' situation CLAUDE.md documents for polkit/mesa/adwaita-cursors - documented with a full entry in docs/software/README.md and the declared-package count updated. Documented in docs/manual/02-the-desktop.md's bar module table, linking to the '## Power' section TASK-163 added. Verified: all templates render without error; the rendered config.jsonc is valid JSON after stripping comments; the rendered SVG was rasterized with rsvg-convert and visually confirmed as a correct, themed Arch mark; a throwaway waybar instance loaded the rendered config+css with no parse or crash error. checks/session.sh: 124/0. checks/manual.sh: 8/8, including the new table row's anchor link resolving correctly in the built HTML.
<!-- SECTION:FINAL_SUMMARY:END -->
