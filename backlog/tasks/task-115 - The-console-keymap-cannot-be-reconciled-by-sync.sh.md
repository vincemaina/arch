---
id: TASK-115
title: The console keymap cannot be reconciled by sync.sh
status: Done
assignee: []
created_date: '2026-08-22 14:06'
updated_date: '2026-08-22 19:07'
labels: []
dependencies: []
priority: low
type: bug
ordinal: 123000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`KEYMAP` in `setup/install.conf` reaches the machine exactly once, when `03-system.sh` writes `/etc/vconsole.conf` during a fresh install. `sync.sh` has no path for it, so editing `install.conf` on a running machine changes the repository's intent and nothing else.

Found while doing TASK-114: changing the layout to `us` needed a root command typed by hand, because there was no other way to get it there. That is the shape of problem this repository keeps finding at the bottom of a bug - configuration that looks correct and does nothing - and here it is arguably worse than usual, because the context it silently leaves stale is the text console, which is what `Ctrl+Alt+F2` reaches when the graphical session will not start.

The obvious home is `setup/system/apply-config.sh`, which already owns everything machine-wide that both the installer and sync need. The complication is that it does not currently source `install.conf`, and `install.conf` is machine identity rather than system configuration - so this is a question about where that boundary sits, not a one-line change. `checks/session.sh` should probably also assert that `/etc/vconsole.conf` agrees with `install.conf`, since nothing notices today when they disagree.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 sync.sh brings /etc/vconsole.conf into agreement with KEYMAP in install.conf, or a decision is recorded for why it deliberately does not
- [x] #2 A check fails when the running machine's console keymap disagrees with the repository
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
apply-config.sh now sources install.conf and (re)writes /etc/vconsole.conf from KEYMAP; 03-system.sh no longer writes it, so apply-config.sh is the single source of truth (matches CLAUDE.md's 'one source of truth' pattern for machine-wide config). --activate restarts systemd-vconsole-setup.service so a fix applies live, warning not failing per the rest of that section. checks/session.sh gained a 'Console keymap (TASK-115)' section comparing /etc/vconsole.conf against install.conf.

Verified: (1) bash -n on all three edited scripts. (2) Ran the actual write+compare logic against a scratch install.conf/vconsole.conf pair (KEYMAP=uk) outside /etc - confirmed the writer produces the right file and the checker both passes on agreement and fails on a deliberately introduced mismatch. (3) Ran checks/session.sh for real on this machine: 92/92 pass (was 91/91 before), new section reports 'PASS /etc/vconsole.conf KEYMAP is us', matching install.conf. (4) sync.sh --dry-run runs clean. Did not run apply-config.sh --activate for real against live services (keyd/earlyoom restarts) since KEYMAP already agreed and that would restart unrelated live services with no need to.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
apply-config.sh is now the single writer of /etc/vconsole.conf, sourcing KEYMAP from install.conf and reapplying it live (systemctl restart systemd-vconsole-setup.service) under --activate; 03-system.sh no longer writes it directly. sync.sh therefore reconciles the console keymap on every run, closing the gap where a wrong wizard answer needed a hand-typed fix. checks/session.sh gained a section that fails when /etc/vconsole.conf disagrees with install.conf. Verified via syntax checks, an isolated logic test proving both the writer and the mismatch-detector behave correctly, and a real checks/session.sh run (92/92 pass, up from 91/91).
<!-- SECTION:FINAL_SUMMARY:END -->
