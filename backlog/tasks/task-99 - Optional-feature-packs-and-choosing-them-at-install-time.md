---
id: TASK-99
title: 'Optional feature packs, and choosing them at install time'
status: To Do
assignee: []
created_date: '2026-08-22 01:03'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 101000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-86 delivered the identity half of the install wizard - username, hostname, timezone, locale, keymap and git identity, validated against the live system and written into setup/install.conf. Its description also asked for two things that are a different and larger problem, and they are split out here rather than left implied.

FEATURE PACKS. Being able to say at install time that this machine wants music, or development tooling, or neither. Today setup/packages/ is three flat manifests - base, desktop, dev - and 04-desktop.sh installs desktop.txt and dev.txt unconditionally. Optional sets mean the manifests grow a notion of membership and 04-desktop.sh learns to install a selection, which touches the parsing rules CLAUDE.md documents (base.txt takes no comments; the others are comment-stripped; sync.sh globs all three).

WHICH DESKTOP OR WINDOW MANAGER. Larger still, and entangled with TASK-31 and TASK-32 - the repository currently assumes sway throughout, from wayland-session@sway.target to the session-entry masking pair to six pieces of tooling that parse sway's config.

Worth doing in that order, and worth being honest that the second may not be worth doing at all: a build that can install any of several desktops is a different project from one that reproduces this desktop exactly. The guiding principle is the test - minimal enough to stay understandable, and new machinery must earn its place.

Not blocked on anything. The wizard's prompt loop and its verify-before-replace mechanism are reusable for whatever selection UI this needs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Optional package sets exist in setup/packages/ without breaking the two different parsers documented in CLAUDE.md, and sync.sh reconciles whatever was selected
- [ ] #2 04-desktop.sh installs the selected sets rather than everything, and a machine built with no optional packs still produces a working desktop
- [ ] #3 The selection is recorded somewhere a rebuild reproduces, not only answered once at install time
- [ ] #4 Whether choosing a desktop environment is in scope at all is decided explicitly, with TASK-31 and TASK-32 taken into account
<!-- AC:END -->
