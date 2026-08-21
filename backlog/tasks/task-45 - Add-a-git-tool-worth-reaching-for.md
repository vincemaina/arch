---
id: TASK-45
title: Add a git tool worth reaching for
status: Done
assignee:
  - '@claude'
created_date: '2026-08-20 20:50'
updated_date: '2026-08-21 21:27'
labels:
  - dev
dependencies:
  - TASK-37
priority: medium
type: feature
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Everything git currently happens through the bare CLI. That is fine for commit and push and hopeless for the things this repository actually does a lot of: reading a diff before committing, staging part of a file, working out what changed across a session, and resolving the occasional conflict.

Candidates, with what they cost, all from the official repositories - none of this needs the AUR, unlike Sublime Merge which is not packaged:

tig, 702 KiB. A TUI over git log, diff, blame and staging. By far the smallest, has been around forever, and does the reading half well. Weakest at staging hunks.

gitui, 8.09 MiB. Rust TUI. Fast, good hunk staging, keyboard-driven throughout. Younger than the others.

lazygit, 19.07 MiB. Go TUI, the most featureful of the three and the one most people mean when they say this. Panels for status, branches, stashes and log, interactive rebase, hunk staging.

meld, 5.64 MiB GTK. A graphical three-way diff and merge tool rather than a git front end. Different job - it is what git mergetool would open - and could sit alongside one of the above rather than instead of it.

git-delta, 4.96 MiB. Not a front end at all: a pager that makes git diff and git log readable, with syntax highlighting and side-by-side. Configured in gitconfig, so it improves the plain CLI rather than replacing it. Cheapest thing here by effort and could be the whole answer.

difftastic, 113.99 MiB. Structural diff that compares syntax trees rather than lines, so a reindent shows as nothing changed. Genuinely clever and by far the largest thing on the list.

Two things worth settling rather than assuming.

Whether the answer is a front end or a better pager. git-delta plus the existing CLI may cover most of the complaint, at a fraction of the size and with nothing new to learn, and it composes with any of the TUIs later.

Where the configuration lives. A TUI is a package and a config file, which is straightforward. git-delta and any mergetool are gitconfig settings - and this repository has no gitconfig at all, which is TASK-37. If that lands first, this becomes a few lines in a file that already exists.

This is a keyboard-driven desktop, so a TUI in a terminal fits the session better than a GTK window, the same reasoning that has yazi being trialled against Thunar.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Whether the answer is a front end, a better pager, or both is decided rather than assumed, with the cheap option priced honestly against the featureful one
- [x] #2 Whatever is chosen is declared in packages/ and, if it needs configuration, that configuration lives in the repository rather than only on this machine
- [x] #3 It is tried on a real diff from this repository before being committed to, not chosen from a feature list
- [x] #4 Its relationship to TASK-37 is resolved: anything that is a gitconfig setting waits for that file to exist rather than creating a second home for git settings
- [x] #5 The choice is recorded in DECISIONS.md, since TASK-27 exists because tools keep being picked without a reason being written down
- [x] #6 Resolving a merge conflict is covered specifically, not assumed to fall out of whatever front end is chosen - it is the case where the bare CLI is worst and the one that decides whether a separate merge tool is also wanted
- [x] #7 The everyday path - see what changed, stage some of it, commit, push - is quicker than the bare CLI it replaces, tried on real work rather than judged from a screenshot
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Price all six candidates from the official repositories by size and by what they actually do, not from the feature list in the description.
2. Trial the shortlist for real. No sudo on this machine, so fetch the packages from a mirror and extract them to a scratch directory; drive the TUIs under a pty against a clone of this repository, and screenshot them on a throwaway sway output.
3. Decide front end vs pager on evidence, and settle the relationship to TASK-37 rather than inventing a second home for git settings.
4. Prove the everyday path (see, stage part, commit) and a real merge conflict against a clone, checking the result with git rather than by eye.
5. Declare the choice in packages/dev.txt with the reasoning, add a themed config template, a ~/.local/bin helper that resolves the repository, and a launcher entry following the theme.desktop.tmpl pattern.
6. Run checks/sway-commands.sh and checks/session.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
CHOSEN: lazygit (extra, 19.07 MiB), reached from the launcher and from ~/.local/bin/git-ui.

FRONT END OR PAGER (AC1). Both, in that order, and the order is forced rather than
preferred. git-delta is the cheap half - 4.96 MiB, a pager that makes `git diff`
readable - and it is configured in a gitconfig, which this repository does not have
until TASK-37 decides whether it should. Shipping it now would mean inventing a
second home for git settings, which AC4 exists to prevent. It also only fixes the
reading half: it does not stage a hunk and does not resolve a conflict, which are
two of the four complaints. lazygit ships explicit delta support (the binary carries
the string `delta --dark --paging=never` and a message pointing at the integration),
so TASK-37 can add delta to the CLI and to lazygit at once, and nothing here has to
change. difftastic was ruled out on size alone: 113.99 MiB, six times lazygit.

TRIALLED FOR REAL (AC3). No sudo on this machine, so the four candidates were
fetched from geo.mirror.pkgbuild.com and extracted to a scratch directory - all of
their dependencies (libgit2, oniguruma, libssh2, ncurses, pcre2, readline) were
already present. They were driven under a pty against a clone of this repository
(185 commits) and screenshotted in foot on a throwaway headless sway output.

  tig 702 KiB     `tig status` is one pane of filenames with no diff until you press
                  enter - five lines on a 1600x1000 screen. Reads well, stages badly.
  gitui 8.09 MiB  Closer. Tabs for status/log/files/stashes and a keybinding bar, but
                  the diff pane is empty until a file is selected.
  lazygit         Arrives with the diff, the 185-commit log, the branches and the
                  stash already on screen, and prints the git command behind every
                  keypress in a command log.

