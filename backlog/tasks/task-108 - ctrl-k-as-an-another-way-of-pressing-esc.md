---
id: TASK-108
title: ctrl + k as an another way of pressing esc
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 12:03'
updated_date: '2026-08-22 12:45'
labels: []
dependencies: []
priority: medium
type: spike
ordinal: 116000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently I have to move my hand to press escape, and use that quite a lot e.g. in vim, even this backlog tool.

It would be nice to have another way to press it without having to move my hands - currently i'm thinking ctrl + k, but im open to suggestions as well.

part of this ticket would involve assessing the impact of the chosen shortcut against other shortcuts in this system, or the tools we've chosen, as well as wider shortcut patterns.

I.e. what shortcuts do we give up by using ctrl + k like this.

What would some other logical options be for this shortcut
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 What Ctrl+K currently does is recorded per program, gathered by asking each one on this machine (zsh, nvim, fzf, lazygit, qutebrowser, yazi, foot, rofi, sway, the backlog TUI) rather than from general knowledge, and each loss is marked trivial or daily
- [x] #2 At least three alternatives to Ctrl+K are assessed with their trade-offs, including a dual-role key, a currently wasted key, and doing it per-application, and one is recommended
- [x] #3 Nothing is left in this repository's configuration that Ctrl+K now shadows and that can therefore never fire; the zsh binding it displaces is either replaced or its loss is written down where the next reader will look
- [x] #4 ./tools/shortcuts.sh reports the new binding, guarded on something that will not silently stop matching if the binding is reworded
- [x] #5 docs/manual/03-the-keyboard.md describes it, and ./checks/manual.sh, ./checks/session.sh, ./checks/sway-bindings.sh and ./checks/sway-commands.sh all pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Ask every candidate program what it binds Ctrl+K to on this machine (bindkey, configdata.yml, lazygit --config, the yazi/foot/rofi defaults, strings on the backlog binary), and record which losses are daily.
2. Assess the alternatives: a plain keyd remap of Ctrl+K, a dual-role key via overloadt2, a currently wasted key (Ctrl+semicolon, right Alt), Caps Lock tap, a j+k chord, and per-application remaps. Recommend one.
3. Implement Ctrl+K -> Escape as a [control] layer binding in setup/system/keyd/default.conf, with the reasoning and the costs written into the file.
4. Compensate the one loss with no replacement: rebind zsh kill-line to Alt+K in dot_zshrc.
5. Remove nvim's <C-k> split-up mapping, which Ctrl+K now shadows so it can never fire, and say why in its place.
6. Validate with keyd check, apply with sudo keyd reload, and prove it with an injected Ctrl+K read back off keyd's own virtual keyboard - not by reading the config.
7. Extend tools/shortcuts.sh with an escape_note alongside scroll_note, guarded on the layer-and-key rather than the whole binding string.
8. Update docs/manual/03-the-keyboard.md and run all four checks.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## What Ctrl+K costs, asked of each program on this machine

| Program | Evidence | Ctrl+K was | Weight |
| --- | --- | --- | --- |
| zsh | `zsh -i -c bindkey` -> `"^K" kill-line` | kill-line, the ONLY binding for it | daily |
| nvim | `init.lua:209` | `<C-w>k`, move to the split above | daily |
| fzf | `man fzf`: `up  ctrl-k  up` | move selection up | daily (Ctrl+R, Ctrl+T) |
| lazygit | `lazygit --config`: `moveUpCommit: [<ctrl+k>, <alt-up>]` | move a commit in a rebase | rare |
| qutebrowser | `configdata.yml:3916,3943` | rl-kill-line, command and prompt modes only | rare |
| rofi | `rofi -dump-config`: `kb-remove-to-eol: "Control+k"` | kill to end of line | rare |
| yazi | embedded preset: `{ on = "<C-k>", run = "kill eol" }` | kill to end of the input line | rare |
| foot | `man 5 foot.ini`: 'Deletes search input after the cursor. Default: Ctrl+k' | scrollback-search only | trivial |
| firefox | convention | focus the search bar | rare (Ctrl+L remains) |
| sway | `checks/sway-bindings.sh` | NOTHING - sway's k is $mod+k | none |
| backlog TUI | `strings` on the binary: only `ctrl+s` appears, and keys are named ("escape", "up") | NOTHING | none |

