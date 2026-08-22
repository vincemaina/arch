---
id: TASK-112
title: select all shortcut in terminal
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 13:54'
updated_date: '2026-08-22 14:29'
labels: []
dependencies: []
priority: medium
type: feature
ordinal: 120000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
currently there is no way to select all in the terminal.
if copy and paste are ctrl + shift + c/v (respectively), then it follows that select all should be something like ctrl + shift + a
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Ctrl+Shift+A in foot places the terminal's entire scrollback on the clipboard
- [x] #2 The copy is confirmed visibly, since there is no selection to see
- [x] #3 The binding lives in the repository's foot config and reaches a running machine through sync.sh
- [x] #4 checks/sway-commands.sh, checks/session.sh and checks/manual.sh all pass
- [x] #5 The manual documents the shortcut, and tools/shortcuts.sh no longer claims foot overrides no bindings
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
foot 1.27 has no select-all action - verified against the full key-bindings list in `man foot.ini`, and there is no way to script a selection either. So the shortcut delivers what select-all is *for* - getting the whole buffer onto the clipboard - rather than a selection nobody can see.

1. Add `~/.local/bin/terminal-copy-all`: reads the scrollback on stdin, drops the trailing blank lines the grid pads with, copies via wl-copy, and confirms with a notification carrying the line count. Logic goes in a helper, not the config, because foot's bracket syntax quotes badly and `checks/sway-commands.sh` already enforces a `# requires:` header on helpers.
2. Bind it in `foot.ini.tmpl` as `pipe-scrollback=[...] Control+Shift+a`, with an absolute `{{ .chezmoi.homeDir }}` path - foot's PATH is the session's, not an interactive shell's, the same trap waybar already documents.
3. Teach `tools/shortcuts.sh` to read foot's bindings from the rendered config, and drop the now-false "no keybindings overridden" note.
4. Document the shortcut in the manual.
5. Run the checks.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## What was built

- `setup/dotfiles/dot_local/bin/executable_terminal-copy-all` - reads foot's scrollback on stdin, trims the trailing blank rows the grid pads with, copies via wl-copy, and raises a notification with the line count.
- `foot.ini.tmpl` gains a `[key-bindings]` section: `pipe-scrollback=[{{ .chezmoi.homeDir }}/.local/bin/terminal-copy-all] Control+Shift+a`.
- `tools/shortcuts.sh` grew a 'Terminal - foot' section that parses the rendered config, replacing the now-false 'no keybindings overridden' note.
- `docs/manual/04-applications.md` documents the key and that it is a copy, not a selection.
- `checks/session.sh` gained human step 5, for the one link no script can test.

## The finding

foot 1.27 has **no select-all action**. Every key-bindings action in `man foot.ini` was read; the select-* actions that exist (select-begin, select-word, select-row, select-extend) are all pointer-driven and none can be told 'everything'. There is no IPC to script a selection either. So the shortcut copies rather than selects, and the notification stands in for the missing highlight.

## Verification

- `foot --check-config` accepts the rendered config (exit 0). **Negative control run first**: binding the same action to Control+Shift+c gives 'already mapped to clipboard-copy' and exit 230 - so the check has teeth, and Ctrl+Shift+A being accepted is itself proof it collided with no foot default.
- Helper exercised against stub wl-copy/notify-send over seven inputs: trailing blank lines dropped, interior blanks kept, width padding trimmed, singular/plural correct, and empty input leaves the clipboard alone rather than wiping it.
- End-to-end with the **real** wl-copy and notify-send, wrapped to write PRIMARY so the clipboard and cliphist history were untouched: 40 numbers plus 'done' plus four trailing blanks produced 'Copied - 41 lines on the clipboard' in `makoctl history`, and the selection survived the helper exiting.
- `tools/shortcuts.sh` proved against a real rendered config (swapped in and restored byte-identical): renders 'Ctrl+Shift+A' in both terminal and markdown form, and registers no cross-context key clash.
- checks: sway-commands 0 failures (awk -> gawk, notify-send -> libnotify, wl-copy -> wl-clipboard all resolve), sway-bindings 76 bindings and no duplicate, manual 8/8, packages 6/6, session 92/0.

## What is NOT verified, and why

**The keypress itself.** No script on this machine can generate one: /dev/uinput is root-only, wtype and ydotool are not installed, and sway has no key-injection IPC. The mouse route was tried too - foot's [mouse-bindings] accept the same actions, and sway can inject clicks - but foot ignores swaymsg's synthetic button events (proved by binding fullscreen to BTN_MIDDLE and watching fullscreen_mode stay 0, while sway's own binding on the same injected click did fire). So AC 1 stays unchecked until a human presses it. That is now step 5 of checks/session.sh rather than an unwritten gap.

Also note the change is not live: `./sync.sh` has not been run, and foot reads its config only at startup, so the key works in terminals opened after a sync.

AC 1 confirmed by the user on 2026-08-22: Ctrl+Shift+A in a terminal opened after sync copies the scrollback and raises the 'Copied - N lines' notification. That was the one link no script here could exercise (uinput root-only, no wtype/ydotool, no key-injection IPC in sway, and foot ignores synthetic clicks), so it needed a human by design - step 5 of checks/session.sh.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-08-22 14:12
---
Implementation is complete, checks all pass, and the branch is pushed as worktree-task-112-select-all. AC 1 is deliberately left unchecked: nothing on this machine can generate the keypress (uinput is root-only, no wtype/ydotool, sway has no key-injection IPC, and foot ignores synthetic clicks). Run ./sync.sh, open a NEW terminal - foot reads its config only at startup - and press Ctrl+Shift+A. A 'Copied - N lines' notification closes it. It is also step 5 of checks/session.sh now.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
foot 1.27 has no select-all action - every key-bindings action in `man foot.ini` was checked, the select-* actions that exist are pointer-driven with no way to say 'everything', and there is no IPC to script a selection. So Ctrl+Shift+A does what select-all is for instead: `pipe-scrollback` hands the whole buffer to `~/.local/bin/terminal-copy-all`, which trims the trailing blank rows a terminal grid pads with, copies via wl-copy, and raises a notification with the line count - the notification standing in for the highlight that cannot exist.

The logic is a helper rather than an inline `sh -c` because checks/sway-commands.sh only validates external commands behind a `# requires:` header; the path is absolute via chezmoi because foot inherits the session's PATH, not zsh's. tools/shortcuts.sh now parses foot's rendered config instead of claiming it overrides nothing, docs/manual/04-applications.md documents that the key copies rather than selects, and checks/session.sh gained human step 5.

Verified: `foot --check-config` accepts the rendered config, with a negative control (same action on Control+Shift+c) rejected as 'already mapped to clipboard-copy' - so acceptance proves the key was free. The helper was exercised over seven inputs against stubs, then end-to-end against the real wl-copy and notify-send wrapped to write PRIMARY so the clipboard and cliphist history stayed untouched: 41 lines in, 'Copied - 41 lines on the clipboard' out of makoctl history. checks: session 92/0, sway-commands 0 failures, sway-bindings 76 with no duplicate, manual 8/8, packages 6/6. The keypress itself was confirmed by the user, being the one link no script on this machine can generate.
<!-- SECTION:FINAL_SUMMARY:END -->
