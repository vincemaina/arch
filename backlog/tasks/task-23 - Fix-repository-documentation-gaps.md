---
id: TASK-23
title: Fix repository documentation gaps
status: To Do
assignee: []
created_date: '2026-08-19 18:16'
labels:
  - repo
dependencies: []
priority: low
type: docs
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
README.md links to FLOW.md, which does not exist, so the documented overview of the installation process is a dead link. setup/packages/CHATGPT.md is a raw pasted assistant conversation sitting inside the installation payload, which is copied onto every built machine; its useful conclusions already live in packages/README.md and DECISIONS.md.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every link in README.md resolves
- [ ] #2 The installation flow is documented, including which stages run on the live ISO and which run inside the chroot
- [ ] #3 No raw conversation transcripts remain under setup/
- [ ] #4 Anything still useful from the removed material is preserved in the appropriate document
<!-- AC:END -->
