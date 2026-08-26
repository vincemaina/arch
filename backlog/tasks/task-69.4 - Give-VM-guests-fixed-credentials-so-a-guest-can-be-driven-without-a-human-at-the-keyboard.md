---
id: TASK-69.4
title: >-
  Give VM guests fixed credentials so a guest can be driven without a human at
  the keyboard
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-26 11:12'
updated_date: '2026-08-26 11:24'
labels:
  - vm
  - repo
dependencies: []
parent_task_id: TASK-69
priority: medium
type: feature
ordinal: 190000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The base image's user and passwords come from setup/install.conf and from two interactive passwd prompts in 03-system.sh. That means a guest cannot be used by anything that is not a person sitting at it: there is no password to give sudo, and no way to enable sshd, so every measurement or experiment inside a guest has to be typed into a qemu window by hand.

The user's decision, in their own words: a VM override only, on the grounds that these guests already sit behind the host's own login and are not intended for confidential work. Username 'user', password 'password'.

WHAT IS ALREADY TRUE, AND WAS MISREAD ONCE TODAY

The guest already logs itself in. build-vm-image.sh appends an [initial_session] block to the GUEST's /etc/greetd/config.toml running 'uwsm start -N Sway -D sway -- sway' as $USERNAME, gated on a /run runfile so it fires on every boot. Confirmed by screenshotting a running clone: it comes up at the desktop with waybar, a wallpaper and workspace 1, with no prompt at any point. So this ticket is NOT about getting into the guest. It is about having a credential for sudo and for sshd once inside.

THE BOUNDARY THAT MATTERS

USERNAME is read by real installs and by the VM builder from the same file. Changing setup/install.conf itself would rename the user on real hardware, including the desktop this build is about to be installed on. The override must therefore be the builder's alone.

The mechanism is already available and needs no new invention: build-vm-image.sh copies the whole setup/ tree to /mnt/opt/arch-setup (line 346), and both 03-system.sh and 05-dotfiles.sh source $SETUP_ROOT/install.conf, which is that COPY. Overriding the copy after it is made reaches every stage without the repository's own install.conf changing.

Note the trap: build-vm-image.sh also sources $REPO_ROOT/setup/install.conf directly (line 390) and uses $USERNAME for the wallpaper --ensure step and for the auto-login block it writes. Overriding only the copy would leave those two pointing at the wrong user, and the failure would be a guest that auto-logs into an account that does not exist. Guest identity should be decided once in the builder and used by both.

Passwords are the harder half. 03-system.sh sets them with an interactive passwd, wrapped in a five-attempt retry that exists because of TASK-131. Whatever makes them presettable has to leave that path exactly as it is when nothing opts in, since it is the path every real install takes.

THIS REVERSES A WRITTEN DECISION, PARTLY

DECISIONS.md has a 'Passwords' section, and build-vm-image.sh's own header carries a 'WHY PASSWORDS ARE STILL INTERACTIVE' block stating that the script reads a password from nowhere. Both become untrue for guests once this lands and both must be updated in the same change - a comment that describes a stance the code no longer takes is the failure mode this repository has already been bitten by. The stance for REAL installs does not change at all and should be restated as such.

The builder's header also claims every stage script is used 'completely unmodified'. If the chosen mechanism touches 03-system.sh, that claim needs correcting rather than quietly falsifying.

COST TO BE AWARE OF

The existing ~/.local/share/vm/base.qcow2 was built with typed passwords and is unaffected by a code change alone. New credentials only exist in a REBUILT base image, which is a full pacstrap as root and takes tens of minutes. Any clone made from the old base keeps the old credentials.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A base image built by tools/build-vm-image.sh has user 'user' with password 'password', and root reachable, with no human typing a password during the build
- [x] #2 setup/install.conf is byte-identical before and after the change, and a real install still prompts for both passwords exactly as it does today
- [x] #3 The guest's username is decided in one place in the builder, so the auto-login block and the wallpaper --ensure step cannot disagree with the account the stages actually created
- [ ] #4 sudo works inside a guest as 'user' with that password, verified in a booted guest rather than inferred from the build
- [ ] #5 sshd can be enabled inside a guest and reached from the host, so a guest can be driven without the qemu window
- [x] #6 DECISIONS.md and build-vm-image.sh's header state the new position for guests and the unchanged one for real installs, and no comment anywhere still claims the builder reads a password from nowhere
- [x] #7 If a stage script is modified, build-vm-image.sh's claim that stages are used completely unmodified is corrected in the same change
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED, NOT YET VERIFIED END TO END. The code change is complete and the parts testable without root are tested; the parts that need a rebuilt base image are not, because build-vm-image.sh requires root and this machine has no passwordless sudo. Three acceptance criteria are deliberately left unchecked for that reason and are named below.

