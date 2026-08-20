---
id: TASK-39
title: Separate machine-local dotfile changes from the reproducible build
status: Done
assignee:
  - '@claude'
created_date: '2026-08-20 14:20'
updated_date: '2026-08-20 14:25'
labels:
  - dotfiles
  - repo
dependencies:
  - TASK-14
priority: medium
type: feature
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Editing a chezmoi-managed file on a machine leaves that machine diverged from the repository with no path back except remembering to fold the change in by hand. It surfaced when a PATH line added to ~/.zshrc while installing a tool turned the next sync into an interactive conflict prompt, and it raised the general question: does every local change have to become part of the standard build?

It should not have to. Three kinds of divergence are being conflated, and only the middle one is currently expressible:

Universal - belongs in the repository and every machine should have it. The PATH line was actually this: setup/dotfiles/dot_local/bin/ installs executables and nothing ever puts that directory on PATH, so every machine built from this repository has helper scripts that cannot be run by name.

Per-machine but declared - laptop against VM against desktop. That is TASK-14, and divergence there lives in git and survives a rebuild.

Machine-local scratch - genuinely not worth standardising, and there is no mechanism for it at all today. Anything in this category has to be typed into a managed file, which is what creates the conflict.

The proposal is a drop-in the repository ships but does not own: dot_zshrc sources ~/.config/zsh/local.zsh when it exists, and a .chezmoiignore keeps chezmoi from ever writing, diffing or removing it. Machine-local work goes there, conflicts become structurally impossible rather than handled at sync time, and .zshrc itself stays fully managed so shell changes can still reach every machine.

Keeping .zshrc unmanaged and merely checking that an import line is present was considered and rejected: it gives up the ability to push a shell change at all, and enforcing a line inside an unmanaged file needs a modify_ script, which is more machinery for less.

Separately, sync.sh runs a plain chezmoi apply, which prompts when a target has been modified. With no TTY - over ssh, from a script - that blocks forever rather than failing. Same shape as the invisible failures this repository keeps finding: it works right up until it is run the way it was meant to be run.

The rule that falls out, and the reason this is worth writing down rather than just coding: put things in the local file that you are content to lose on a rebuild. Anything you would be annoyed to lose is by definition universal or declared per-machine, and belongs in git.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A machine built from this repository has ~/.local/bin on PATH, so the helper scripts it installs can be run by name
- [x] #2 A machine-local shell change can be made without diverging from a chezmoi-managed file
- [x] #3 The local drop-in is never written, diffed or removed by chezmoi
- [x] #4 sync.sh cannot hang when run without a TTY, and says what is wrong instead
- [x] #5 sync.sh tells the user how to fold a local change back into the repository when it finds one
- [x] #6 The three categories and the rule for choosing between them are recorded in DECISIONS.md
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add the PATH entry to dot_zshrc, guarded so a nested shell cannot duplicate it. Nothing system-wide provides it: /etc/profile only appends /usr/local/bin, and the systemd user environment does not carry it either, so today it exists only where it was typed by hand.

2. Add the local drop-in to dot_zshrc, sourced last so it can override anything the repository sets, and only when readable so a machine without one is unaffected.

3. Add setup/dotfiles/.chezmoiignore listing the drop-in, so chezmoi never writes, diffs or removes it. Verify it is genuinely ignored rather than assumed to be, by rendering to a scratch destination and confirming the file is untouched.

4. sync.sh: prompt only when there is a TTY, and pass --error-on-conflict otherwise so a scripted or ssh run fails loudly instead of blocking on a prompt nobody can answer.

5. sync.sh: when a managed file differs, print the chezmoi re-add command for it, so folding a local change back is one command rather than something to look up.

6. Record the decision in DECISIONS.md next to the existing chezmoi entries, in the house style, including the rejected alternative of leaving .zshrc unmanaged.

7. Verify by rendering templates to a scratch destination, running sync.sh --dry-run, and running checks/session.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
The PATH line turned out to be a build gap rather than a personal preference. Nothing puts ~/.local/bin on PATH on this system: /etc/profile only appends /usr/local/bin, and the systemd user environment does not carry it. It existed on this machine solely because it had been typed in by hand, so every machine built from this repository had dot_local/bin/ helpers that could not be run by name. Sway bindings and the swayidle unit call them by absolute path, which is why nothing ever reported it.

Guarded with a case test rather than a bare prepend, so a nested shell cannot stack duplicates.

sync.sh had a latent hang. It ran a plain chezmoi apply, which prompts when a target was edited since chezmoi last wrote it - fine in a terminal, and a permanent block over ssh or from a script. It now prompts only when stdin is a TTY and passes --error-on-conflict otherwise.

--error-on-conflict was then found to exit 1 and print nothing at all, which under set -e would have ended a scripted run with no explanation - trading a hang for a silent failure, which is the pattern this repository keeps finding rather than a fix for it. sync.sh now catches that exit and prints what conflicted and the three ways out.

Verification. Ignore: rendered to a scratch destination with a local.zsh already present; the file survived byte-identical and chezmoi managed reports zero matches for it. PATH guard: the rendered block executed twice in one clean shell yields a single entry. Conflict hint: observed in ./sync.sh --dry-run against a deliberately modified ~/.zshrc. No-TTY behaviour: chezmoi apply --error-on-conflict exits 1 with the file untouched rather than prompting, and ./sync.sh --dry-run under < /dev/null completes rather than blocking. The message branch was executed by extracting it from sync.sh itself with the chezmoi call forced to fail, so the text checked is the text in the script. Also ran checks/session.sh (34 passed, 0 failed), checks/sway-commands.sh and checks/sway-bindings.sh, all passing.

The users existing ~/.zshrc was reconciled rather than left diverged: it differed by exactly the one PATH line, which the repository now supersedes, so it was overwritten after backing it up. chezmoi status is clean.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Separated machine-local dotfile changes from the reproducible build. dot_zshrc now puts ~/.local/bin on PATH - a real gap, since nothing else on the system does and the repository installs executables there - and sources ~/.config/zsh/local.zsh, which a new .chezmoiignore keeps chezmoi from writing, diffing or removing. Machine-local work goes in the drop-in, so conflicts become impossible rather than handled, while .zshrc stays fully managed and shell changes can still reach every machine. sync.sh no longer hangs without a TTY, and explains the conflict instead of failing silently, and it now prints the chezmoi re-add command for each differing file. DECISIONS.md records the three categories, the rule for choosing between them, and the rejected alternative of leaving .zshrc unmanaged. Verified by scratch-destination render, an idempotency test of the PATH guard, an induced conflict under both a TTY and /dev/null, and all three check scripts passing.
<!-- SECTION:FINAL_SUMMARY:END -->
