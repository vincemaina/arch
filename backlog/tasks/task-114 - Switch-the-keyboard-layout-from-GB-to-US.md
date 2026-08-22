---
id: TASK-114
title: Switch the keyboard layout from GB to US
status: In Progress
assignee:
  - '@vincemaina'
created_date: '2026-08-22 14:02'
updated_date: '2026-08-22 14:06'
labels: []
dependencies: []
priority: medium
ordinal: 122000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The physical keyboards this machine will be used with are moving to ANSI, so the layout should follow now rather than at the moment the hardware changes - muscle memory is the thing being retrained, and it is retrained by using it.

Two tracked files carry the layout today: sway's `xkb_layout gb` in `setup/dotfiles/dot_config/sway/config.d/10-input.conf`, and `KEYMAP="uk"` in `setup/install.conf`, which `03-system.sh` writes to `/etc/vconsole.conf` for the text console.

The greeter is a third context and sets no layout at all: greetd runs cage/regreet with no XKB variables, so libxkbcommon's default (`us`) has always applied there. The login screen and the session have therefore disagreed about every symbol key since this was first configured - the change closes that gap rather than opening one.

The locale stays `en_GB.UTF-8`: it governs dates, paper size and currency, not keys.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 sway's input config declares xkb_layout us, and the running compositor reports it
- [x] #2 install.conf declares KEYMAP="us", so a fresh install gets a US text console
- [ ] #3 The running machine's /etc/vconsole.conf agrees (applied by hand; sync.sh has no path for KEYMAP)
- [x] #4 The manual's keyboard chapter names the layout
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. sway: xkb_layout gb -> us in setup/dotfiles/dot_config/sway/config.d/10-input.conf, with a comment saying why the layout is declared at all and that the greeter defaults to the same thing.
2. install.conf: KEYMAP="uk" -> "us", so a fresh install's text console agrees.
3. Manual chapter 3: a short section naming the layout, since that chapter already documents everything else the keyboard does before Sway sees it.
4. Apply to the running machine: swaymsg input type:keyboard xkb_layout us for the session now (no root), and hand the user the one root command for /etc/vconsole.conf - sync.sh has no path for KEYMAP, so the console cannot be reconciled from the repo.
5. Verify with swaymsg -t get_inputs (xkb_active_layout_name), then checks/session.sh and checks/manual.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified, not assumed.

Layout, live: `swaymsg input type:keyboard xkb_layout us` applied to the running session, and `swaymsg -t get_inputs` now reports `"xkb_active_layout_name": "English (US)"` for every keyboard. That is the runtime trial; the tracked change is the config line, which reaches the machine on the next `./sync.sh`.

The greeter claim was checked rather than reasoned about: `xkbcli compile-keymap --test --verbose` with no arguments reports `rules 'evdev', model 'pc105', layout 'us'`. So the login screen really has been US all along, and the session was the odd one out.

The key differences in the manual were read out of the two compiled keymaps (`xkbcli compile-keymap --layout gb|us --model pc105`) rather than remembered. Two of them were the opposite of what memory suggested: on ISO hardware the key labelled `#`/`~` becomes backslash and pipe, and the key labelled `\\`/`|` becomes `<` and `>`.

No shortcut moved. The only non-alphanumeric keysyms bound anywhere in sway's config are `minus`, `equal` and `slash`, and all three are identical in both keymaps (AE11, AE12, AB10).

Checks: `checks/session.sh` 92 passed / 0 failed, `checks/manual.sh` 8 passed / 0 failed, `checks/sway-bindings.sh` 76 bindings and no duplicates.

AC #3 is deliberately unchecked: /etc/vconsole.conf needs root and this session has no passwordless sudo. The text console is still on `uk` until a human runs it.

Follow-up raised as TASK-115: sync.sh has no path for KEYMAP, which is why AC #3 needs a human.
<!-- SECTION:NOTES:END -->
