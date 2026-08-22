---
id: TASK-119
title: 'Ctrl+J is Enter, everywhere'
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-22 15:26'
updated_date: '2026-08-22 15:35'
labels: []
dependencies: []
priority: medium
type: feature
ordinal: 125000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Ctrl+J already means Enter in some programs and not others, which is worse than either extreme: the hand learns it and then it fails in the one place it was needed. zsh (accept-line, ASCII LF), rofi (kb-accept-entry lists Control+j) and qutebrowser (<Ctrl-J>: <Return>) already do it; nvim, fzf, lazygit, GTK dialogs and the browser chrome do not.

Make it unconditional the way Ctrl+K became Escape in TASK-108: a binding in the [control] layer of setup/system/keyd/default.conf, so a real Enter key event is emitted at the evdev layer and every program - including the ones this repository has no config file for - sees exactly what the Enter key sends.

Two things are already known to be in the way and are part of the work, not surprises to discover later:

- sway binds `$mod+Ctrl+j` to `workspace back_and_forth` (50-keybindings.conf:321). keyd strips only the layer own modifier, so Super passes through and that chord would arrive as `$mod+Return`, which launches a terminal. It has to move.
- nvim maps `<C-j>` to `<C-w>j` (init.lua:214). Ctrl+J would shadow it so it could never fire - the same silently-dead mapping TASK-108 removed for `<C-k>`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 What Ctrl+J currently does is recorded per program, gathered by asking each one on this machine rather than from general knowledge, and each loss is marked trivial, rare or daily
- [ ] #2 Ctrl+J emits a real Enter key event below the compositor, proven by observing what keyd emits on its virtual keyboard rather than by reading the config back
- [ ] #3 Pressing $mod+Ctrl+j no longer launches a terminal: that sway binding is either moved to a chord keyd does not rewrite, or deliberately dropped with the reason written down
- [ ] #4 Nothing is left in this repository configuration that Ctrl+J now shadows and can therefore never fire; any displaced binding is either replaced or its loss is written down where the next reader will look
- [ ] #5 Shift, Alt and Super still compose with it, so Ctrl+Shift+J is Shift+Enter, and the existing Ctrl+K, the Alt+hjkl arrows, the Caps Lock scroll layer, the modifier swap and keyd panic sequence are all unaffected
- [ ] #6 ./tools/shortcuts.sh reports the binding, read out of the [control] layer rather than asserting a binding string
- [ ] #7 docs/manual/03-the-keyboard.md describes it, and ./checks/manual.sh, ./checks/session.sh, ./checks/sway-bindings.sh and ./checks/sway-commands.sh all pass
- [ ] #8 setup/system/keyd/default.conf and /etc/keyd/default.conf are identical, so the machine is not running something the repository does not describe
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Complete the per-program cost table for Ctrl+J by asking each program on this machine (zsh bindkey, nvim map dump, fzf man, lazygit --config, rofi -dump-config, qutebrowser configdata.yml, yazi embedded preset via strings, foot.ini man page, sway config, backlog binary strings).
2. Move sways `$mod+Ctrl+j workspace back_and_forth` off a chord keyd rewrites, since it would arrive as `$mod+Return` and launch a terminal.
3. Remove nvims `<C-j>` -> `<C-w>j` mapping, which Ctrl+J would shadow so it could never fire, and say why in its place - the same treatment `<C-k>` got in TASK-108.
4. Add `j = enter` to the [control] layer of setup/system/keyd/default.conf with the cost table and the reasoning written into the file.
5. Validate with `keyd check`, apply to /etc, reload, and prove it with an injected Ctrl+J read back off keyds own virtual keyboard - not by reading the config. The probe must declare a full keyboard key range and abort if keyd logs `ignoring` for it, per the scripting-traps skill.
6. Extend tools/shortcuts.sh to report the binding by READING the [control] layer, not by asserting a string.
7. Update docs/manual/03-the-keyboard.md and run all four checks.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## What Ctrl+J costs, asked of each program on this machine