THE EVERYDAY PATH (AC7). Three separate hunks were made in checks/session.sh in the
clone. In lazygit: two down-arrows, enter, space, escape, c, a message, enter. The
resulting commit contains exactly hunk one (`git show --stat`: 1 file, 1 insertion,
1 deletion) and `git diff` still reports 2 hunks unstaged. The same job with
`git add -p` prints "(1/3) Stage this hunk [y,n,q,a,d,k,K,j,J,g,/,e,p,P,?]?" and
makes you answer before it will show you hunks two and three - the same keystroke
count, deciding blind. Startup is the honest cost: about a second to a full first
frame against a few milliseconds for `git status`.

MERGE CONFLICTS (AC6). A real conflicting merge was made in the clone (two branches
editing the same line of checks/session.sh). lazygit filtered the files panel to
"(only conflicting)" and offered "Pick hunk: <space> | Pick both hunks: b |
Previous/Next conflict". One keypress: the markers were gone (grep for
<<<<<<</=======/>>>>>>> returned 0) and the file was staged. So no separate merge
tool is wanted - meld, 5.64 MiB and a GTK window, would do less on a keyboard-driven
desktop and is what git mergetool would have opened.

CONFIGURATION. dot_config/lazygit/config.yml.tmpl resolves the selected palette like
every other themed consumer. It renders and parses under all eight themes. Proved
applied rather than read back: run with the ember palette the borders are #ffb347
and the selection is ember's tertiary, against the stock green and blue in the same
screenshot taken without it. selectedLineBgColor is tertiary with the default text
on top deliberately - that is the one fg/bg pair checks/session.sh already has a
contrast floor for (the focused workspace disc and its number), so a new theme
cannot land a selection you cannot read. Four non-colour settings, each with a
reason in the file: disableStartupPopups (a first-run panel would be the first thing
a new machine shows), os.editPreset (so 'e' opens nvim at the line), update.method:
never (a front end that installs its own updates is a second package manager), and
border: single (everything else on this desktop has square corners).

HOW IT IS REACHED. ~/.local/bin/git-ui, and git-ui.desktop.tmpl in the launcher
following theme.desktop.tmpl's absolute-Exec pattern. The helper exists because
`foot -e lazygit` from the launcher would open in $HOME, which is not a repository,
and lazygit's answer to that is a prompt offering to `git init` there. It resolves
the focused window's working directory instead - foot's pid, then down to the newest
leaf, then /proc/<pid>/cwd - and takes that directory's repository root. Verified:
run from a shell standing in .../trial/checks it opened a window with app_id git-ui
whose lazygit child had cwd .../trial, the repository root. Given /tmp it printed to
stderr AND raised a notification, which mako recorded (makoctl history shows
app_name git-ui, body "/tmp is not inside a git repository") - the failure is
visible rather than silent. Tiled rather than floating, so no window rule is needed:
reading a diff and writing a commit message is work you stay in, which is what
40-window-rules.conf says tiling is for.

CHECKS. checks/session.sh: 74 passed, 1 failed, 1 skipped. The failure is the
pre-existing zswap one, which was already there before this task started (baseline
run: 75 passed, 1 failed) and belongs to another task; the skip is TASK-96's, the
screenshot check standing down while the screen is locked. checks/sway-commands.sh
reports one failure, 'lazygit is not installed' - the check resolves every command
in a helper's '# requires:' header against the local package database, and this
machine has no sudo so the package could not be installed. It clears the moment
./sync.sh runs. Every other command git-ui declares (foot, git, swaymsg,
notify-send, python3) resolves.

STILL OPEN: AC5. The choice is not yet in DECISIONS.md - this session was told not
to edit that file.

PUSH (the last quarter of AC7). Trialled against a bare repository in the scratch
directory rather than a real remote: one keypress, 'P', and the remote's main
matched the local main (both 436674d). So the whole path - see, stage part, commit,
push - is four keys and a message, without leaving the window.

BINDING. $mod+g is free (checks/sway-bindings.sh lists 68 bindings and none uses g)
and sits beside $mod+e for the explorer and $mod+b for the browser, which are the
other two 'open the thing' keys. 'swaymsg bindsym Mod4+g exec ~/.local/bin/git-ui'
was accepted at runtime and unbound again; the config change was left to whoever
owns config.d/, since another session is editing that file.

DECISIONS.md entry added - 'lazygit as the git interface, and delta deliberately not yet' - which was the outstanding criterion, placed immediately before the git identity entry since the two were decided in the same batch and the second is why delta waits.

Binding added: $mod+g, beside $mod+b and $mod+e because it is the same kind of thing - a tool opened on whatever you are already looking at. checks/sway-bindings.sh now reports 69 bindings, none defined twice, and the repeat rule satisfied.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
lazygit, on $mod+g and from the launcher, opened on the focused window's repository by a helper rather than in $HOME - which is not a repository, and where lazygit would offer to git init. Chosen by driving tig, gitui and lazygit against a clone of this repository's real history: the others leave their diff pane empty until something is selected, and lazygit's advantage over 'git add -p' is that it shows all three hunks before asking about the first. A graphical merge tool was ruled out by resolving a real conflict in one keypress. git-delta is deliberately left out until the gitconfig TASK-37 introduced has settled, so git settings do not acquire a second home.
<!-- SECTION:FINAL_SUMMARY:END -->
