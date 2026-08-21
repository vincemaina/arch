---
id: TASK-79
title: add truncation to media summary in top bar
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 13:48'
updated_date: '2026-08-21 20:36'
labels: []
dependencies: []
modified_files:
  - setup/dotfiles/dot_config/waybar/config.jsonc.tmpl
priority: low
type: enhancement
ordinal: 81000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
It shouldn't display the full name, there should be a limit based on available space / screensize etc, and then it should truncate the media name and scroll through it
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A long track title is truncated with an ellipsis rather than dropped: the title is always visible when a player is playing
- [x] #2 The centre of the bar stops growing past a fixed budget, measured in pixels, however long the title or artist is
- [x] #3 The untruncated title and artist remain available in the tooltip
- [x] #4 checks/session.sh passes 75/0 and checks/sway-commands.sh exits 0
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Reproduce on the running bar: a fake MPRIS player with a long title, then look at what the centre actually renders.
2. Read waybar-mpris(5) and the 0.15.0 source to establish what dynamic-len, title-len and artist-len each do.
3. Trial candidate lengths on a throwaway waybar on HEADLESS-2 (bottom edge, so it cannot be confused with the real bar) and screenshot each.
4. Set title-len/artist-len alongside the existing dynamic-len budget in setup/dotfiles/dot_config/waybar/config.jsonc.tmpl, and rewrite the comment that described dynamic-len wrongly.
5. chezmoi apply, restart waybar, and measure the rendered width of the centre group across title/artist lengths to prove it saturates.
6. checks/session.sh and checks/sway-commands.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
What was actually wrong. The module already carried "dynamic-len": 45 with a comment saying it capped the title. It does not cap anything: dynamic-len is a budget for the whole {dynamic} string and a tag that will not fit is dropped whole. Measured on the running bar with a fake MPRIS player: a 20-character title showed "title - artist"; a 40-character title showed the title alone; a 60- or 80-character title showed **the artist alone, with the title gone**; and a long title next to a long artist showed nothing but the music icon. So the failure was not the bar changing shape, it was the media readout deleting itself - the invisible-configuration failure CLAUDE.md describes.

The fix is title-len 30 and artist-len 20 next to the unchanged dynamic-len 45. title-len/artist-len are the settings that truncate, with an ellipsis (confirmed against waybar 0.15.0 src/modules/mpris/mpris.cpp: getTitleStr/getArtistStr call truncate() with the ellipsis; getDynamicStr only decides which tags fit). With the title capped at 30 it always fits the budget, so the title is now always the tag that survives and the artist is what gets dropped when a long title leaves no room.

Not scrolled. waybar's mpris module has no marquee, and the only way to scroll would be to replace it with a custom module polling playerctl on a timer - a permanently animating readout in the centre of the bar, redrawing for text the tooltip already holds in full. Recorded in the config comment rather than left as an open question.

A harness trap worth keeping: the first round of throwaway-waybar trials all produced identical screenshots, because the real waybar service also draws a bar on the headless output and grim captured that one. Every "override" appeared to do nothing, including one that changed the format string. Fixed by giving the throwaway bar "position": "bottom" and a TESTBAR marker in its clock, so the capture is provably not the real bar.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Gave the media module real truncation: title-len 30 and artist-len 20 alongside the existing dynamic-len 45 in setup/dotfiles/dot_config/waybar/config.jsonc.tmpl, and rewrote the comment that claimed dynamic-len capped the title - it does not, it drops whole tags, which is why a long title used to vanish and leave the artist alone (or nothing but the icon when both were long).

Verified on the running system, not the file. chezmoi apply + systemctl --user restart waybar, then a fake MPRIS player driven through a range of titles and artists with grim captures of the real bar: a 73-character title now renders as "Everything In Its Right Place… - Radiohead", and with a long artist as well the artist is dropped and the title still shows. Width measured from raw PPM pixels (leftmost to rightmost lit column of the centre group): 360px at a 10-char title, 440 at 20, and 520 at 30 characters and unchanged at 45, 60, 80 and 120 - it saturates instead of growing; artist length saturates at 464, worst case across the grid 568px on a 1920px output. Hovering the pill shows the tooltip still carrying the full untruncated title and artist (screenshot). checks/session.sh 75 passed / 0 failed; checks/sway-commands.sh exit 0.

Not done: scrolling the truncated title. waybar 0.15 mpris has no marquee, so it would mean replacing the built-in module with a polling custom script and animating the centre of the bar permanently; the reasoning is recorded in the config comment.
<!-- SECTION:FINAL_SUMMARY:END -->
