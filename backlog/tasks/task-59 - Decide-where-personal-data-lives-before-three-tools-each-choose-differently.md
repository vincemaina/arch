---
id: TASK-59
title: 'Decide where personal data lives, before three tools each choose differently'
status: To Do
assignee: []
created_date: '2026-08-21 10:21'
labels:
  - desktop
  - dev
dependencies: []
type: spike
ordinal: 57000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A calendar, a notes tool and a todo tool are all wanted. Each needs somewhere to keep what you write, and if they are built one at a time each will answer that separately - three locations, three sync stories, three ways of being reached. Deciding it once is cheap now and expensive later.

THE CONSTRAINT THAT DECIDES MOST OF IT

This repository is a system build. setup/ is the machine, and nothing personal belongs in it - a note written on a Tuesday is not part of a reproducible Arch install, and committing one would make every sync a diff about your day. The same reasoning already keeps the selected theme out of the repository and machine-local instead.

So personal data lives outside the repository, and the repository holds only the tools that read it. That much is settled. What is not settled:

  * WHERE. ~/Documents, an XDG data directory, or a single directory these tools share. The XDG user directories already exist and nothing uses them.
  * WHETHER IT SURVIVES A REBUILD. The whole point of this repository is that a machine can be rebuilt from it. Anything in the category above is by definition not rebuilt from it, so unless there is a sync or backup story, "reproducible machine" quietly means "loses your notes". That may be acceptable if the data lives in a git repository of its own or in a synced account, and unacceptable otherwise, but it should be a decision.
  * WHAT FORMAT. Plain text and markdown compose with everything already here - yazi opens them, ripgrep searches them, git versions them. A tool with its own database does not, and is a bet on that tool still being maintained in three years.
  * HOW THEY ARE REACHED. There is a pattern for this already: a helper in ~/.local/bin, a .desktop entry with an absolute Exec, and a floating foot window with its own app_id and a for_window rule. Notifications, the theme switcher, the wallpaper picker and the calendar all follow it. A fourth, fifth and sixth should look the same rather than each inventing an interface.
  * WHETHER THEY ARE ONE TOOL OR THREE. Notes with a due date are a todo list; a todo with a date is a calendar entry. Deciding they are separate is fine, but it should be a decision rather than an accident of the order they were built in.

This is a spike: the output is a written answer, not code. It should be short, and it should be recorded in DECISIONS.md, because the three tickets that depend on it will each want to cite it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Where personal data lives is decided and written down, with the reason it is not in this repository stated
- [ ] #2 Whether it survives a machine rebuild is answered honestly - either there is a story, or the limitation is recorded as accepted
- [ ] #3 A format is chosen, weighed against the tools already installed that could read it
- [ ] #4 Whether notes, todos and calendar entries are one thing or three is decided
- [ ] #5 The launcher pattern the existing helpers use is written down as the pattern these follow, rather than re-derived three times
- [ ] #6 Recorded in DECISIONS.md so the dependent tickets cite it instead of re-arguing it
<!-- AC:END -->
