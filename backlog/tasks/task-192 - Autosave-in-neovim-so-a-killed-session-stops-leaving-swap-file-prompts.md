---
id: TASK-192
title: 'Autosave in neovim, so a killed session stops leaving swap-file prompts'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-29 10:07'
updated_date: '2026-08-29 11:13'
labels: []
dependencies: []
ordinal: 198000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Neovim is the only editor on this desktop that can lose work, and it announces the fact at the worst possible moment: opening a file greets you with E325 ATTENTION and a swap file "modified: YES", which is nvim saying an earlier session died with unwritten changes. On this machine right now there are four such swap files under ~/.local/state/nvim/swap, three of them for the same notes file - .swp, .swo and .swn - which is what happens when a terminal running nvim is closed rather than quit, repeatedly.

Ctrl+S already writes the file (TASK-171), but relying on it is relying on remembering it. Every other editor the user works in saves on its own.

MEASURED, BECAUSE IT DECIDES THE SHAPE OF THE FIX: a stale swap file is only a problem when it holds unsaved changes. Killing nvim -9 with an unwritten buffer and reopening the file produces the full E325 dialog; killing it after a :write and reopening produces nothing at all, and nvim silently deletes the swap file on the way in. So autosave is the whole fix - no SwapExists autocmd, no cleanup timer, nothing that has to reason about whether another nvim owns a swap file.

The user chose the VS Code shape over the conservative one: debounced, roughly a second after the last keystroke, in insert mode as well as normal. That is the only variant that also covers being killed mid-sentence, which is the case that actually produced the swap files above. The cost is accepted: a file watcher may see a half-typed line.

Format-on-save stays off. lua/lsp.lua argues that case at length and autosave makes it stronger, not weaker - reformatting the buffer under the cursor a second after you stop typing would be unusable.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A modified buffer is written to disk about a second after the last keystroke, in insert mode as well as in normal mode
- [x] #2 Rapid typing does not produce a write per keystroke: the delay restarts on each change, so a continuous burst of typing writes once at the end of it
- [x] #3 Buffers that must not be written are left alone: unnamed buffers, non-file buftypes (help, terminal, quickfix, the completion popup and friends), and anything nomodifiable or readonly
- [x] #4 The write is quiet: no "written" message flashing in the message area, and no hit-enter prompt
- [x] #5 Formatting still does not run on save; <leader>f remains the only thing that reformats a buffer
- [x] #6 Killing nvim with kill -9 on a file that has been typed into and reopening that file shows no E325 dialog - verified by doing it, not by reading the config
- [x] #7 The four stale swap files in ~/.local/state/nvim/swap are cleared, and the one belonging to the nvim process that is actually running is not touched
- [x] #8 The manual says autosave is on and what it does not do, in the chapter that already covers the editor
- [x] #9 DECISIONS.md records the choice under the existing Neovim decision: why debounced rather than on-Esc, and why no swap-file handling was needed
- [x] #10 checks/session.sh passes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Work on branch task-192 in the main checkout rather than a worktree: this machine's chezmoi sourceDir is /home/vincemaina/Projects/arch/setup, and applying dotfiles from a worktree would repoint it at a directory that is about to be deleted (TASK-121.1).
2. Add an Autosave section to setup/dotfiles/dot_config/nvim/init.lua, next to the Ctrl+S mapping, since that is where a reader asking how files get written will look. One vim.uv timer per buffer, restarted by TextChanged and TextChangedI, firing 'silent update' inside nvim_buf_call so the write does not depend on which buffer is current when it lands.
3. Guards, each one a way this could go wrong quietly: only named, modifiable, non-readonly buffers with buftype '' (no help, terminal, quickfix); skip and reschedule while the completion popup is visible, so a write cannot dismiss it mid-word; skip when the file's mtime on disk differs from what nvim last read or wrote, because ':update' answers that case with a modal 'really write?' prompt and a modal prompt appearing on its own is worse than not saving; pcall the write and, on failure, notify once and stop autosaving that buffer instead of repeating the same error every second.
4. Close and forget the timer on BufWipeout so a long session does not accumulate them.
5. chezmoi apply, then verify on the running editor rather than in the file: watch the file's mtime while typing a burst (one write per burst, not per keystroke), confirm nothing flashes in the message area, kill -9 the process and reopen to confirm E325 is gone, and confirm <leader>f is still the only thing that reformats.
6. Clear the stale swap files under ~/.local/state/nvim/swap, checking each one's recorded PID first so the swap belonging to the nvim that is actually running is left alone.
7. Manual chapter, DECISIONS.md under the existing Neovim decision, and checks/session.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
VERIFICATION - all of it against a running editor over RPC, not against the file.

A headless nvim was started with --listen and driven with 'nvim --server ... --remote-send', which is real input through the main loop. Every number below is measured.