Three daily losses, all with a replacement already bound except zsh's kill-line, which was moved to Alt+K.

## Alternatives assessed

- **Caps Lock tapped** - the usual answer. Ruled out by revealed preference: the config comments record that tapping was taken away once and deliberately put back. Caps Lock HELD is already the scroll layer and Caps+k is scroll-up.
- **j+k chord** (keyd supports `j+k = esc`) - makes every j and every k wait out chord_timeout before being emitted. Latency on the two keys nvim navigates with. Rejected.
- **A held letter (lettermod/overloadi)** - already rejected in this same file for the scroll layer, for the reason that a held letter silently swallows a character in prose.
- **Right Alt / right Ctrl as a plain Escape** - genuinely wasted keys, but they are thumb/pinky reaches rather than home row, and the gb layout does use AltGr for a few symbols.
- **Ctrl+semicolon** - the zero-cost option. No ASCII control code exists for it, so no terminal program can bind it, and nothing on this machine does. Right little finger, already resting on it. Rejected only because Ctrl+J-is-Enter/Ctrl+K-is-Escape is a better mnemonic, and every Ctrl+K loss has a live replacement. Switching is one word in the config; the shortcuts.sh note follows automatically.
- **Per-application remaps** - fails the requirement outright: the two contexts this was asked for (the backlog TUI, a browser) have no config in this repository to change.

## Implemented

- `setup/system/keyd/default.conf`: a `[control]` layer with `k = esc`, with the full cost table and the rejected alternatives written into the file.
- `setup/dotfiles/dot_zshrc`: `bindkey '\ek' kill-line` - the one loss with no replacement.
- `setup/dotfiles/dot_config/nvim/init.lua`: removed `<C-k>` -> `<C-w>k`, which could never fire again.
- `tools/shortcuts.sh`: `escape_note()`, which READS the key out of the [control] layer instead of asserting a binding string - the failure `scroll_note` records in its own comment.
- `docs/manual/03-the-keyboard.md`: a new section with the cost table.

## Not applied to /etc yet

sudo needs a password and there is no non-interactive path to it on this machine, so `/etc/keyd/default.conf` is still the old file and the emitted-Escape claim is UNPROVEN. Run the prepared script, which validates, backs up, installs, reloads and then injects Ctrl+K on a uinput device and reads back what keyd emits on its virtual keyboard.

## Verification so far

- `keyd check setup/system/keyd/default.conf` -> 'No errors found', exit 0.
- `zsh -c "bindkey -e; bindkey '\\ek' kill-line; bindkey"` -> `"^[k" kill-line`, so Alt+K really is kill-line.
- The escape_note parser run against the new repo file prints `k`; run against the current (unapplied) /etc it prints nothing, which is the correct 'not there' answer rather than a stale claim.
- `./checks/manual.sh` 8 passed / 0 failed; `./checks/sway-bindings.sh` exit 0; `./checks/sway-commands.sh` 'All referenced commands are accounted for'; `./checks/session.sh` 92 passed / 0 failed / 0 skipped.

AC 3, 4, 5 and 7 are UNCHECKED because they can only be proven against a running keyd, and applying the config needs root.

BOTH KEYS BOUND, at the user request, as a trial rather than a design.

The user applied the config at 13:34 - /etc/keyd/default.conf now carries k = esc and keyd reloaded at 13:34:03 - and then asked for Ctrl+semicolon alongside it, to see which one the hand actually reaches for. TASK-110 ends the trial and removes whichever loses; the config comment says so beside the two lines, so a reader who finds both later knows it was on a clock.

