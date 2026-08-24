---
id: TASK-169
title: 'Continue markdown lists on Enter, and drop the ~ end-of-buffer column'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-24 21:15'
updated_date: '2026-08-24 21:24'
labels: []
dependencies: []
ordinal: 176000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Two small editor annoyances. Writing a list in markdown means retyping the marker on every line - bullets, numbered items and checkboxes alike - because nothing continues them. And every line past the end of the buffer carries a ~, which says nothing the absent line number does not already say and costs a column of the gutter.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Pressing Enter at the end of a markdown bullet, numbered item or checkbox starts the next line with the same marker, at the same indent
- [x] #2 Pressing Enter on a list item with no content clears the marker instead of adding another, so a list can be ended without deleting anything by hand
- [x] #3 Numbered lists increment
- [x] #4 No ~ appears below the end of a buffer, in any filetype
- [x] #5 The behaviour is verified by driving a real neovim, not by reading the config
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. list_marker() in init.lua: parse a markdown line into indent, the marker the next line should carry, and the item's content. Bullets, 1./2), checkboxes, nested.
2. Buffer-local insert-mode <CR> mapping on FileType markdown that splits the buffer text itself rather than sending keys.
3. Empty item clears its marker instead of continuing.
4. o.fillchars:append({ eob = ' ' }) for the ~ column.
5. Verify by driving a real neovim through every list form, and by drawing nvim into a pty to count the tildes on screen against a control.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Enter is a real mapping doing real buffer edits, not an expr mapping returning keys, and two earlier attempts are recorded in init.lua because both looked right:

- <CR> plus the marker, letting autoindent reproduce the indent: works, but only because smartindent copies it today.
- <CR><C-u> plus the whole leader: measured to be actively broken. <C-u> at column 0 of the fresh line finds nothing before the cursor and eats the line break instead, because backspace contains eol - so Enter did nothing at all on an unindented item while working on indented ones.

nvim_feedkeys for the plain-Enter path needs the 'i' flag. The default appends to the typeahead, so keys already queued run before the newline; a scripted test hits that every time and a fast typist can.

Verified by driving a real neovim (rendered config, XDG_CONFIG_HOME pointed at it): bullet, indented bullet, 1., 2), nested 3., *, checkbox, ticked checkbox, mid-item split, cursor inside the marker, empty item at two indents, three lines that only look like lists, and a non-markdown buffer. The ~ was counted on a drawn 20x40 pty frame: 28 before, 0 after.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Markdown Enter continues the list - same bullet, same indent, next number, an empty checkbox - and Enter on an item with nothing in it clears the marker so a list can be ended. Implemented as a buffer-local insert-mode mapping in setup/dotfiles/dot_config/nvim/init.lua that edits the buffer text directly; two key-sending approaches were tried first and both are recorded there, one of which silently did nothing on unindented items. fillchars eob is a space, so the ~ column below the end of a buffer is gone.

Verified by driving a real neovim over thirteen list and non-list cases, and by drawing nvim into a pty and counting tildes on the frame: 28 with the old config, 0 with the new. checks/manual.sh passes; docs/manual/04-applications.md gained the two paragraphs.
<!-- SECTION:FINAL_SUMMARY:END -->