| Program | Evidence | Ctrl+J was | Weight |
| --- | --- | --- | --- |
| zsh | `zsh -i -c bindkey` -> `"^J" accept-line` | Enter ALREADY | none |
| rofi | `rofi -dump-config` -> `kb-accept-entry: "Control+j,Control+m,Return,KP_Enter"` | Enter ALREADY | none |
| qutebrowser | `configdata.yml:3646` -> `<Ctrl-J>: <Return>` | Enter ALREADY | none |
| less | `man less` -> "ENTER or RETURN or ^N or e or ^E or j or ^J" | Enter ALREADY | none |
| foot | `man 5 foot.ini` | nothing | none |
| yazi | `strings` on the binary: no `<C-j>` at all | nothing | none |
| backlog TUI | `strings`: only Ctrl+S among Ctrl bindings | nothing | none |
| nvim | `init.lua:214` | `<C-w>j`, split below | daily |
| fzf | `man fzf` -> `down  ctrl-j  down` | move selection down | daily |
| lazygit | `lazygit --config` -> `moveDownCommit: [<ctrl+j>, <alt-down>]` | move a commit in a rebase | rare |
| sway | `50-keybindings.conf:321` | `$mod+Ctrl+j workspace back_and_forth` | COLLISION |

Four programs already agreed with it, which is the finding: this binding removes an exception rather than adding a convention. That is why it costs a fraction of what Ctrl+K did.

## The sway collision, and why the sway config was NOT changed

`$mod+Ctrl+j` would have arrived as `$mod+Return` - `exec $term` - so the workspace toggle would have opened a terminal every time, with the sway config still looking correct. The obvious fix was to move the sway binding, and the comment above it argues at length that `j` was chosen deliberately: it sits between `h` and `l` so the directions flank it, and it replaced `$mod+Tab` on purpose.

keyd has a better answer. Composite modifier layers take precedence over the single-modifier one, and a key the composite layer does not name passes through WITH its modifiers - quoted from keyd(1) in the config. So a `[control+meta]` layer keeps the compositor chords out of the application rewrites, and sway keeps its binding untouched.

All four keys bound in `[control]` are listed there, not just `j`, so that adding a sway binding on `$mod+Ctrl+k` (or `f`, or `;`) later cannot spring the same trap silently.

## Implemented

- `setup/system/keyd/default.conf`: `j = enter` in `[control]`, plus the new `[control+meta]` layer with the rule written into it.
- `setup/dotfiles/dot_config/nvim/init.lua`: removed `<C-j>` -> `<C-w>j`, which Ctrl+J shadows so it could never fire. Its comment went from "THREE, NOT FOUR" to "TWO, NOT FOUR" and now names both absences.
- `tools/shortcuts.sh`: new `control_note()`, which READS the enter/tab keys out of the `[control]` layer rather than asserting a binding string, and whose per-key trailers are each guarded on that binding being present.
- `docs/manual/03-the-keyboard.md`: a new section, "Enter and Tab, without leaving the home row".

## Verified so far, without root

- `keyd check setup/system/keyd/default.conf` -> "No errors found", exit 0, with the composite layer present.
- The `control_note` parser run against the new repo file prints `j enter` and `f tab`; run against the current unapplied `/etc` it prints nothing, which is the correct "not there" answer rather than a stale claim.
- `checks/manual.sh` 8 passed / 0 failed. `checks/sway-bindings.sh` exit 0. `checks/sway-commands.sh` "All referenced commands are accounted for". `tools/shortcuts.sh` exits 0.
- `checks/session.sh` reports 84 passed / 4 failed / 1 skipped - and the MAIN checkout reports exactly the same four, so all four are pre-existing on this machine (wallpaper not reloaded, floating-term rule, an empty desktop context, stale deleted dotfiles) and none is caused by this work.

## Not applied to /etc, and the claim is therefore UNPROVEN

Same wall as TASK-108: `sudo -n` refuses, `/etc/sudoers.d` is unreadable, and `keyd bind` cannot reach `/var/run/keyd.socket` without root. `/etc/keyd/default.conf` was ALREADY behind before this work - it is missing the whole Alt+hjkl block from TASK-111 - so applying this brings three tickets to the machine at once.

An apply-and-verify script is prepared. It validates, backs up with the revert line printed, installs, reloads, diffs, then injects chords on a uinput keyboard and reads back what keyd emits on its own virtual keyboard. Per the scripting-traps skill it declares a whole keyboard (codes 1..248) and ABORTS if keyd logs `ignoring` for it, so it cannot report a confident negative while disconnected from what it claims to observe. Its first case is plain `j` - an unbound key, which must reappear - as the grab tell.

The case that matters most is `Super+Ctrl+J`, which must emit `leftctrl+leftmeta+j` and not Enter.
<!-- SECTION:NOTES:END -->
