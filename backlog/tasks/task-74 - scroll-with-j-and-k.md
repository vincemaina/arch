---
id: TASK-74
title: scroll with j and k
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-21 11:55'
updated_date: '2026-08-22 00:58'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 76000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
it would be nice if there were some universal way of scrolling with j + K. currently the issue is some tool support scrolling that way others don't. and even the ones that do sometimes don't work, for example if you're in an input field.

for some reason im thinking we could start to make use of some more advanced keyd stuff here. maybe have it so that if you tap f, then f behaves like f. But if you hold it (without pressing ctrl, shift, mod or anything like that), then pressing j and k function as page up and page down buttons.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Holding one key makes j and k scroll, in a program with no j/k support and with the caret inside a text input field
- [ ] #2 A second binding scrolls by keyboard focus rather than pointer position, so the feature still works when the pointer is over another window
- [ ] #3 Holding the scroll key continues to scroll rather than emitting a single step
- [x] #4 The trigger key introduces no tap-hold ambiguity on any key used while typing, in a terminal, in nvim, or on the rescue console
- [x] #5 setup/system/keyd/default.conf passes 'keyd check', and the gate is shown to fail on a deliberately broken copy
- [x] #6 ./checks/session.sh still reports 0 failures
- [ ] #7 The shortcuts are written down where a reader will find them, rather than being discoverable only by accident
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Read setup/system/keyd/default.conf and the keyd(1) manual for the tap-hold actions (overload, overloadt, overloadt2, overloadi, lettermod).
2. Decide the trigger key on evidence, not on the sketch. Weigh f against Caps Lock for misfire risk while typing, behaviour in nvim (f is find-character), key repeat, and behaviour on the rescue console, which this same file governs.
3. Decide what the layer emits. Page Up/Down alone does not meet the stated goal because it moves the caret inside a text field; mouse wheel events do, and keyd already runs a virtual pointer.
4. Confirm keyd's virtual pointer actually advertises REL_WHEEL before relying on scrollup/scrolldown.
5. Add the layer to setup/system/keyd/default.conf with the reasoning in the file.
6. Validate with 'keyd check' against the repository file, and prove the gate goes red by breaking a copy in both directions.
7. Re-run ./checks/session.sh. Draft the DECISIONS.md entry and the tools/shortcuts.sh text for the owning agents.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Recommendation: build it, but not on f

The outcome is worth having and keyd is the right layer for it. The trigger key
in the sketch is not, and Page Up/Down alone does not deliver what was asked
for. Both were changed, with reasons.

### Not f

Overloading a letter turns every press of it into a tap-hold decision. keyd's
letter-safe form is `lettermod(scroll, f, 150, 200)`, which expands to
`overloadi(f, overloadt2(scroll, f, 200), 150)` and resolves an f struck within
150ms of the previous key as a plain f immediately. That covers mid-word f
entirely - 'off', 'affix', 'of' are all safe.

What it does not cover is an f that STARTS a word after any pause, which is
every f at the beginning of a sentence and every f after a moment's thought.
That press falls to `overloadt2`, and overloadt2 resolves as a HOLD on any
intervening key tap. Type 'For' after a pause with a normal rolled overlap and
the f is swallowed: the o falls through the layer unbound and you get 'or'. A
silently dropped character in prose, indistinguishable from a failing keyboard.

Plain `overloadt` avoids the intervening-tap rule but queues the following
keystrokes until the timeout expires, so it trades the dropped character for a
visible typing stall on every sentence-initial f.

nvim makes it worse rather than better: f is find-character, and bare
`f<char>` is used precisely in the after-a-pause position that falls to the
tap-hold branch. df) and ct" are safe because the operator key resets the idle
timer, but the bare form is the common one. nvim also already has C-d, C-u,
C-f, C-b and j/k, so the feature buys nothing there and costs a core motion.

