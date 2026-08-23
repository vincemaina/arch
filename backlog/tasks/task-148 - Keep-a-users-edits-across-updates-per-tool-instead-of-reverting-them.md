---
id: TASK-148
title: 'Keep a user''s edits across updates, per tool, instead of reverting them'
status: To Do
assignee: []
created_date: '2026-08-23 12:58'
labels: []
dependencies: []
priority: high
type: feature
ordinal: 155000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Today sync.sh has two settings: the repository wins, or the user is asked. Asking happens whenever a managed file differs, regardless of whether the repository actually changed that file - so a user who tweaked their Neovim config is interrupted by an update that only touched the bar. The honest answer to that prompt is usually 'not now', which trains people to ignore it.

The proposal is per-tool three-way merge, driven by a recorded baseline of what the repository last produced:

  base    what the repository rendered at the version this machine last synced
  theirs  what it renders now
  ours    what is on disk

  neither changed        nothing to do
  only the repo changed  apply, silently
  only the user changed  KEEP IT, and do not ask - this is the case that matters
  both changed           merge, or ask, per tool

The fourth column is the whole point: the question is asked per TOOL, not per repository. If an update does not touch nvim/, a user's nvim changes are none of its business.

This is the pattern dpkg uses for conffiles and rpm approximates with .rpmnew, and it is the right one. It also composes with the machine-local layer rather than replacing it: local files are for ADDITIVE config that can never conflict, this is for edits to tracked files.

WHAT CHEZMOI ALREADY GIVES, checked rather than assumed:
  * It detects a target modified since it last wrote it - sync.sh already uses --error-on-conflict for this.
  * chezmoi merge and merge-all perform a three-way merge, with merge.command configurable.
  * chezmoi state is a general key/value store we can record a baseline version in.

WHAT IS MISSING: chezmoi's three-way merge uses destination, source and target - the SOURCE is a template, not the previously rendered output, so the 'base' side is not what this machine was actually given last time. And there is no per-tool 'did the repository change this since your version' filter at all. That filter is the user's idea and is the substance of this task.

TWO DESIGNS, and the second is probably right:

  A. Record the commit id of main at each sync. Reconstruct base by rendering the old tree. Exact, cheap to store, but REQUIRES A GIT CHECKOUT.

  B. Store the rendered baseline itself under ~/.local/state/, the way dpkg stores conffile digests. No git history needed, so it works when the update arrives as a package rather than a clone - which is the direction this build is heading if it is ever published under its own name. Config files here total well under a megabyte.

B also makes 'what did I change' answerable offline, which A cannot do without the repo.

OPEN QUESTIONS worth settling before building:
  * What is a 'tool'? A directory under dot_config/ is the obvious unit and probably right, but sway's config.d/ and the shared themes.toml cut across it.
  * What happens to a template whose output changed only because the THEME changed? That is not a repository change and must not count as one.
  * Which merge tool? vimdiff is chezmoi's default and is a poor fit for a non-technical user.
  * How does an update even arrive if the user has no repo? sync.sh currently requires a clone. That question is bigger than this task and may deserve its own.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A user edit to a tracked file survives an update that does not change that tool
- [ ] #2 An update that changes a tool the user has also edited produces a merge or a prompt, not a silent revert
- [ ] #3 The baseline is recorded per sync and does not require the git history to be present
- [ ] #4 The unit of comparison is the tool, not the whole repository, and what counts as a tool is written down
- [ ] #5 A theme or font change does not register as a repository change to a tool's configuration
<!-- AC:END -->
