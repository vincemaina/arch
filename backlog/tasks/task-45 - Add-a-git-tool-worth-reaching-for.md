---
id: TASK-45
title: Add a git tool worth reaching for
status: To Do
assignee: []
created_date: '2026-08-20 20:50'
updated_date: '2026-08-20 20:50'
labels:
  - dev
dependencies:
  - TASK-37
priority: medium
type: feature
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Everything git currently happens through the bare CLI. That is fine for commit and push and hopeless for the things this repository actually does a lot of: reading a diff before committing, staging part of a file, working out what changed across a session, and resolving the occasional conflict.

Candidates, with what they cost, all from the official repositories - none of this needs the AUR, unlike Sublime Merge which is not packaged:

tig, 702 KiB. A TUI over git log, diff, blame and staging. By far the smallest, has been around forever, and does the reading half well. Weakest at staging hunks.

gitui, 8.09 MiB. Rust TUI. Fast, good hunk staging, keyboard-driven throughout. Younger than the others.

lazygit, 19.07 MiB. Go TUI, the most featureful of the three and the one most people mean when they say this. Panels for status, branches, stashes and log, interactive rebase, hunk staging.

meld, 5.64 MiB GTK. A graphical three-way diff and merge tool rather than a git front end. Different job - it is what git mergetool would open - and could sit alongside one of the above rather than instead of it.

git-delta, 4.96 MiB. Not a front end at all: a pager that makes git diff and git log readable, with syntax highlighting and side-by-side. Configured in gitconfig, so it improves the plain CLI rather than replacing it. Cheapest thing here by effort and could be the whole answer.

difftastic, 113.99 MiB. Structural diff that compares syntax trees rather than lines, so a reindent shows as nothing changed. Genuinely clever and by far the largest thing on the list.

Two things worth settling rather than assuming.

Whether the answer is a front end or a better pager. git-delta plus the existing CLI may cover most of the complaint, at a fraction of the size and with nothing new to learn, and it composes with any of the TUIs later.

Where the configuration lives. A TUI is a package and a config file, which is straightforward. git-delta and any mergetool are gitconfig settings - and this repository has no gitconfig at all, which is TASK-37. If that lands first, this becomes a few lines in a file that already exists.

This is a keyboard-driven desktop, so a TUI in a terminal fits the session better than a GTK window, the same reasoning that has yazi being trialled against Thunar.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Whether the answer is a front end, a better pager, or both is decided rather than assumed, with the cheap option priced honestly against the featureful one
- [ ] #2 Whatever is chosen is declared in packages/ and, if it needs configuration, that configuration lives in the repository rather than only on this machine
- [ ] #3 It is tried on a real diff from this repository before being committed to, not chosen from a feature list
- [ ] #4 Its relationship to TASK-37 is resolved: anything that is a gitconfig setting waits for that file to exist rather than creating a second home for git settings
- [ ] #5 The choice is recorded in DECISIONS.md, since TASK-27 exists because tools keep being picked without a reason being written down
<!-- AC:END -->