Two further costs: holding f no longer auto-repeats f, and this file is read by
the console and the greeter as well, so an ambiguous letter is ambiguous on the
rescue VT - which the existing comment in this file already argues is the
context that matters most.

### Caps Lock instead

Caps Lock is bound nowhere in this repository (grepped across
setup/dotfiles/dot_config/sway/ and setup/system/), is never struck while
typing, has no repeat behaviour worth keeping, and is the key keyd's own manual
uses for exactly this. Every cost above becomes zero.

Trade-off, stated rather than hidden: Caps Lock stops locking caps. Shift is
the replacement. `layer(scroll)` rather than `overload(scroll, capslock)`
because overload would keep the old function at the price of a
hold-then-think-better-of-it silently latching caps on release, which is this
repository's named failure mode.

### Wheel events, not just Page Up/Down

The ticket asked for something that works inside a text input field. Page Down
inside a text field moves the caret, not the view, so Page Down alone does not
answer the ticket.

A mouse wheel event does: it is delivered to the surface under the pointer and
ignores keyboard focus entirely, so it scrolls a textarea with the caret in it
and scrolls programs with no keyboard scrolling at all. keyd already runs a
virtual pointer, and it was checked rather than assumed that it can carry a
wheel:

    $ awk '/keyd virtual pointer/,/^$/' /proc/bus/input/devices
    B: REL=147

0x147 sets bit 8 (REL_WHEEL) and bit 6 (REL_HWHEEL), so both axes are already
advertised on the device keyd creates, and sway routes them like any mouse.

The cost of a wheel event is the other side of the same coin: it goes where the
pointer is, and sway's default mouse_warping is 'output', so keyboard-driven
focus changes inside one output leave the pointer behind. That is why d and u
emit Page Down and Page Up as well - those follow keyboard focus and are the
answer when the pointer is over some other window. Neither mechanism reaches
everything; the layer carries both on purpose.

### macro2 rather than a bare mapping

`j = scrolldown` would emit exactly one wheel click however long j is held.
Auto-repeat is generated by the compositor from a key being held down, and a
wheel event has no press and no release for it to work from. `macro2(250, 40,
scrolldown)` makes keyd repeat it: one click immediately, then every 40ms after
250ms. Those numbers are sway's own repeat_delay 250 / repeat_rate 40 from
10-input.conf, so holding j feels like holding an arrow key.

### Validation, and its limit

There is no sudo in this session and /var/run/keyd.socket is root:root 0660, so
`keyd do` and `keyd bind` both refuse to connect - the config could not be
loaded or live-tested, by design. What is available is `keyd check`, which
reads a file and needs no socket:

    keyd check setup/system/keyd/default.conf     -> No errors found. exit=0

and it was proven to go red on this exact file, in both directions:

    capslock = layer(scrol)          -> 'scrol is not a valid layer'   exit=255
    macro2(250, 40, scrolldwn)       -> 'Invalid macro'                exit=255

Worth being explicit about what that does and does not prove: keyd check is a
parser, not a simulator. It proves the file will not leave the machine without
a keyboard. It cannot prove the scroll actually scrolls - that needs the user
to run ./sync.sh, which is also what setup/system/apply-config.sh gates on the
same keyd check before enabling or restarting.

./checks/session.sh: 81 passed, 0 failed (the count is 81 rather than the 80
baseline because a check was added in a parallel session; nothing regressed).
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-08-22 00:58
---
Left In Progress rather than Done on purpose. Acceptance criteria 1, 2 and 3 describe behaviour that cannot be observed until the config is loaded, and this session has no sudo (/var/run/keyd.socket is root:root 0660, so keyd do and keyd bind both refuse). Criterion 7 needs DECISIONS.md and tools/shortcuts.sh, which are owned by other agents this session - draft text handed back in the report. Move to Done once ./sync.sh has been run and Caps Lock+j/k has been tried in Firefox, a text input and a GTK dialog.
---
<!-- COMMENTS:END -->
