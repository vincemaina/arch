---
id: TASK-175
title: 'zsh startup is compinit, and compinit is 96% of it'
status: To Do
assignee: []
created_date: '2026-08-25 11:20'
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
- [ ] #1 zsh -i -c exit is measurably faster, with before and after numbers taken at the same power profile
- [ ] #2 Completion still works, including case-insensitive matching and the completion menu, verified by using it rather than by the shell starting
- [ ] #3 A newly installed command is still completable without clearing the cache by hand, or the staleness window is written down
- [ ] #4 checks/session.sh reports the shell inside its pass threshold at full clock
<!-- AC:END -->
