---
id: TASK-194
title: Ctrl+Q quits neovim
status: Done
assignee:
  - '@claude'
created_date: '2026-08-29 11:25'
updated_date: '2026-08-29 11:29'
labels: []
dependencies: []
ordinal: 199000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Ctrl+S already writes the file in neovim (TASK-171), matching what every other editor on this machine does. Ctrl+Q is the other half of that habit: leave the editor without typing :qa. Nothing on this desktop claims Ctrl+Q today - keyd rewrites k, semicolon, j, h and l in its [control] layer but not q, foot binds nothing on it, and sway has $mod+q rather than Ctrl+q - so the key reaches neovim. Measured: 0x11 sent down a pty fires a <C-q> mapping in normal mode, so terminal flow control is not in the way (neovim turns IXON off in raw mode, the same reason Ctrl+S arrives). The cost is real and needs writing down rather than discovering: Ctrl+Q is currently blockwise-visual mode, because it is vim built-in behaviour rather than a mapping the pruning in init.lua would have removed. Ctrl+V, the usual key for that, never reaches neovim in this terminal - foot consumes it for paste since TASK-187. Measured, both ways: 0x11 and 0x16 each put neovim in VISUAL BLOCK today, and foot sends 0x16 for Ctrl+Shift+V, so blockwise visual survives on Ctrl+Shift+V once Ctrl+Q is taken.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Ctrl+Q in normal mode leaves neovim
- [x] #2 Ctrl+Q in insert mode leaves neovim
- [x] #3 Unsaved changes are not lost silently: the quit prompts rather than discarding
- [x] #4 The mapping carries a description, so checks/session.sh passes and the shortcuts helper lists it
- [x] #5 The cost to blockwise visual, and that Ctrl+Shift+V replaces it in this terminal, is written down where the next reader will look
- [x] #6 checks/session.sh passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a <C-q> mapping to setup/dotfiles/dot_config/nvim/init.lua, next to the Ctrl+S block it is the other half of: normal and insert mode, right-hand side '<cmd>confirm qa<CR>' - every window, and a prompt rather than a silent discard.
2. Write the two things that are not obvious into the comment beside it: that the key arrives despite being XON (measured down a pty, same raw-mode reason Ctrl+S arrives), and that it OVERWRITES blockwise visual - which is a vim built-in rather than a mapping, so the pruning above never saw it - with Ctrl+Shift+V as the replacement in this terminal because foot sends 0x16 for it.
3. Measure the result against the real config in a pty rather than reading it back: Ctrl+Q from normal mode exits, Ctrl+Q from insert mode exits, an unsaved buffer prompts instead of dying, and 0x16 still reaches blockwise visual.
4. Add the row to the neovim keybinding table in docs/manual/04-applications.md and say what it cost, since that chapter already carries the Ctrl+S and foot-swap story.
5. Run checks/session.sh and shortcuts --mode nvim.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Measured against the real config rendered to a scratch destination (chezmoi --source ./setup --destination <scratch> apply --force --exclude=scripts) and driven through a pty, not read back off the file:

- Ctrl+Q (0x11) in normal mode on a clean buffer: nvim exits.
- Ctrl+Q in insert mode: nvim exits.
- Ctrl+Q on an unnamed modified buffer (the case autosave deliberately skips): does NOT exit, and the screen shows `Save changes to "Untitled"?  [Y]es, (N)o, (C)ancel:`.
- 0x16, the byte foot sends for Ctrl+Shift+V: still VISUAL BLOCK, read off the mode indicator.

`confirm qa` rather than plain `qa` even though o.confirm is already true: a key whose whole job is closing everything should not depend on an option two hundred lines away staying set.

Both mappings register with descriptions - `<C-Q> Quit neovim` in n and i, listed by nvim_get_keymap - so the shortcuts helper picks them up and the description pass in checks/session.sh is satisfied.

foot --check-config accepts the edited foot.ini (comment-only change there): the \x16 text-binding now carries a note that it is the only route into blockwise visual inside this terminal, so deleting it would remove a vim mode rather than just quoted-insert.

checks/session.sh: 140 passed, 0 failed, 2 skipped. checks/manual.sh: 8 passed, 0 failed.

Noted in passing, NOT changed - out of scope: the neovim table in docs/manual/04-applications.md still lists <C-h>/<C-j>/<C-k>/<C-l> as split movement, but init.lua sets only <C-l> (the other three are keyd rewrites and the lines were deliberately removed). Pre-existing drift that checks/manual.sh does not look for.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ctrl+Q now quits neovim from normal or insert mode, as `<cmd>confirm qa<CR>` beside the Ctrl+S mapping it is the other half of - every window, and a prompt rather than a silent discard for anything still unsaved.

The key was free everywhere it could have been claimed (keyd rewrites k, semicolon, j, h, l but not q; foot binds nothing on it; sway uses $mod+q) and it reaches nvim despite being XON, because raw mode turns IXON off - measured by sending 0x11 down a pty, not assumed from the Ctrl+S precedent.

What it cost is blockwise visual, which Ctrl+Q was providing as a vim built-in rather than a mapping, so the default-pruning in init.lua never saw it. That mattered more than it looks: foot has consumed Ctrl+V for paste since TASK-187, so Ctrl+Q was the only route into the mode in this terminal. It survives on Ctrl+Shift+V, because foot sends \x16 for that - measured, 0x11 and 0x16 both reached VISUAL BLOCK before the change, 0x16 still does after. Written down in three places a reader might arrive from: the mapping comment, the foot text-binding it now depends on, and the editor section of the manual.

Verified in a pty against the config rendered from this branch: exits from normal mode, exits from insert mode, prompts with `Save changes to "Untitled"?` on an unsaved buffer, and Ctrl+Shift+V still enters blockwise visual. checks/session.sh 140 passed / 0 failed, checks/manual.sh 8 passed / 0 failed, foot --check-config clean.
<!-- SECTION:FINAL_SUMMARY:END -->
