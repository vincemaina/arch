---
id: TASK-37
title: 'Explore making git part of the build: identity and preferences'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-20 13:43'
updated_date: '2026-08-21 21:04'
labels:
  - dev
  - dotfiles
dependencies: []
priority: low
type: spike
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Committing on a machine freshly built from this repository fails: git has no user.name or user.email, because nothing under setup/ ever sets them. It surfaced the way most bugs here surface - it looked configured right up until it was used. Setting it by hand works, and then has to be remembered again on the next machine.

The idea is to make git configuration part of the build rather than something redone per machine: the identity, and the preferences that otherwise get answered wrong under time pressure - pull strategy (merge, rebase or ff-only), default branch name, push behaviour, and whatever else earns its place.

This is user configuration, so a dot_gitconfig under setup/dotfiles/ is the obvious home, and it would reach a running machine through sync.sh like anything else. But identity is per-machine rather than universal, which puts it next to TASK-14 (chezmoi templating for per-machine values and profiles). That overlap wants resolving, not duplicating.

Two things to weigh honestly. Committing an identity into a public repository publishes an email address that the commit history already exposes anyway, so the cost is low - but it should be a deliberate choice rather than a side effect. And CLAUDE.md is explicit that a dotfile is only committed once there is a meaningful customisation worth preserving: a gitconfig holding nothing but a name and an email may not clear that bar, while one that also settles merge and rebase behaviour probably does.

Raised as an idea rather than a request. Needs discussing before anything is committed to.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 It is decided whether git configuration belongs in the build at all, and deciding against it counts as completing this
- [x] #2 The split between what is universal and what is per-machine is settled against TASK-14 rather than duplicated
- [x] #3 Every preference encoded is named with a reason, rather than a generic gitconfig being copied in wholesale
- [x] #4 Publishing an identity in a public repository is an explicit recorded decision, either way
- [x] #5 If it goes ahead, a machine built from scratch can commit without any manual git configuration
- [x] #6 The outcome is recorded in DECISIONS.md
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify the premise: does a machine with no gitconfig actually fail, and where does this machine's identity come from?
2. Settle committed-vs-prompted against the two existing precedents (install.conf is committed; passwords are interactive).
3. Settle the TASK-14 overlap: decide whether git identity is genuinely per-machine, rather than assuming it.
4. Add GIT_NAME/GIT_EMAIL to setup/install.conf and a dot_gitconfig.tmpl that reads them, so there is one source and both install paths get it.
5. Encode only preferences with a demonstrated failure behind them; name what is deliberately NOT set.
6. Verify by rendering to a scratch destination and by exercising each setting in a throwaway repo with a fake HOME.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
EVIDENCE (all re-run, not assumed).

The premise holds. A HOME with no gitconfig cannot commit: "Author identity unknown ... fatal: unable to auto-detect email address (got 'vincemaina@arch.(none)')". On the reference machine the identity comes from a 59-byte hand-written ~/.gitconfig (git config --list --show-origin: file:/home/vincemaina/.gitconfig, user.name + user.email only). `chezmoi source-path ~/.gitconfig` -> "not managed". So it exists exactly once, in a file nothing tracks, and a rebuild loses it. Nothing under setup/ mentioned git config before this task.

DECISION 1 - committed, not prompted.
The two precedents are install.conf (committed) and the passwords in 03-system.sh (interactive). A password is a secret; a name and an email address are not. This repository's own history already publishes both on every commit (git log -1 --format='%an <%ae>' -> Vince Maina <vchapandrews@gmail.com>), so committing them reveals nothing `git log` does not. Prompting would also put the question in the one place it can only be answered once - the installer - and leave sync.sh with nothing to apply, which is the "reaches the installer but never a running machine" bug CLAUDE.md already records.

DECISION 2 - the TASK-14 overlap dissolves rather than needing splitting.
The task description assumed "identity is per-machine rather than universal". It is not. It is per-PERSON, and this build has one person; USERNAME in install.conf is exactly as personal and is already committed. So there is nothing per-machine here for TASK-14 to own, and no profile is needed. TASK-14 is untouched.

DECISION 3 - one source, no second copy.
GIT_NAME/GIT_EMAIL go in setup/install.conf beside USERNAME. dot_gitconfig.tmpl reads that file with `{{ include "../install.conf" }}` and parses the KEY="value" lines. Verified chezmoi will read outside its source dir: with setup/.chezmoiroot = dotfiles, sourceDir is setup/dotfiles and "../install.conf" resolves in all three contexts (installer chroot /opt/arch-setup, sync.sh, scratch render). This is why install.conf keeps its quoting style - the template matches on it.

