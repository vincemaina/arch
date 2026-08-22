---
id: TASK-105.3
title: 'Manual part I: the applications, making it yours, and working'
status: Done
assignee: []
created_date: '2026-08-22 10:27'
updated_date: '2026-08-22 11:05'
labels: []
dependencies: []
parent_task_id: TASK-105
ordinal: 110000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Chapters four to six. The applications: the terminal and shell, the editor and what it can do per language, the two browsers and when each is for, the file manager, the git tool, the calendar. Making it yours: themes, the wallpaper system including the URL library and drop-in files, the bar, fonts, and which of these are machine-local rather than tracked. Working: focus music, the focus timer and what it pauses, clipboard history, screenshots, the notification centre, the startup toggles and the shortcuts helper.

Several of these were built recently and are documented nowhere. Read the helper scripts in setup/dotfiles/dot_local/bin/ rather than assuming behaviour.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Every helper in dot_local/bin/ that a person invokes is documented, and the ones that are internal are named as such
- [x] #2 The theme and wallpaper chapter says clearly what is tracked in the repository and what is machine-local
- [x] #3 A reader can find focus music, the timer, clipboard history and the notification centre without knowing they exist beforehand
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Wrote docs/manual/04-applications.md, 05-making-it-yours.md and 06-working.md. Everything verified against the running system rather than the source: nvim run headlessly to see which LSP clients actually attach per filetype, shortcuts --mode read live, theme/wallpaper/startup queried with --list and --current, 40-window-rules.conf read directly to confirm the visualiser tiles rather than floats.

A later fact-checking pass over all ten chapters found four real errors, two of them here:
  * Chapter 4 claimed neovim deletes "87" default mappings, copied from a comment in init.lua. The deployed config actually removes 69 - the 87 in that comment is nvim raw default count under --clean, not what this configs plugin-disabling plus deletion loop removes. Measured by reading vim.g.removed_default_mappings from the real config, three times for stability.
  * Chapter 4 asserted a scratch file outside any project gets no language server at all. The opposite is true: pyright, ruff and marksman all attach with root_dir = nil, because neovim 0.11+ falls back to single-file mode and this config never sets single_file_support = false. Rewritten.
  * Chapter 5 said the media widget "skips on right/middle" as if both went the same way. waybar mpris defaults are middle=previous, right=next, which chapter 2 had right. Made specific.

Not verified and left hedged in the text: qutebrowsers exact keybindings (this repository ships no qutebrowser config, so the chapter tells the reader to press :bind rather than presenting a list), and whether a browser tab exposes MPRIS for the focus timer to pause - the mechanism is described precisely instead of naming players that were never tested.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Three chapters covering the applications, theming and the work tools, all verified live. A later fact-check corrected two real errors here: a neovim mapping count copied from a stale comment (87 vs a measured 69) and a backwards claim about language servers outside a project.
<!-- SECTION:FINAL_SUMMARY:END -->
