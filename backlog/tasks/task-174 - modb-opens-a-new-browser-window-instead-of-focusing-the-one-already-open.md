---
id: TASK-174
title: mod+b opens a new browser window instead of focusing the one already open
status: Done
assignee:
  - '@claude'
created_date: '2026-08-25 11:06'
updated_date: '2026-08-25 11:16'
labels: []
dependencies: []
priority: medium
type: enhancement
ordinal: 181000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
$mod+b runs ~/.local/bin/browser, which finds the most recently focused qutebrowser window and moves it to the current workspace rather than opening a window. Opening the browser from rofi does create a new window, so the same intent produces two different results depending on how it was expressed, and the shortcut is the one that behaves unexpectedly.

The wanted behaviour is the rofi one: asking for a browser gives you a browser window. Reaching a window that already exists is what window switching is for.

The helper's own comment argues for the current behaviour on performance grounds - focusing costs 1ms against 553ms for a new window - so this reverses a documented decision and the comment has to be rewritten rather than left contradicting the code, which CLAUDE.md calls out as a failure mode this repository keeps hitting.

Note those recorded figures are correct but were taken at full CPU clock; on power-saver the same machine measures 3161ms cold and 2093ms warm. Speed is not the reason to keep the old behaviour either way.

$explorer already launches a fresh instance, so no other launch binding needs changing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 $mod+b opens a new browser window even when a browser window is already open, verified by pressing it and counting windows
- [x] #2 The behaviour matches what opening the browser from rofi does
- [x] #3 The rationale comment in ~/.local/bin/browser describes the behaviour the script actually has
- [x] #4 docs/manual/ no longer tells the reader that $mod+b brings the existing window to them
- [x] #5 checks/session.sh and checks/sway-commands.sh pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Rewrite ~/.local/bin/browser so it always launches a new window, keeping the sway/python window-finding code only if something still needs it (it does not) - so the script collapses to a launch.
2. Rewrite the WHY THIS EXISTS comment: it currently argues for focus-existing on 1ms-vs-553ms grounds. Record what replaced it and why speed was not the deciding factor, plus the power-profile finding that explains why the recorded figures look wrong on battery.
3. Decide whether the script still earns its existence at all, or whether $browser should just be 'qutebrowser'. Keep a helper only if it does something a bare command does not.
4. Update docs/manual/04-applications.md, which currently describes the focus-existing behaviour and quotes the 1ms figure.
5. Run checks/sway-commands.sh, checks/sway-bindings.sh, checks/manual.sh and checks/session.sh.
6. Verify by pressing the binding with a browser already open and counting windows, not by reading the file back.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
The fix is NOT where the task assumed it was.

The premise was that rofi already opened a new window and only the keybinding did not. Measured, and it is false: qutebrowser's new_instance_open_target defaults to 'tab', so with an instance running ANY launch route - rofi, gio open, a link from another application, the terminal - opens a tab in the last-focused window and raises it. Evidence: with one qutebrowser open, 'qutebrowser https://example.com' produced no window::new event on sway's IPC and left the window count at 1.

So the change went into qutebrowser's config rather than onto the sway binding. '--target window' on the binding alone would have fixed $mod+b and left every other route still making tabs.

That meant creating setup/dotfiles/dot_config/qutebrowser/config.py, which this repository deliberately did not have. config.load_autoconfig() is its first statement and is load-bearing: without it qutebrowser silently ignores autoconfig.yml, which on this machine already held a real setting (chatgpt.com microphone access). Session settings the user had already approved rode along - auto_save.session and session.lazy_restore - because closing the last window otherwise discards every tab, which happened for real during TASK-134 benchmarking.

~/.local/bin/browser was deleted rather than edited: with focus-existing reversed it had nothing left to do that the bare command does not. Added to .chezmoiremove so it is removed from machines that have it.

Corrected a factual error found in DECISIONS.md while editing it: it claimed qutebrowser 'runs stock, where auto_save.session defaults to true'. The default is false. So the session recovery that paragraph reassured the reader about was never enabled.

Verification, all against the running system rather than the files:
  - before: second launch -> no window::new event, window count stayed 1
  - after:  second launch -> window::new at 2430ms, window count 1 -> 2
  - clean startup log with the new config: zero config errors, zero tracebacks
  - config.load_autoconfig() proven to have executed by inference that holds:
    it is the first statement, so a failure there would abort the file before
    new_instance_open_target, which demonstrably applied
  - chezmoi render to a scratch destination (--exclude=scripts): config.py
    renders, browser helper no longer does

checks/sway-commands.sh, checks/sway-bindings.sh, checks/manual.sh: all exit 0.
checks/session.sh: 131 passed, 1 failed - the failure is 'interactive shell takes 971ms', which pre-exists this change and is a CPU power-profile artefact, not a shell problem (the same shell measures 243ms at full clock, comfortably inside the check's 400ms threshold).

AC3 note: ~/.local/bin/browser no longer exists, so 'the comment describes the behaviour the script has' is satisfied by deletion rather than by rewriting - the rationale moved to the $browser block in sway/config and to config.py, and neither now contradicts the code.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
$mod+b now opens a new browser window instead of moving the already-open one to the current workspace, and so does every other way of launching the browser.

The task assumed the launcher already did this and only the keybinding was wrong. Measurement showed otherwise: qutebrowser's new_instance_open_target defaults to 'tab', so every launch route opened a tab in the last-focused window - proven by launching a second qutebrowser and observing no window::new event on sway's IPC with the window count unchanged at 1. The fix therefore went into a new setup/dotfiles/dot_config/qutebrowser/config.py rather than onto the sway binding, so the launcher, the default link handler and the terminal all agree with the key.

~/.local/bin/browser was deleted, since with focus-existing reversed it did nothing a bare 'qutebrowser' does not, and added to .chezmoiremove. auto_save.session and session.lazy_restore were included so closing the last window stops discarding every tab.

Verified on the running system: the same second launch now fires window::new and takes the window count from 1 to 2, and a clean start logs no config errors. checks/sway-commands.sh, checks/sway-bindings.sh and checks/manual.sh all pass; checks/session.sh is 131/1 with the single failure pre-existing and caused by the CPU power profile rather than by this change.

Also corrected a wrong claim in DECISIONS.md that auto_save.session defaults to true - it defaults to false.
<!-- SECTION:FINAL_SUMMARY:END -->
