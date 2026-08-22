---
id: TASK-86
title: add wizard to the initial arch setup tool
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 16:29'
updated_date: '2026-08-22 01:04'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 88000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a wizard that helps you configure your arch installation
- which feature packs i want to load if any e.g. music, development
- possibly later it might ask me which DEs (including window managers) e.g. sway, cosmic, hyprland I want to install that could be just one or multiple
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Running ./install.sh <disk> with no extra flags asks for USERNAME, HOSTNAME, TIMEZONE, LOCALE, KEYMAP, GIT_NAME and GIT_EMAIL before anything destructive happens, defaulting each to the value already in setup/install.conf
- [x] #2 Every answer is validated against the live system (zoneinfo entry, /etc/locale.gen entry, kbd keymap, useradd/RFC1123 name rules) and against the KEY="value" quoting that 03-system.sh sources and dot_gitconfig.tmpl parses; an invalid answer is re-asked, never written
- [x] #3 The wizard writes setup/install.conf in place, keeping every comment, and the result is source-able by the stage scripts and parseable by dot_gitconfig.tmpl
- [x] #4 The non-interactive path is preserved: ./install.sh --no-wizard, and any run whose stdin is not a terminal, skips the wizard entirely and uses the committed install.conf
- [x] #5 Passwords are still never prompted for by the wizard and never written to install.conf
- [x] #6 The wizard is exercisable without running install.sh - a standalone script driven by piped answers, with its output verified source-able
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add setup/install/00-wizard.sh: a standalone bash+coreutils script that reads setup/install.conf for its defaults, asks for USERNAME, HOSTNAME, TIMEZONE, LOCALE, KEYMAP, GIT_NAME and GIT_EMAIL, validates each against the live system, and rewrites only the KEY="value" lines of install.conf in place.
2. Validate against what actually consumes each value, not against a regex alone: zoneinfo file exists; the locale has a '<name> UTF-8' line in /etc/locale.gen and carries the .UTF-8 suffix (03-system.sh writes LANG verbatim); the keymap is a real file under /usr/share/kbd/keymaps; the value contains no " \ ` $ or control character, because 03/05 source the file and dot_gitconfig.tmpl parses it with ^[A-Z_]+="[^"]*".
3. Verify before replacing: render to a temp file next to the target, source it back in a clean subshell, compare to the answers, re-check the gitconfig regex, then chmod --reference and mv. Any mismatch aborts and leaves the original.
4. Wire it into install.sh as step [0/5], before 01-disk.sh, with real option parsing: --no-wizard skips, --wizard forces, and with neither flag the wizard runs only when stdin is a terminal - so scripted builds keep working untouched. Echo the resulting identity in both paths.
5. Exercise it without running install.sh: drive the wizard with piped answers, and drive a truncated copy of install.sh that stops before the disk stage.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
No TUI. dialog and whiptail are not on the Arch install medium, so a wizard built on either would have to install a package before it could ask its first question. The wizard is bash + coreutils + awk/find and the data files tzdata, glibc and kbd already ship, all of which are on the ISO.

The wizard rewrites setup/install.conf in place rather than writing a separate override, because install.conf has two consumers with two different parsers and both have to see the answers: 03-system.sh and 05-dotfiles.sh source it, and setup/dotfiles/dot_gitconfig.tmpl parses it through chezmoi's include "../install.conf". An override file would have needed a change to 03-system.sh, and would have left the git identity behind.

Values that would break either parser are refused at the prompt: " \\ ` $ and control characters. The finished file is then sourced back in a clean subshell (env -i bash --noprofile --norc) and compared to the answers, and each key is re-checked against the gitconfig regex, before it is allowed to replace the original. An install.conf that does not source would only fail three stages later, inside a chroot, on a machine with no way to edit it.

Two pipefail traps from the scripting-traps skill were hit while writing this and are fixed in the file: grep -q closing the pipe on printf (now grep -c compared to 0), and head -12 doing the same (now || true). Both would have made a suggestion list abort the wizard.

Deliberately NOT done, and still open from the task description: choosing feature packs (music, development) and choosing which desktops/window managers to install. Both need a change to the package manifests and to 04-desktop.sh's single desktop+dev install, which is a larger design question than machine identity. No follow-up task was created without approval.

Verification, without running install.sh (it erases a disk). Two harnesses, both driven by piped answers:

(a) The wizard directly, against a throwaway copy of install.conf - 53 assertions, all passing: pressing Enter through every prompt leaves the file byte-identical; a full set of new answers sources back exactly, keeps every comment and the line count; bad answers for all six validated fields are re-asked and never written; a value containing " or $ is refused; ? and ?text list and search timezones, locales and keymaps; n aborts and r starts over with the answers as the new defaults; running out of input aborts with a pointer to --no-wizard; --output writes elsewhere; a key missing from the file is appended. The verify step was then proven able to fail by sabotaging render() to emit an unquoted line - the guard fired and the target file was untouched.

(b) install.sh's new lines, via a copy truncated two lines before 01-disk.sh with only the root check neutralised - 27 assertions, all passing: no disk, unknown option and two disks each exit 1 with usage; --no-wizard and a non-terminal stdin both skip the wizard and leave install.conf untouched; --wizard drives it from a pipe and the answers reach install.conf before the disk stage; aborting the wizard never reaches the disk stage.

(c) The two real consumers, against a wizard-written install.conf: chezmoi --source <copy> execute-template < dot_gitconfig.tmpl rendered name = Zoe Q. Example / email = zoe@example.com; and sourcing the file then running 03-system.sh's own sed against a copy of /etc/locale.gen un-commented the fr_FR.UTF-8 line, with the zoneinfo file and the fr keymap both present.

./checks/session.sh: 81 passed, 0 failed, 0 skipped.

Scope settled rather than silently narrowed. The identity half is done; the feature packs and the choose-a-desktop question are TASK-99, because they are a different problem - they need setup/packages/ to grow a notion of optional membership and 04-desktop.sh to install a selection, and the second is entangled with TASK-31 and TASK-32. Splitting them was preferred to leaving this ticket open indefinitely against work nobody has decided to do.

Documentation applied to the files the implementing agent was not permitted to edit: README's install section now describes the wizard and both non-interactive routes; CLAUDE.md's stage table lists 00-wizard.sh on the live-ISO row and the install.conf section records that the wizard is the only non-human writer of that file; DECISIONS.md has an entry covering why a wizard at all, why not dialog or whiptail, and why it rewrites install.conf rather than using an override.

Verified independently rather than accepted: pressing Enter through every prompt against a copy leaves the file byte-for-byte identical, a full answer set sources back in a clean environment with all seven values correct, all sixteen comment lines survive, and the real setup/install.conf is untouched by any of it.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-08-22 01:01
---
The identity half of this task is finished and verified (see the final summary). The other half of the description - choosing feature packs (music, development), and later choosing which desktops/window managers to install - is not started: it needs the package manifests split into optional sets and 04-desktop.sh taught to install a selection, which is a bigger change than machine identity and touches files another agent may be in. Leaving this In Progress rather than closing it. Do you want it split into a follow-up task so this one can go to Done, or added to this task's scope?
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
install.sh now asks for the machine identity before anything destructive, as step [0/5] ahead of the disk stage, defaulting every answer to what setup/install.conf already says so pressing Enter through it is a no-op. Answers are validated against the live system rather than a pattern - a real zoneinfo file, a real /etc/locale.gen line carrying .UTF-8 because 03-system.sh writes LANG verbatim, a real keymap - and the result is rendered, sourced back in a clean environment and compared key by key before it replaces anything. No TUI: dialog and whiptail are not on the Arch install medium. The non-interactive path is preserved twice over, by --no-wizard and by stdin not being a terminal, so existing scripted builds need no new flag. Feature packs and choosing a desktop are split to TASK-99 as a different and larger problem.
<!-- SECTION:FINAL_SUMMARY:END -->
