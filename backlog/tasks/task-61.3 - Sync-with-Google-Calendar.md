---
id: TASK-61.3
title: Sync with Google Calendar
status: To Do
assignee: []
created_date: '2026-08-21 10:22'
labels:
  - desktop
  - dev
dependencies: []
parent_task_id: TASK-61
ordinal: 62000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The calendar that matters already exists in a Google account. Until this machine sees it, a local calendar is a second empty one nobody will use.

Google supports CalDAV, so a local store can sync both ways with vdirsyncer. The awkward part is authentication: Google wants OAuth, an app password, or - for accounts with two-factor enabled, which this one should have - something more than a password in a config file. Whatever it turns out to need, the credential is a secret and must not be committed. This repository has no secret story at all yet, which makes this the first ticket to need one; TASK-38 has the same problem for SSH keys and the two should not solve it twice.

Sync also has to happen on some schedule without being asked. A systemd user timer is the obvious mechanism and matches how everything else in the session is supervised, and it must fail quietly when there is no network rather than filling the journal.

Two-way is the goal - an event added here should reach the phone - but one-way is a reasonable first step and much easier to be sure of. Whichever it is, it should be stated, because silently discarding a locally-created event would be the worst outcome.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Events from the Google account appear in the local calendar
- [ ] #2 Whether sync is one-way or two-way is explicit, and if one-way, locally created events are prevented rather than silently lost
- [ ] #3 Sync happens on its own, and does nothing noisy when there is no network
- [ ] #4 The credential is not committed to this repository, and how secrets are handled is decided in a way TASK-38 can reuse
<!-- AC:END -->
