---
id: TASK-43
title: Decide whether this repository supports AUR packages
status: Done
assignee: []
created_date: '2026-08-20 17:39'
updated_date: '2026-08-21 14:50'
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Raised from low. This was filed as a curiosity and is now gating real work.

TASK-84 needs html, css, json, emmet and sql language servers, none of which is
in the official repositories, and TASK-73 decided against Mason because it
installs binaries where the manifests cannot see them. So the editor's support
for four of the six languages named waits on the answer here.

Worth noting the fallback if the answer is no: a tracked list of npm packages,
which keeps them declared at the cost of more machinery. That is not an argument
for saying yes, but it means a no is not a dead end.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Decided: no AUR support, for now, and "for now" is stated rather than implied.

Nothing currently wanted needs it. The three tools that prompted this ticket
were sway-systemd, powerlevel10k and swayfx, and swayfx was the live one -
rejected here on its merits rather than on the cost of the AUR: it buys
shadows, blur and rounded corners at the cost of GPU work, and vanilla sway
already looks the way it should after the theming work. That is a judgement
about the feature, so the AUR machinery has nothing left to justify it.

The neovim gap, which was the other thing gating this, is closed a different
way. The servers missing from the official repositories - html, css, json,
emmet - are npm packages, and the AUR PKGBUILDs are wrappers around npm
install. So npm directly, from a list tracked in this repository, keeps them
declared and reproducible without a helper to bootstrap, makepkg under runuser
inside the chroot, or teaching sync.sh which manifest entries pacman -T cannot
see. See TASK-84.

The data that made that easy: the AUR packages this repository would have
needed are its weakest. vscode-langservers-extracted has 4 votes, popularity
0.00 and was last touched in May 2024. sqls is flagged out of date.
tree-sitter-sql has zero votes. Popularity 0.00 means nobody else installs
them either, so nobody else notices when they break. By contrast the packages
that motivated the ticket are healthy - swayfx has 46 votes and was updated
ten days ago - which is what makes this a judgement about swayfx rather than
about the AUR.

WHAT WOULD REOPEN THIS

A tool that is genuinely wanted, actively maintained, and AUR-only. niri is
the likely route instead, and it is in extra at 24.87 MiB rather than in the
AUR - worth exploring for the workflow rather than for the effects, and not
now. That exploration belongs on TASK-31.

The costs catalogued in the description above remain accurate and are the
reason this stays a no rather than a shrug: bootstrapping a helper that is
itself an AUR package, makepkg refusing to run as root while stages 03-05 do,
sync.sh's pacman -T reporting AUR entries missing on every run, slow builds
that can fail an otherwise fine install, and PKGBUILDs being mutable
user-submitted code executed at build time.
<!-- SECTION:FINAL_SUMMARY:END -->
