---
id: TASK-27
title: Document every tool the setup chooses
status: To Do
assignee: []
created_date: '2026-08-19 19:17'
labels:
  - repo
  - documentation
dependencies: []
priority: medium
type: docs
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
DECISIONS.md covers the large architectural choices well - Arch, Btrfs, Sway, systemd-boot - but coverage thins out for the individual tools the system actually runs on, and newer additions are being recorded to a higher standard than older ones. The result is uneven: some tools have a full rationale, others appear only as a line in a package manifest with no record of what they do or why they were picked.

Every tool this setup installs should be documented to the same standard, so that a choice can be re-evaluated later without rediscovering the reasoning from scratch, and so that nothing sits in the system purely because it was added once and never questioned.

For each tool: the problem it solves, why it was chosen over the alternatives, what those alternatives were, how it actually works in enough detail to debug it, and what it costs in memory and CPU. Cost matters here specifically - the setup targets a small idle footprint, and a tool that is cheap on a 16 GB machine may not be on a small VM.

earlyoom is the worked example: what problem low-memory handling solves, how watching MemAvailable differs from the kernel OOM killer, why that behaves better alongside zram, what it costs to run, and how systemd-oomd and nohang compare.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every package in setup/packages/ is either documented or explicitly noted as a dependency needing no rationale of its own
- [ ] #2 Each documented tool covers the problem it solves, why it was chosen, the alternatives rejected, and its resource cost
- [ ] #3 Resource figures are measured on this system rather than quoted from elsewhere
- [ ] #4 The documentation is structured so a future addition has an obvious place and format to follow
- [ ] #5 Existing DECISIONS.md entries are brought up to the same standard rather than left as a second tier
<!-- AC:END -->
