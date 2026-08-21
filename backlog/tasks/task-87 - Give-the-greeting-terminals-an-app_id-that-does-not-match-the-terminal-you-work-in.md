---
id: TASK-87
title: >-
  Give the greeting terminals an app_id that does not match the terminal you
  work in
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 20:03'
updated_date: '2026-08-21 20:22'
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
- [x] #1 Each kind of floating terminal is distinguishable by a sway selector, so a rule or a script can name one without matching the others
- [ ] #2 No selector that a helper script would plausibly use matches the terminal the user is working in
- [x] #3 The window rules in 40-window-rules.conf still float and centre the greeting cards, verified by opening one rather than by reading the config
- [x] #4 checks/session.sh or checks/sway-commands.sh notices if the app_id set by the terminal script and the one named in the window rules ever disagree
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Largely settled by TASK-88, which had to split these app_ids for its own reasons.

app_id=greeting is now the once-a-session card only. app_id=floating-term is every other floating terminal. A tiled terminal is plain foot. A rule or a script can now name one without matching the others, which it could not before.

AC2 IS NOT CHECKED, AND SHOULD NOT BE. 'No selector that a helper script would plausibly use matches the terminal the user is working in' cannot be delivered by naming, and it was a mistake to write it as though it could. The user works in whichever terminal is in front of them - a greeting card, a floating-term card, a tiled foot - so every one of those app_ids matches a terminal somebody might be working in. Renaming reduced the blast radius from most terminals to one card; it did not make class selectors safe.

What actually addresses it is elsewhere and is done: the scripting-traps skill records that a class selector matches members of the class you are standing in, with the con_id form to use instead, and TASK-88 stopped the greeter owning the terminals it spawns, which was the larger of the two ways the session died.

AC4 delivered: checks/session.sh has a Terminal windows section asserting that every app_id the terminal helper sets is floated and centred by a matching rule, and that the greeting card and the ordinary floating terminal never collapse back into one app_id. Proven by deleting a rule and watching it fail by name.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Settled as part of TASK-88: the once-a-session greeting card keeps app_id=greeting, every other floating terminal is floating-term, and a check now fails if they ever collapse back into one. Acceptance criterion 2 is deliberately left unchecked - no naming scheme can stop a selector matching the terminal someone happens to be working in, and claiming otherwise would be the false-comfort comment this repository keeps getting caught by. That risk is addressed instead by the scripting-traps entry on class selectors and by the greeter no longer owning the terminals it opens.
<!-- SECTION:FINAL_SUMMARY:END -->
