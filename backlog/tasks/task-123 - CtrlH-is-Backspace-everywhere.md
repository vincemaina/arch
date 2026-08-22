---
id: TASK-123
title: 'Ctrl+H is Backspace, everywhere'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-22 16:13'
updated_date: '2026-08-22 16:40'
labels: []
dependencies:
  - TASK-119
priority: medium
type: feature
ordinal: 128000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The third of the same family, and the same shape as TASK-119: Ctrl+H is ALREADY Backspace wherever ASCII reaches, because 0x08 is backspace. zsh (backward-delete-char), rofi (kb-remove-char-back lists Control+h), fzf (backward-delete-char), yazi (`backspace`) and qutebrowser in command and prompt modes all do it today. It is not Backspace in nvim, in GTK dialogs, in the browser chrome or in the greeter.

Bind it in the [control] layer of setup/system/keyd/default.conf so it arrives inside every program, removing the exception rather than adding a convention.

Two things are known to be in the way, and the second is the rule from TASK-119 coming due exactly as that config predicted it would:

- nvim maps `<C-h>` to `<C-w>h` (init.lua). Ctrl+H would shadow it so it could never fire - the same silently-dead mapping already removed for `<C-k>` and `<C-j>`.
- sway binds `$mod+Ctrl+h` to `workspace prev_on_output` (50-keybindings.conf:291). It needs a line in the [control+meta] layer or it arrives as `$mod+BackSpace`. The config comment there says: "Add a key to [control] and it needs a line here too, or a sway binding on $mod+Ctrl+<that key> silently starts doing something else." This is that case.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 What Ctrl+H currently does is recorded per program, gathered by asking each one on this machine, and each loss is marked trivial, rare or daily
- [x] #2 Ctrl+H emits a real Backspace key event below the compositor, proven by observing what keyd emits rather than by reading the config back
- [x] #3 Pressing $mod+Ctrl+h still switches to the previous workspace rather than sending Backspace, confirmed from sway own binding events
- [x] #4 Nothing is left in this repository configuration that Ctrl+H now shadows and can therefore never fire
- [x] #5 The Alt+h left arrow and the Caps Lock + h horizontal scroll are both unaffected, since a layer only takes the keys it names in the modifier it owns
- [x] #6 tools/shortcuts.sh reports it, read out of the [control] layer rather than asserted
- [x] #7 docs/manual/03-the-keyboard.md describes it, and all four checks pass
- [x] #8 setup/system/keyd/default.conf and /etc/keyd/default.conf are identical
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## What Ctrl+H costs, asked of each program on this machine

| Program | Evidence | Ctrl+H was | Weight |
| --- | --- | --- | --- |
| zsh | `bindkey` -> `"^H" backward-delete-char` | Backspace ALREADY | none |
| rofi | `-dump-config` -> `kb-remove-char-back: "BackSpace,Shift+BackSpace,Control+h"` | Backspace ALREADY | none |
| fzf | `man fzf` -> `backward-delete-char  ctrl-h ctrl-bspace bspace` | Backspace ALREADY | none |
| yazi | embedded preset -> `{ on = "<C-h>", run = "backspace" }` | Backspace ALREADY | none |
| qutebrowser (cmd/prompt) | `configdata.yml:3923,3949` -> rl-backward-delete-char | Backspace ALREADY | none |
| foot / lazygit / backlog TUI | asked, nothing bound | nothing | none |
| nvim | `init.lua` | `<C-w>h`, split left | daily |
| qutebrowser (normal) | `configdata.yml:3830` -> `home` | go to the homepage | rare |
| firefox | convention | History sidebar | rare - Ctrl+Shift+H remains |
| sway | `50-keybindings.conf:291` | `$mod+Ctrl+h workspace prev_on_output` | COLLISION |

Five programs already agreed, for the same reason as Ctrl+J: ASCII 0x08 IS backspace. The cheapest of the three chords bound this session - it does not even change a behaviour the way Ctrl+J changed fzf.

## The rule from TASK-119 came due, and it was written down before it was needed

The [control+meta] layer carries a note saying that any key added to [control] needs a line there too, or a sway binding on `$mod+Ctrl+<key>` silently starts doing something else. `h` is the first time that has been claimed rather than hypothetical: without its line, `$mod+Ctrl+h` would have arrived as `$mod+BackSpace` and the previous-workspace binding would have died silently.

That note has been updated to say it has now been claimed once, since a warning that has actually caught something reads differently from one that has not.

## APPLIED AND PROVEN

| chord | keyd emitted | verdict |
| --- | --- | --- |
| Ctrl+H | `+leftctrl -leftctrl +backspace -backspace +leftctrl -leftctrl` | Backspace, control released around it |
| Super+Ctrl+H | `+leftmeta +leftctrl +h -h -leftctrl -leftmeta` | the RAW chord, not Backspace |
| Alt+h | `... +left -left ...` | still the Left arrow |
| Caps+h | 1 wheel event, horizontal negative | still horizontal scroll |

Both neighbours survive, which was the specific worry: three different layers now bind `h`, and each only takes it in the modifier it owns.

## Checks

`checks/manual.sh` 8 passed / 0 failed. `checks/sway-bindings.sh` exit 0. `checks/sway-commands.sh` clean. `checks/session.sh` 85 passed / 3 failed / 1 skipped, all three pre-existing. `tools/shortcuts.sh` prints Ctrl+H alongside Ctrl+J and Ctrl+F, read out of /etc.

## AC#3 confirmed from sway own binding events

`swaymsg -t subscribe [binding]` while Super+Ctrl+H was injected:

    { "change": "run", "binding": { "command": "workspace prev_on_output",
      "event_state_mask": [ "Control", "Mod4" ], "symbol": "h" } }

So sway ran its own binding rather than receiving a Backspace. As with $mod+Ctrl+j in TASK-119, the focused workspace did not visibly change - `prev_on_output` has nowhere to go with one workspace on this output - which is why the IPC event was consulted instead of the workspace list. A no-op with a real cause is indistinguishable from a dead binding from the outside.

Other binding events in the same capture (Mod4+Shift+h, Mod4+Shift+space) were the user working on the machine while the probe ran, not the injection.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Ctrl+H now emits a real Backspace key event at the evdev layer, from the same [control] layer as Ctrl+J, Ctrl+F and Ctrl+K, applied and verified by injection.

It is the cheapest of the three chords bound this session, and for the reason the family keeps repeating: ASCII 0x08 IS backspace, so zsh, rofi, fzf, yazi and qutebrowser command and prompt modes already deleted backwards on it. Only the graphical half disagreed. It costs nvim split-left mapping (removed - Ctrl+W then h still reaches it), qutebrowser normal-mode homepage shortcut, and Firefox history sidebar, which Ctrl+Shift+H still opens.

The result worth keeping is that the [control+meta] rule paid for itself. That layer carried a written warning that any key added to [control] needs a line there too, or a sway binding on $mod+Ctrl+<key> silently starts doing something else. h is the first key to claim it: without its line, $mod+Ctrl+h would have arrived as $mod+BackSpace and the previous-workspace binding would have died quietly. sway own binding events confirm it runs "workspace prev_on_output", and the probe confirms keyd emits the raw chord rather than Backspace.

Three layers now bind h - Backspace under Control, Left under Alt, horizontal scroll under Caps Lock - and all three were re-checked live. Each takes the key only in the modifier it owns.
<!-- SECTION:FINAL_SUMMARY:END -->