AC#7 checked and verified live: tools/shortcuts.sh reports the binding, read out of the [control] layer of /etc rather than asserted. It was rewritten to report ALL keys mapping to esc rather than the first - it stopped at the first match, which would have told a reader something true and useless while two are bound. Verified against the applied /etc: prints Ctrl+K, its per-program cost, and stays silent about semicolon until that reaches /etc. It also states, only when more than one key is bound, that this is a trial.

STILL OPEN, and honestly so:
  * AC#5 - setup/system/keyd/default.conf is ahead of /etc again by the semicolon = esc line. The repository leads the machine, which is the recoverable direction.
  * AC#3 and AC#4 - the user ran the apply-and-verify script, but I have not seen what its probe printed, so I am not checking a criterion on the assumption that it said what it should. The probe now injects plain semicolon and leftalt+semicolon as well as the Ctrl+K cases, so one more run proves both keys at once.

keyd check passes on the two-key config.

CLOSED AS A SPIKE, with the behavioural criteria moved rather than ticked.

The user judgement was that the research this ticket asked for is done, and it is: what Ctrl+K costs was established per program by asking each one on this machine, four alternatives were assessed, and a recommendation was made. Ctrl+K is implemented, applied and in daily use.

Three criteria were REMOVED from here and added to TASK-110 rather than checked, because they were not met and ticking them would have been a lie: that pressing the key emits a real Escape below the compositor proven by observation rather than by reading the config back; that typing, the modifier swap, the scroll layer and the panic sequence all still work; and that the repository file and /etc are identical.

They belong on TASK-110 anyway. That ticket ends the trial, and the trial cannot be judged until both keys are actually live and observed - /etc currently carries k = esc alone, so Ctrl+semicolon is written and not yet applied. Whoever closes TASK-110 has to apply and verify regardless, so the work is not lost, it is where it will actually be done.

The outcome that mattered most here was not the binding but the finding that Ctrl+semicolon costs nothing: there is no ASCII control code for semicolon, so no terminal program CAN bind it, and none on this machine does. Ctrl+K costs three daily bindings, all now replaced - kill-line in zsh moved to Alt+K, the nvim split-above mapping removed, move-up in fzf where the same key now ABORTS instead. That comparison is what TASK-110 decides between, and cost is already settled; only which one the hand reaches for is open.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-08-22 12:26
---
Blocked on one thing only: sudo needs a password and this session has no interactive path to it (`sudo -n true` fails, no /etc/sudoers.d entry, no askpass helper installed). So the repository is ahead of the machine - /etc/keyd/default.conf is still the old file and Ctrl+K does nothing yet.

To close it, run:

    /tmp/claude-1000/-home-vincemaina-Arch/00a28866-e3d8-4da2-a9d3-b0ab619c4773/scratchpad/apply-and-verify.sh

It validates with `keyd check`, backs up the current /etc file (and prints the one-line revert), installs, `sudo keyd reload` (not restart), diffs the two files, then parks focus on an empty workspace on a headless output, injects Ctrl+K on a uinput keyboard that keyd grabs, and reads back what keyd emits on its own virtual keyboard. `./sync.sh` would install it too, but restarts keyd rather than reloading and does not prove anything.

Two things the script cannot press for you and asks you to: Caps Lock held + j still scrolls, and Backspace+Escape+Enter still panics keyd out.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Spike done. Ctrl+K costs three daily bindings, each measured by asking the program rather than assumed, and each replaced; Ctrl+semicolon was found to cost nothing at all, since no ASCII control code exists for semicolon. Ctrl+K is implemented and applied, both keys are now bound for a trial, and the criteria that require observing what keyd emits moved to TASK-110, which ends that trial.
<!-- SECTION:FINAL_SUMMARY:END -->
