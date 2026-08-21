---
id: TASK-13
title: Detect drift between installed packages and the manifests
status: Done
assignee:
  - '@claude'
created_date: '2026-08-19 18:15'
updated_date: '2026-08-21 20:32'
labels:
  - repo
  - workflow
dependencies: []
priority: low
type: chore
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
packages/README.md describes comparing pacman -Qqe against the manifests to find packages that were installed ad hoc or are listed but unused, but this is a manual chore that will not happen reliably. Automating it keeps the manifests honest as the intentional description of the system.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A script reports packages explicitly installed but not in any manifest
- [x] #2 It also reports packages listed in a manifest but not installed
- [x] #3 It exits non-zero when drift is found so it can gate other checks
- [x] #4 It ignores the distinction between manifest files rather than requiring a package to be in a specific one
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Read checks/session.sh and checks/sway-commands.sh for style; read sync.sh and 04-desktop.sh for how manifests are parsed and installed.
2. Establish the ground truth on this machine: pacman -Qqe vs the comment-stripped union of setup/packages/*.txt, and read /var/log/pacman.log to explain each difference rather than guessing.
3. Write checks/packages.sh (a check, not a tool - AC3 requires a non-zero exit so it can gate). Model: the manifests declare the set of packages that should be EXPLICITLY installed, so drift is the symmetric difference between that set and pacman -Qqe, taking 'provides' into account.
4. Four drift categories, one per remedy: declared-but-absent (install or drop), declared-but-marked-as-a-dependency (pacman -D --asexplicit), explicit-but-undeclared-and-inside-the-manifest-dependency-closure (pacman -D --asdeps), explicit-but-undeclared-and-unrelated (declare or remove).
5. Add a manifest-hygiene section covering the parser asymmetry documented in CLAUDE.md: base.txt must carry no comments or blank lines, and no package may be listed twice.
6. Avoid the grep -q/pipefail trap and the set -e-outside-a-condition trap from the scripting-traps skill.
7. Run it on this machine, chmod +x, document the workflow in setup/packages/README.md.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Finished the partial checks/packages.sh left by an interrupted attempt. The model it had was right - the manifests declare the set that should be EXPLICITLY installed, so drift is the symmetric difference against pacman -Qqe - and it already found real drift, so it was fixed rather than replaced. Seven concrete faults corrected:

1. No LC_ALL=C. Every parse matched on the English pacman -Qi labels 'Name', 'Provides' and 'Required By'. On a machine running in any other locale the Provides and Required By extraction returns nothing and the script silently reports the wrong category. Now pinned at the top.
2. 'no such package exists in the repositories' was decided by pacman -Si without checking the sync database is populated. On a machine that has never run pacman -Sy every missing package would have been reported as a typo. Now gated on pacman -Slq, with a different message when the database is empty.
3. A declared name satisfied by a *provider* was skipped without asking whether the provider is itself explicitly installed. That is the same orphan-removal risk the section exists to catch, one step removed - the capability is declared and the only thing supplying it can still be removed. Now split into three: provider explicit (skip), provider dependency-marked (fail, with the -D --asexplicit fix), provider unknown (skip).
4. Membership was a grep per question inside nested loops - roughly 90x90 subprocesses, with a pattern-matching and quoting surface it did not need. Replaced with bash associative arrays.
5. No hygiene check for malformed package lines. Neither parser trims, so 'coreutils ' or 'sudo vim' on one line survives the comment-stripping grep and is handed to pacman as a name, surfacing two sections later as 'declared but not installed' - which reads as a missing package rather than as a typo. Verified: that cascade is exactly what happens without the check.
6. The header comment asserted the current machine's state as fact ('wofi and firefox on this machine arrived exactly that way'). That is the failure mode CLAUDE.md names about the SPICE guest agent - a transient observation read a month later as a permanent one. Generalised.
7. ls | wc -l for the manifest count, and a summary line reading 'drifted' where session.sh reads 'failed'. Both aligned.

Verification. Every branch was exercised, not just the ones this machine happens to hit, by pointing a copy of the script at scratch manifest directories:
  * manifests == pacman -Qqe exactly -> 6 passed, 0 failed, exit 0
  * base.txt with a comment and a blank line, plus 'coreutils ', 'sudo vim', a tab-indented name, and a package listed in two files -> all five hygiene failures fire, and the malformed names then cascade into 'declared but not installed' as predicted
  * 'exa' declared (provided by eza, explicit) -> SKIP; 'sh' declared (provided by bash, dependency-marked) -> FAIL naming bash; 'foot-terminal-emulator' -> FAIL as a typo; eza itself undeclared -> PASS, provides a declared name
  * PATH with every /usr/bin entry except pactree -> the SKIP fires and undeclared packages are reported without the by-remedy split, rather than misclassified
  * pacman -Slq --dbpath against an empty database returns 0, so the sync-db guard can be false

checks/session.sh still reports 75 passed, 0 failed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
checks/packages.sh answers, in both directions, whether pacman -Qqe matches the union of setup/packages/*.txt, and exits non-zero when it does not.

It treats the manifests as declaring the set of packages that should be EXPLICITLY installed, which is the only reading that makes 'a dependency may still be listed explicitly' (polkit) mean anything: sync.sh installs with pacman -T, which reports such a package as satisfied, so pacman is never told it is wanted in its own right and -Rns on whatever pulled it in still takes it away. Four drift categories, one remedy each - declared-but-absent, declared-but-dependency-marked, undeclared-but-inside-the-manifest-closure, undeclared-and-unrelated - plus the provider-of-a-virtual-name variant of the second. It ignores which manifest a package is in, and a manifest-hygiene section covers the parser asymmetry base.txt cannot show on a running machine.

Verified by running it here (8 genuine drift items, all explained against /var/log/pacman.log) and by pointing a copy at scratch manifest directories that force every branch the real machine does not reach: a clean machine (exit 0), five hygiene faults, all three provides outcomes, a typo, and pactree absent. checks/session.sh still reports 75 passed, 0 failed. setup/packages/README.md now documents the check and the four remedies in place of the manual pacman -Qqe comparison the task was raised against.

The script is read-only: every finding names the command that settles it and none were run.
<!-- SECTION:FINAL_SUMMARY:END -->