DECISION 4 - ~/.gitconfig, not ~/.config/git/config.
Measured, not assumed: with both files present git reports FROM_DOTGITCONFIG. git reads the XDG path first and ~/.gitconfig second, so second wins. Managing the XDG path would have left the existing hand-written ~/.gitconfig quietly in charge and the managed file inert - the exact invisible-configuration failure this repo keeps hitting.

PREFERENCES - four, each with a demonstrated failure:
  init.defaultBranch=main   - without it `git init` makes `master` + 8 lines of hint (observed). Every branch here is main.
  pull.ff=only              - without it a divergent `git pull` is "fatal: Need to specify how to reconcile divergent branches" + 12-line lecture (observed). `only` refuses rather than silently merging (pull.rebase false) or silently rewriting local commits (pull.rebase true).
  push.autoSetupRemote=true - without it the first push of a new branch is "fatal: The current branch newbranch has no upstream branch" (observed); with it, "[new branch] newbranch -> newbranch ... set up to track" (observed).
  user.name/user.email      - commit fails outright without them.

DELIBERATELY NOT SET, and named in the file so they are not added back:
  push.default   - already `simple` since git 2.0; `git config --show-scope --get push.default` exits 1 (unset) and behaviour is already correct. Setting it would read as a decision that was made.
  core.editor    - EDITOR=nvim and VISUAL=nvim are already in the user manager environment (systemctl --user show-environment) from .config/environment.d/30-editor.conf, and git honours EDITOR. A second copy is a second thing to keep in step.
  commit.gpgsign - no signing key on a machine this repo builds; TASK-38 decided not to provision one.

FAILURE PATHS ARE LOUD. An empty user.name is accepted by git and writes unattributable commits, so the template calls `fail` instead. Verified by temporarily removing GIT_NAME ("chezmoi: ... GIT_NAME is not set in setup/install.conf") and by emptying GIT_EMAIL ("GIT_EMAIL is empty in setup/install.conf"). install.conf restored afterwards and re-verified.

DECISIONS.md entry added, which was the outstanding criterion - 'Git identity lives in install.conf, and is committed', placed next to the Passwords entry because it is the deliberate contrast to it: a password is a secret, a name and an email are not, and this repository publishes both on every commit already.

Verified independently after the fact rather than taken on trust: rendering to a scratch home produces all five settings, and a commit made with only that file present is attributed to Vince Maina <vchapandrews@gmail.com>. git init in that home creates 'main' with no hint.

One correction to my own checking: a first attempt reported the branch as 'master' and appeared to contradict the work. It had run git init without HOME pointed at the rendered config, so git used the real one. The test was wrong, not the change - the same shape as the HOME= trap already in the scripting-traps skill, which is about needing XDG_CONFIG_HOME too.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-08-21 21:02
---
Held at In Progress rather than Done: AC#6 requires a DECISIONS.md entry and this session was explicitly scoped out of editing that file. Everything else is implemented and verified. Draft DECISIONS.md text was handed to the orchestrating session; once it lands, check AC#6 and close.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Decided IN FAVOUR and implemented. git configuration is now part of the build.

setup/install.conf gains GIT_NAME and GIT_EMAIL beside USERNAME, committed rather than prompted: a password is a secret, a name and an email are not, and this repository already publishes both on every commit. setup/dotfiles/dot_gitconfig.tmpl (new) reads that same file through chezmoi `include "../install.conf"` and parses its KEY="value" lines, so the identity is written down once and the dotfile holds no second copy - which is why the TASK-14 overlap needed no split: the identity turned out to be per-person, not per-machine, and this build has one person.

Four settings, each with an observed failure behind it: user.name/user.email (commit fails outright), init.defaultBranch=main (git init makes `master` + 8 lines of hint), pull.ff=only (divergent pull is a fatal + 12-line lecture), push.autoSetupRemote=true (first push of a new branch fails). Three more are named in the file as deliberately unset - push.default (already `simple` since git 2.0), core.editor (EDITOR=nvim is already in the user manager env) and commit.gpgsign (no key, per TASK-38).

VERIFIED: rendered to a scratch destination with --exclude=scripts and read back; `git config --list --file` parses all five values; and with HOME and XDG_CONFIG_HOME pointed at a home containing ONLY this file, `git init` produced `main` with no hint and `git commit` succeeded as "Vince Maina <vchapandrews@gmail.com>" - AC#5 proven rather than inferred. Both loud-failure paths exercised (GIT_NAME removed, GIT_EMAIL emptied) and install.conf restored. chezmoi diff against the live machine is a pure addition: the existing identity lines are unchanged, so applying is a no-op for identity. checks/session.sh unchanged at 75 passed / 1 failed (the failure is a pre-existing zswap item, present before this work and unrelated).

AC#6 (DECISIONS.md) is NOT done: this session was scoped out of editing that file. Draft text handed to the caller.
<!-- SECTION:FINAL_SUMMARY:END -->
