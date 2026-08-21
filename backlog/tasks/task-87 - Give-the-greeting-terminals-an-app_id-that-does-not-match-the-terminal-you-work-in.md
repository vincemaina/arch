---
id: TASK-87
title: >-
  Give the greeting terminals an app_id that does not match the terminal you
  work in
status: To Do
assignee: []
created_date: '2026-08-21 20:03'
labels: []
dependencies: []
priority: medium
type: bug
ordinal: 89000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Three separate windows share app_id=greeting: the login card from greeting.service, the card sway-workspace-greeter opens on every empty workspace, and anything launched with `terminal --floating`. On a machine in use that means most open terminals carry it, including the one the user is actually working in.

Two consequences.

The sharp one: `swaymsg [app_id="greeting"] <anything destructive>` targets the user's working terminal. This is not hypothetical - it closed the session three times in one sitting while a helper was cleaning up a test window it had spawned, taking the editor and five background jobs with it each time. The selector describes a category and the session is standing in the category. Recorded in the scripting-traps skill, but a skill entry is a warning rather than a fix.

The blunt one: window rules cannot distinguish them. 40-window-rules.conf floats and centres app_id=greeting, which is right for a greeting card and is also applied to every floating terminal opened for any other reason - including the one yazi opens at a directory on ctrl+o. Any rule that should apply to one and not the others cannot currently be written.

Worth deciding what the identities actually are before renaming: 'the login greeting', 'a fresh-workspace greeting' and 'a floating terminal opened deliberately' may want to be three app_ids, or two, or one plus a title match. The name 'greeting' describing a general-purpose floating terminal is the underlying error.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each kind of floating terminal is distinguishable by a sway selector, so a rule or a script can name one without matching the others
- [ ] #2 No selector that a helper script would plausibly use matches the terminal the user is working in
- [ ] #3 The window rules in 40-window-rules.conf still float and centre the greeting cards, verified by opening one rather than by reading the config
- [ ] #4 checks/session.sh or checks/sway-commands.sh notices if the app_id set by the terminal script and the one named in the window rules ever disagree
<!-- AC:END -->
