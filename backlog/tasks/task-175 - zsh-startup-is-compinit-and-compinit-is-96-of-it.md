---
id: TASK-175
title: 'zsh startup is compinit, and compinit is 96% of it'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-25 11:20'
updated_date: '2026-08-26 10:54'
labels: []
dependencies: []
priority: medium
type: enhancement
ordinal: 182000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
checks/session.sh already fails on this: 'interactive shell takes 971ms'. That figure is a CPU power-profile artefact - the same shell measures 243ms at full clock, inside the check's 400ms pass threshold - but 243ms is still five times what foot itself takes (48ms), so the shell, not the terminal, is what is felt on $mod+Return.

Profiled with zsh/zprof on balanced, and the answer is not the plugins:

    compinit                267.39ms   95.99%
      compdef (903 calls)   130.49ms   46.84%
      compaudit (2 calls)    11.95ms    4.29%
    zsh-syntax-highlighting   9.08ms    3.26%
    everything else          <1ms each

The three evals people usually blame are trivial, timed individually:
starship init 4ms, zoxide init 3ms, fzf --zsh 7ms.

dot_zshrc line 28-30 runs a full 'compinit -d ~/.cache/zsh/zcompdump' on every
interactive shell. The usual remedies are (a) 'compinit -C', which skips the
security audit and the rebuild check, with a full compinit run once a day, and
(b) zcompile on the dump so loading it is not re-parsed each time. Neither has
been tried here yet and both should be measured rather than assumed - compdef
being 903 calls suggests the dump itself is what costs, not the audit.

Worth doing after the power profile question is settled, since that dominates
the absolute numbers.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 zsh -i -c exit is measurably faster, with before and after numbers taken at the same power profile
- [x] #2 Completion still works, including case-insensitive matching and the completion menu, verified by using it rather than by the shell starting
- [x] #3 A newly installed command is still completable without clearing the cache by hand, or the staleness window is written down
- [x] #4 checks/session.sh reports the shell inside its pass threshold at full clock
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add one line to setup/dotfiles/dot_zshrc creating $HOME/.cache/zsh before compinit runs, matching the existing 'mkdir -p ${HISTFILE:h}' idiom a few lines above.
2. Rewrite the comment above compinit: it currently claims the dump is cached, which was false for as long as it existed. Say plainly that compinit does not create the directory and fails silently without it, so the mkdir is not deleted as redundant.
3. Verify honestly on a machine WITHOUT the directory: rm -rf ~/.cache/zsh, confirm gone, take five 'zsh -i -c exit' timings; then start a shell sourcing the edited rc, confirm the directory and zcompdump appear, take five more timings. Record scaling_cur_freq with both sets - TASK-175 exists because an earlier figure was a power-profile artefact.
4. AC #2 (completion works, verified by using it) cannot be driven interactively from a tool call. Prove what is objectively provable - that the written dump carries the completion definitions and that compdef-registered completions resolve in a fresh shell - and leave the AC open with a note saying what a human must do, rather than checking it on the shell merely starting.
5. AC #3: establish what actually happens when a new command is installed, rather than asserting it. compinit's own staleness rule still applies; find out and write it down.
6. Run checks/session.sh and report the shell line. Decide whether docs/manual/ describes shell startup behaviour that is now wrong; if not, record that as the answer rather than padding it.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
FIX APPLIED AND VERIFIED. One line in setup/dotfiles/dot_zshrc - 'mkdir -p "$HOME/.cache/zsh"' immediately before compinit - plus a rewrite of the comment above it, which previously claimed the dump was cached and had been false since it was written. The new comment names the trap (compinit does not create the directory, fails silently, next shell rebuilds) so the mkdir is not deleted as redundant. No run_once_ script, no tmpfiles rule, no XDG helper: the file already creates ${HISTFILE:h} the same way eleven lines above.

MEASUREMENT, and it was NOT taken by trusting the machine's existing state. ~/.cache/zsh was present at the start of this session because the previous investigation created it, so a plain run would have proved nothing about a fresh install. Both sides were measured with the directory deliberately removed first, through matched ZDOTDIR harnesses: /tmp/t175-before/.zshrc is origin/main's dot_zshrc byte-for-byte (confirmed identical to the live ~/.zshrc), /tmp/t175-after/.zshrc is the edited one. Only the mkdir differs.