WHAT CHANGED, IN THREE PLACES

tools/build-vm-image.sh. A 'Guest identity' block after the payload copy defines GUEST_USERNAME=user and GUEST_PASSWORD=password, rewrites USERNAME in the COPIED install.conf at /mnt/opt/arch-setup/install.conf, and asserts in both directions: that the copy really changed, and that $REPO_ROOT/setup/install.conf did not. The second assertion compares against the USERNAME line captured before the edit rather than grepping for the guest name, because a machine whose real configured username happened to be 'user' would make the naive check fire on a file nothing had touched. Stage 3 is then invoked with GUEST_PRESET_PASSWORD in its environment. The later 'source $REPO_ROOT/setup/install.conf' is replaced by USERNAME="$GUEST_USERNAME" - that line was correct only while the two agreed, and after this change sourcing the repository's file would point the wallpaper --ensure step and the auto-login block at an account 03-system.sh never created.

setup/install/03-system.sh. The two set_password calls are now the else branch of 'if [[ -n ${GUEST_PRESET_PASSWORD:-} ]]', whose then branch uses chpasswd. chpasswd rather than piping into passwd because passwd reading from a pipe fails instantly - the same property the existing five-attempt bound exists to survive.

Docs. DECISIONS.md's 'Passwords' section rewritten to record the split, how the boundary is enforced, the trade-off and four rejected alternatives. build-vm-image.sh's header 'WHY PASSWORDS ARE STILL INTERACTIVE' block said the script reads a password from nowhere, which this change makes false, and now says so explicitly rather than being quietly deleted. Its 'every stage script is used completely unmodified' claim is corrected to 'no stage script is edited or patched at build time', with the one behavioural difference named.

MANUAL. Two passages were actively wrong rather than merely incomplete, and neither would have been caught by checks/manual.sh, which checks paths, helpers and bindings but not the truth of prose. 04-applications.md said the builder 'asks for a root password and a user password partway through - so it needs a real terminal to run in, not a script driving it'. 08-recipes.md said 'Run this yourself, at a real terminal - not through a script that pipes answers into it' and that the builder 'does not weaken' the interactive stance. Both corrected, and the recipe now also warns that rebuilding the base invalidates every existing clone.

VERIFIED WITHOUT ROOT

  * bash -n clean on both changed scripts.
  * The install.conf override tested in isolation on a real copy: USERNAME="vincemaina" -> USERNAME="user"; the result still sources cleanly under set -eu; and a diff of both files with the USERNAME line removed is empty, so nothing else in the file is touched. The KEY="value" quoting the wizard writes is preserved, which matters because dot_gitconfig.tmpl matches on it - its regex is (?m)^[A-Z_]+="[^"]*" and still matches.
  * Branch selection tested both ways under set -euo pipefail: unset takes the interactive path, set takes the preset path. The :- guard means set -u does not fire on a real install.
  * arch-chroot environment inheritance CHECKED rather than assumed, by reading /usr/bin/arch-chroot: line 223 is a plain chroot with no env -i, and the --reset-env at line 207 is only on the -S systemd-run path this builder does not use. So GUEST_PRESET_PASSWORD reaches the stage.
  * git diff --exit-code setup/install.conf is clean.
  * checks/session.sh 133 passed 0 failed 0 skipped - identical to main, as expected since nothing here touches the running session. checks/manual.sh 8 passed 0 failed.

NOT VERIFIED, AND WHY

AC #1 (a built image really has these credentials), #4 (sudo works in a booted guest) and #5 (sshd reachable from the host) all need a rebuilt base image. tools/build-vm-image.sh requires root, this machine has no passwordless sudo, and the rebuild is a full pacstrap taking tens of minutes. It has to be run by the user.

REBUILD HAZARD, FOUND WHILE PREPARING THIS. ~/.local/share/vm/base.qcow2 is the BACKING FILE of every clone. 'vm list' currently shows one, 'login', with 148M of real writes, and qemu-img info confirms its backing file is that base. Rebuilding in place would corrupt it. Either delete that machine first or build to a different path with --output. This is now warned about in the recipe chapter too.
<!-- SECTION:NOTES:END -->
