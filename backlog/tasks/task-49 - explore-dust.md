---
id: TASK-49
title: explore dust
status: Done
assignee:
  - '@claude'
created_date: '2026-08-20 23:11'
updated_date: '2026-08-21 20:34'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 47000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
dust could be a cool tool that makes disk usage easier to visualise. perhaps that could be a tool that displays in a floating window on startup. there may also be better tools available for this. its just an idea for now
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Check availability and cost: official repos, size, dependency tail.
2. Check what is already installed that answers the same question - du, btop, yazi, tree.
3. Trial it on this machine rather than reading its README: fetch the package, extract to scratch, run it.
4. Measure it against the du idiom it would replace, warm cache, several runs.
5. Survey the alternatives in the repos: ncdu, gdu, dua-cli, diskus.
6. Decide, and evaluate the floating-window-at-login idea separately.
7. If it earns a place: setup/packages/dev.txt plus a DECISIONS.md entry.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DECISION: dust earns a place, in dev.txt. The floating-window-at-login half of
the idea is rejected.

AVAILABILITY AND COST. extra/dust 1.2.5-1. Installed size 2.97 MiB, download
1013 KiB, Depends On: glibc libgcc. No AUR, no dependency tail. Not currently
installed on this machine.

TRIALLED, NOT READ ABOUT. No sudo was available, so the package was fetched
from the configured mirror, extracted into the scratch directory and run from
there. Dust 1.2.5.

WHAT IT GIVES OVER du. Not speed - the shape of the question. The reflex is
`du -sh ~/*`, which stops at the top level, and on this machine that reports
.local at 1.4G and stops. dust ranks the largest directories at any depth and
named the actual culprit unprompted: three cached Claude Code versions in
~/.local/share/claude/versions, 969 MiB, 46 percent of home. The du equivalent
is `du -h --max-depth=N ~ | sort -h | tail`, where N has to be guessed before
you know where the space went - and the guess is what hides the answer.

MEASURED, AND THE FIRST MEASUREMENT WAS WRONG. The first comparison ran dust
cold against a du that had just warmed the page cache, and reported dust three
times slower (2.8s vs 0.42s on /usr). That was the "one patch is not a
measurement" trap. Warm on both sides, three runs each, over /usr:

  dust -n 20 /usr                                   134 / 126 / 131 ms
  du -h --max-depth=3 /usr | sort -h | tail -20     219 / 219 / 217 ms

Over a home directory both are under 30 ms and the difference is irrelevant.

NOTHING INSTALLED ALREADY DOES THIS.
  * btop reports filesystem free space, not per-directory totals.
  * yazi has no directory-tree size command. Checked against its default
    bindings extracted from /usr/bin/yazi rather than from memory - the
    defaults cover navigation, selection, yank/paste, search, fzf and zoxide,
    and there is no size or calc action among them.
  * tree does not aggregate.

ALTERNATIVES IN THE OFFICIAL REPOS.
  ncdu      529 KiB   interactive TUI browser, can delete in place
  dua-cli   3.7 MiB   both one-shot and interactive
  gdu       21 MiB    interactive, much larger
  diskus    814 KiB   a faster du -sh for one directory, answers none of this
  dutree              not packaged
ncdu and gdu are a second thing shaped like yazi, and yazi is already on a key.
A one-shot ranked report composes with a shell and a scrollback; a TUI does not.
dua-cli is the closest call - rejected for being larger while its one-shot
output is a plain list without the proportion bars that make dust readable at a
glance.

THE FLOATING WINDOW AT LOGIN IS REJECTED. It puts a filesystem walk on the
critical path of every login to answer a question nobody asked at that moment.
The login greeting already reports filesystem usage - fastfetch config.jsonc
carries a `disk` module. What that report lacks is not the free-space number,
it is which directory to blame, and that is worth one command when the question
comes up rather than a scan every time the machine starts.

WHAT CHANGED
  setup/packages/dev.txt - dust added to the "Navigation and viewing" group
    (with zoxide, eza, bat), with a comment carrying the measurement and the
    reason, not just the name.
  DECISIONS.md - new entry "## dust rather than a `du` pipeline" after
    "## Terminal utilities": Decision / Why with the timing table / Trade-off
    (it is a monthly tool, not a daily one, and 3 MiB for a monthly question is
    the honest cost) / Alternatives considered, including the rejected
    login-window idea.

VERIFICATION
  ./sync.sh --dry-run        91 packages declared, 1 missing: dust. So the
                             package reaches a running machine and a fresh
                             install through the one manifest line.
  ./checks/session.sh        75 passed, 0 failed, 0 skipped (unchanged)
  ./checks/sway-commands.sh  clean
  base.txt untouched and still comment-free.

NOT INSTALLED HERE. No sudo was used, so this machine does not yet have dust -
`./sync.sh` installs it. checks/packages.sh reports it as declared but not
installed until then.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
dust earns a place; added to setup/packages/dev.txt with a DECISIONS.md entry. The "floating window on startup" half of the idea is rejected and the rejection recorded.

Decided by trialling it on this machine rather than reading its README: with no sudo available the package was fetched from the mirror, extracted to scratch and run. The argument that carries it is not speed but the shape of the question - `du -sh ~/*` reports .local at 1.4G and stops, while dust named the real culprit unprompted (three cached Claude Code versions, 969 MiB, 46% of home), which du only reaches with a --max-depth guessed before you know the answer. It is faster too, though the first measurement said the opposite: cold-cache dust against warm-cache du. Warm on both sides, three runs each over /usr, dust took 126-134 ms against 217-219 ms for the du pipeline.

Nothing installed already does it - btop reports free space not per-directory, yazi has no size command (checked against defaults extracted from its binary), tree does not aggregate. ncdu and gdu were rejected as a second TUI where yazi already is one, dua-cli as larger with less readable one-shot output, diskus as answering a different question. The login-window idea was rejected because fastfetch already reports disk usage at login and a filesystem walk on the login path answers a question nobody asked then.

Verified with ./sync.sh --dry-run (91 declared, dust the only missing one), ./checks/session.sh (75 passed, 0 failed, unchanged) and ./checks/sway-commands.sh. Not installed on this machine yet - ./sync.sh does that.
<!-- SECTION:FINAL_SUMMARY:END -->