Machine on AC, power profile 'performance', scaling_cur_freq 3400158 / 3404365 / 3399580 across the runs against a cpuinfo_max_freq of 3400000 - full clock, so these are not the power-profile artefact the description warns about.

  before (unfixed rc, ~/.cache/zsh removed)   248 245 243 243 248 ms
  after, first run (builds the dump)          382 ms
  after, subsequent runs                       50  51  52  51  51 ms
  bare 'zsh -f -c exit' (no rc at all)          2   2   2 ms

246ms -> 51ms, 4.8x, and 51ms against a 2ms floor means the rc itself is now most of what is left rather than compinit being all of it.

THE DIRECT PROOF OF THE SILENT FAILURE, which is worth more than the timings: after five consecutive 'zsh -i -c exit' runs with the unfixed rc, ~/.cache/zsh was still absent. Five shells each built a 55K dump and each threw it away, with nothing on stderr and every shell exiting 0. With the fixed rc the directory and the 55K dump exist after the first run.

COMPLETION WAS ACTUALLY USED, NOT INFERRED (AC #2). Driven through zsh/zpty - a real interactive zsh on a real pty, real TAB keystrokes sent, real terminal output read back. Not 'the shell started'.

  'ls /usr/sha' TAB                 -> /usr/share/
  'ls ~/Projects/arch/claude' TAB   -> CLAUDE.md   (the matcher-list 'm:{a-z}={A-Za-z}';
                                       lowercase typed matched an uppercase name)
  'systemctl --user is-en' TAB      -> is-enabled  (compdef entry loaded from the dump)
  'git chec' TAB                    -> 'git check' (common prefix)
       second TAB                   -> menu opens, grouped and described:
                                       'main porcelain command' / 'plumbing manipulator
                                       command' / 'plumbing internal helper command',
                                       with checkout, checkout-index, check-attr,
                                       check-ignore, check-mailmap, check-ref-format
       third TAB                    -> selection advances, command line becomes
                                       'git checkout'

That last one exercises 'menu select', 'group-name' and the descriptions format together. The identical suite run against the UNFIXED rc with no dump at all produced identical results, which is the control that matters: the dump changes how long completion takes to become available, not what it does.

STALENESS ESTABLISHED BY EXPERIMENT, NOT ASSERTED (AC #3). Read /usr/share/zsh/functions/Completion/compinit lines 491-516 for the rule, then tested it. compinit reads the dump's first line, '#files: N<TAB>version: V', and rebuilds if N differs from the number of completion files it now finds across $fpath, or if $ZSH_VERSION differs. It is a FILE COUNT, not an mtime. Tested with a scratch fpath directory under $HOME (not /tmp - compaudit rejects /tmp's parent permissions and compinit then aborts, which is its own small trap):

  one function present, first run    #files: 1064  dump written, _comps[t175alpha]=_t175alpha
  nothing changed, next run          #files: 1064  mtime unchanged, dump reused
  second function added              #files: 1065  REBUILT automatically, and
                                     _comps[t175beta]=_t175beta in that very shell
  same count, contents rewritten     #files: 1065  NOT rebuilt

So: installing a package that ships a new completion function is picked up by the next shell with no manual step. THE STALENESS WINDOW, written down as the AC allows: a change that leaves the file count identical is not noticed - a package update that revises an existing completion function in place, or one transaction that adds one completion file and removes another. Neither is common, and the remedy is 'rm ~/.cache/zsh/zcompdump' and open a shell. Note this window is created by the fix: before it, nothing was ever cached, so nothing could ever be stale.

WHAT WAS NOT NEEDED. Neither remedy the description proposed. 'compinit -C' skips compaudit, which zprof measured at 11.95ms of 267ms, and it would also switch off the file-count check that AC #3 turns out to depend on - so it would buy under 5% and cost the automatic pickup of new completions. zcompile was an optimisation of loading a dump that was not being written. Both correctly left alone.

CHECKS. checks/session.sh run twice from this worktree at full clock, and the only substantive line that differs between them is the one this task is about:

  ~/.cache/zsh absent (the pre-fix state)   PASS  interactive shell starts in 255ms
                                                  (noticeable; worth watching)
  after one shell with the fixed rc         PASS  interactive shell starts in 52ms

133 passed, 0 failed, 0 skipped, exit 0, on both runs - so nothing else moved. checks/manual.sh: 8 passed, 0 failed.

THE MANUAL DOES NOT NEED CHANGING, and this is the answer rather than a skipped step. docs/manual/ says nothing about shell startup time, compinit or the completion dump. Its only two mentions of 'completion' are neovim's, and its ~/.zshrc references are to the plugin source lines, the PATH export and kill-line. Nothing in it is now wrong, and padding it to satisfy the Stop hook would be worse than leaving it.

ONE THING A HUMAN MIGHT STILL WANT TO DO. This change reaches the running machine only through 'chezmoi apply' via ./sync.sh, which was deliberately not run here - the machine has unrelated uncommitted calendar dotfiles applied to it, and a sync from a worktree would both overwrite that work and re-point chezmoi's sourceDir at a directory about to be deleted (TASK-121.1). ~/.cache/zsh was left in place, so this machine is already fast; the repository is what was fixed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
One line in setup/dotfiles/dot_zshrc - 'mkdir -p "$HOME/.cache/zsh"' before compinit - and a rewrite of the comment above it that had claimed the dump was cached since the day it was written.

compinit does not create the directory its -d dump lives in. It failed to write, silently, with nothing on stderr and every shell exiting 0, so every interactive shell scanned 1306 completion functions across 21 fpath directories and made 903 compdef calls and then discarded the result. The same missing directory made 'zstyle cache-path' dead too, so 'use-cache on' cached nothing; one mkdir fixes both.

Verified with the directory deliberately REMOVED first, because this machine already had it from an earlier investigation and a plain run would have proved nothing about a fresh install. Matched ZDOTDIR harnesses, the 'before' rc byte-identical to origin/main and to the live ~/.zshrc, differing only in the mkdir. On AC at profile 'performance', scaling_cur_freq 3399580-3404365 against a max of 3400000: 248/245/243/243/248 ms before, 382 ms to build the dump once, then 50/51/52/51/51 ms - 4.8x, against a 2ms 'zsh -f' floor. The sharpest evidence is not the timing: after five before-runs the directory was still absent, five dumps built and thrown away.

Completion was used, not inferred. A real interactive zsh driven over zsh/zpty with real TAB keystrokes: '/usr/sha' completed to /usr/share/, 'claude' completed to CLAUDE.md through the case-insensitive matcher-list, 'systemctl --user is-en' to is-enabled from a dumped compdef, and 'git chec' TAB TAB TAB opened the grouped, described menu and advanced the selection to 'git checkout' - exercising menu select, group-name and descriptions together. The same suite against the uncached rc gave identical results, so the dump changes when completion is ready, not what it does.

Staleness read out of compinit's source and then tested: it rebuilds when the count of completion files in $fpath changes, or $ZSH_VERSION does - a count, not an mtime. Adding a file took the dump from #files: 1064 to 1065 and the new completion was live in that same shell with no manual step. The window the fix creates: a change leaving the count identical - a package updating an existing completion function in place, or one transaction swapping one file for another - is not noticed; 'rm ~/.cache/zsh/zcompdump' and open a shell.

checks/session.sh, twice at full clock, differs in exactly one substantive line: 255ms 'noticeable; worth watching' before, 52ms after. 133 passed, 0 failed both times. checks/manual.sh 8 passed, 0 failed. The manual needed no change and that is a finding rather than a skipped step - it says nothing about shell startup, and both its 'completion' mentions are neovim's.

Neither remedy the ticket proposed was needed. 'compinit -C' would have bought under 5% and switched off the very file-count check the new-command behaviour depends on; zcompile optimises loading a dump that was never written.
<!-- SECTION:FINAL_SUMMARY:END -->
