---
id: TASK-43
title: Decide whether this repository supports AUR packages
status: To Do
assignee: []
created_date: '2026-08-20 17:39'
updated_date: '2026-08-20 17:39'
labels:
  - repo
  - foundation
dependencies:
  - TASK-31
priority: low
type: spike
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Three times now a tool has been turned down for being AUR-only, and the reason recorded each time was that adding AUR support was bigger than the task asking for it. That is a deferral rather than a decision, and it has hardened into something that reads like policy without anyone having weighed it.

The record: sway-systemd, which solved exactly the problem TASK-11 was working on. Powerlevel10k, though that had a second reason and would have been declined anyway. And now swayfx, which is the only way to get shadows, blur or rounded corners, since sway has none of them - the words shadow, glow, blur, dim and corner_radius appear zero times in sway(5). The overview tools discussed in TASK-34, sov and swayr, are AUR-only too.

What supporting the AUR would actually cost here, which is more than installing a helper:

The helper is itself an AUR package, so bootstrapping it means git clone and makepkg from source as an installer step.

makepkg refuses to run as root, and stages 03 to 05 run as root inside arch-chroot. Builds would need runuser to the target user, following the pattern 05-dotfiles.sh already uses, plus a way to install the built package as root.

sync.sh breaks in a specific and unavoidable way. It finds missing packages with pacman -T, which only knows configured repositories, so an AUR entry in a manifest would be reported missing on every run and pacman -S would then fail on it. The reconciliation logic has to learn which entries are AUR. This is the real code change, not the helper.

Builds are slow and can fail. swayfx is C, so minutes rather than seconds, and a failed build aborts an install that is otherwise fine.

Reproducibility weakens. PKGBUILDs are user-submitted and mutable, and building one executes arbitrary code. For a repository whose stated purpose is reproducibility, that is a real cost even if a tolerable one.

The reason not to decide this yet, and why it depends on TASK-31: niri is in extra. If the compositor decision lands there, the overview and the visual effects both come natively and the AUR is never needed. If it lands on staying with sway, AUR support is the price of ever having either. So this is not really a separate question - it is the cost of staying on sway, and belongs in that decision as an input.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The decision is made deliberately rather than deferred again, and deciding against counts as completing this
- [ ] #2 It is settled against TASK-31 rather than separately, since a move to niri would remove the need entirely
- [ ] #3 If adopted, sync.sh reconciles AUR entries correctly rather than reporting them missing on every run
- [ ] #4 If adopted, a fresh install builds and installs an AUR package unattended, with a build failure reported clearly rather than aborting the install silently
- [ ] #5 If adopted, the reproducibility cost of building user-submitted PKGBUILDs is stated in DECISIONS.md rather than left implied
- [ ] #6 If declined, DECISIONS.md records it as a decision, so the next tool that wants it does not reopen the question from scratch
<!-- AC:END -->