- AC1: 'oTYPING<Esc>' then a wait; the file on disk gained the line and BufWritePost fired exactly once. Also confirmed while still in insert mode (mode() == 'i' at the moment of the write).
- AC2: fifteen keystrokes at 200ms intervals - 3 seconds of continuous typing - produced 0 writes. One write landed 1.5s after the last keystroke. The delay restarts on each change, as designed.
- AC3: measured buffer by buffer. Unnamed scratch: 0 writes, no error. ':terminal' (buftype=terminal, changing on every line of output): 0 writes. ':help' (buftype=help, nomodifiable): 0 writes. ':copen' (buftype=quickfix): 0 writes. A file opened with -R (readonly=1) and changed anyway: 0 writes, file on disk untouched. The completion-popup guard is by inspection of pumvisible() rather than measurement - it reschedules rather than skipping, so it cannot lose a write.
- AC4: execute('messages') was empty after every autosave in every test above. The only message any probe produced was vim's own 'W10: Warning: Changing a readonly file', which is not autosave. No hit-enter prompt appeared - and one would have hung the headless probe, so its absence is load-bearing rather than assumed.
- AC5: a deliberately messy JSON file with vscode-json-language-server attached was typed into and autosaved; the file on disk kept its original spacing exactly. There is no BufWritePre anywhere in the nvim config.
- AC6: run twice, with a negative control. Killed 0.3s after typing (before autosave could fire) and reopened: the full E325 dialog, 'modified: YES'. Killed 2s after typing the same text and reopened: no output at all, and nvim removed the swap file itself on the way in. The control is the point - it proves the test could have failed.

Also measured, and it is what removed the SwapExists autocmd from the plan: a swap file whose buffer was clean at the moment of the kill produces no dialog at all. Neovim compares the swap against the file and deletes it silently. Saving is the entire fix.

AC7 DID NOT GO AS WRITTEN, and the difference matters. Three of the four stale swaps held content that existed nowhere else - five todo items ('Fix keyboard', 'Fix bike if possible', 'Switch copy + paste', 'Radio', 'check when next being charged my manual') and a whole 26-08-26.md ('Book GP Appointment', 'Get bike parts') for which no file existed on disk at all. Deleting them would have destroyed real notes, so each was recovered and diffed against the live file first, and the user chose what to do with them: written out as ~/Documents/notes/recovered-26-08-26.md and recovered-26-08-29.md, verbatim, without merging into the current notes. The 09:32 swap turned out to be a strict subset of the 10:03 one, so two recovered files cover three swaps. The three were then deleted. The fourth, the live one, was never touched - the user quit that editor during the session and neovim removed its swap itself.

THE CHECK TOOK THREE ATTEMPTS AND THE FIRST TWO ARE WORTH RECORDING, because both failed in the way the scripting-traps skill warns about. Driving the probe with vim.api.nvim_feedkeys() inside 'nvim --headless -c' fires no TextChanged or TextChangedI at all - the events are documented not to fire while there is typeahead - so the check reported 'the editor did not autosave' on a machine where it demonstrably does. Switching to nvim_input() failed the same way: vim.wait() pumps the event loop but not the input layer, so the keys were never consumed. A measuring apparatus that is silently not measuring, twice. The check now drives a real instance over its socket, and - per the same lesson - asserts the text actually reached the buffer before a missing write is allowed to mean anything.

The check was then proved to go red: the TextChanged autocmd in the applied config was rewired to a User event that never fires, session.sh reported FAIL, and it went green again on restore. It also quits its probe with ':qa!' rather than only killing it, because a neovim that takes SIGTERM with a modified buffer preserves its swap - a check that littered ~/.local/state/nvim/swap would be creating the mess it exists to detect.

Worked on branch task-192 in the main checkout rather than a worktree, deliberately: this machine's chezmoi sourceDir is the main checkout, and applying dotfiles from a worktree would have repointed it at a directory due to be deleted (TASK-121.1).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Neovim now writes a modified buffer about a second after the last change, in insert mode as well as normal, debounced so a burst of typing is one write. Roughly 60 lines in setup/dotfiles/dot_config/nvim/init.lua next to the Ctrl+S mapping: one libuv timer per buffer restarted by TextChanged and TextChangedI, firing 'silent update' inside nvim_buf_call.

The four things it refuses to write are the design rather than the detail - buffers with no file behind them, readonly ones, anything mid-completion, and a file that has changed on disk since neovim read it, because ':update' answers that last case with a modal 'do you really want to write to it?' that would eat the next key pressed. A write that fails stops autosave for that buffer and says so once instead of failing quietly once a second.

No swap-file handling, and that was measured rather than assumed: killing neovim -9 with a dirty buffer and reopening produces the whole E325 dialog, killing it after a write produces nothing at all because neovim compares the swap against the file and deletes it itself. Saving is the entire fix. Verified by doing both, with the dirty-kill case as a negative control.

All ten acceptance criteria verified against a running editor driven over RPC - 3 seconds of continuous typing produces 0 writes and one write 1.5s after stopping; terminal, help, quickfix, unnamed and readonly buffers all produce 0 writes; execute('messages') is empty after every save; a messy JSON file with a language server attached comes back unreformatted.

The stale swaps turned out to hold real notes that existed nowhere else, so they were recovered and diffed before anything was deleted, and written out verbatim as ~/Documents/notes/recovered-26-08-26.md and recovered-26-08-29.md at the user's direction rather than merged.

Documented in docs/manual/04-applications.md and DECISIONS.md, and covered by a new check in checks/session.sh that was proved to go red before it was trusted. 140 passed, 0 failed; checks/manual.sh 8 passed, 0 failed.
<!-- SECTION:FINAL_SUMMARY:END -->
