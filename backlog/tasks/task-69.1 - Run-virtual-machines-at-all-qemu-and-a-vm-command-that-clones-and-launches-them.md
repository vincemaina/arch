---
id: TASK-69.1
title: >-
  Run virtual machines at all: qemu, and a vm command that clones and launches
  them
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-23 15:57'
updated_date: '2026-08-23 16:24'
labels: []
dependencies: []
parent_task_id: TASK-69
ordinal: 160000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The foundation: make this machine able to run VMs, and give it one command to manage them. Nothing here depends on the bundled image existing yet - an unrelated ISO or an existing qcow2 is enough to prove it.

Scope:

  * Declare the packages. Prefer explicit top-level entries over the qemu-desktop/qemu-base meta-packages, matching how the manifests already work: qemu-system-x86, qemu-img, a UI package, and edk2-ovmf (the disk layout is GPT/UEFI, so the guest must boot UEFI and needs firmware plus a per-VM copy of the OVMF vars file).
  * A vm helper in setup/dotfiles/dot_local/bin/ covering list, new (clone), run, rm and reset. It needs a "# requires:" header or checks/sway-commands.sh fails, and it must call sibling helpers by absolute path - a helper calling a sibling by bare name is a known failure mode here.
  * Decide and document where images live (~/.local/share/vm/ is the obvious candidate) and set nodatacow on that directory at creation - chattr +C only takes effect on a directory BEFORE files are created inside it, so doing this late silently does nothing.
  * Add qemu to earlyoom's --avoid list in setup/system/earlyoom.conf. Killing a guest is a power cut to it. The comm is "qemu-system-x86", exactly the 15 bytes earlyoom matches on. This is only safe alongside a capped -m, so the cap is part of this task, not an afterthought.

Since setup/packages/ changes, docs/software/README.md or DECISIONS.md must change with it - the keep-the-record hook checks exactly this and will name the packages added.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 qemu and OVMF are declared in the manifests and marked explicit, so checks/packages.sh passes
- [ ] #2 A VM can be created by cloning a qcow2 and launched full-screen with KVM acceleration
- [ ] #3 The image directory is nodatacow before any image is written into it
- [ ] #4 A running guest is protected from earlyoom, and its memory is capped so that protection cannot starve the host
- [ ] #5 checks/sway-commands.sh and checks/packages.sh both pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Declare packages in setup/packages/desktop.txt, NOT a new manifest. sync.sh globs packages/*.txt but 04-desktop.sh names desktop.txt and dev.txt explicitly, so a fourth file would work on sync and silently not on a fresh install - the exact asymmetry CLAUDE.md warns about. desktop.txt over dev.txt because TASK-69.3 makes this a login session and qemu-ui-gtk is a graphical package.
   Packages: qemu-system-x86, qemu-img, qemu-ui-gtk, qemu-audio-pipewire, edk2-ovmf.
   edk2-ovmf is ALREADY a dependency of qemu-system-x86 and is declared anyway for the documented reason polkit and mesa are: the vm script names the firmware file directly, so a dependency-graph change must not be able to remove it quietly.
   Measured: qemu-system-x86 55 MiB, qemu-img 10.7, edk2-ovmf 15.6, qemu-ui-gtk 0.13 plus vte3 1.8, qemu-audio-pipewire 0.09. gtk3 is already installed, which is why GTK beat SDL - ~2 MiB difference, and GTK gives zoom-to-fit and a disableable menubar.

2. Write setup/dotfiles/dot_local/bin/executable_vm: list, new, run, rm, reset, and a rofi menu with no arguments. Carries a "# requires:" header (checks/sway-commands.sh fails without one) and resolves siblings through readlink -f on $0, never by bare name.

3. Storage: one directory per VM under ~/.local/share/vm/<name>/ holding disk.qcow2, that VM's own OVMF_VARS copy, and a vm.conf with memory and cpus. Set nodatacow on the parent BEFORE any image exists - chattr +C on an existing file silently does nothing.

4. Discover the OVMF firmware path at runtime rather than hardcoding it. Arch has moved this path before, the files database is not synced here so it cannot be read from the package, and a wrong hardcoded path is exactly the invisible-configuration failure this repository keeps hitting. Search known locations, fail loudly naming what was tried.

5. Cap guest memory and cpus by default, computed from the host at creation and written into vm.conf so it is visible and editable. This cap is what makes step 6 safe.

6. Add qemu to --avoid in setup/system/earlyoom.conf. Killing a guest is a power cut to it, not a lost browser tab. comm is "qemu-system-x86", exactly the 15 bytes earlyoom matches on.

7. Update docs/software/README.md and DECISIONS.md - setup/packages/ changed, so the keep-the-record hook requires it.

8. Run checks/packages.sh, checks/sway-commands.sh, checks/session.sh. Boot a real VM before claiming criterion 2.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation written and checked as far as is possible without the packages installed.

Done: packages declared in desktop.txt (7, not 5 - the virtio display devices turned out to be separate packages from qemu-system-x86 in Arch, so naming virtio-vga-gl without them would fail at start with an unknown-device error, which is exactly this repository's invisible-configuration failure); ~/.local/bin/vm written; qemu added to earlyoom --avoid; DECISIONS.md, docs/software/README.md and manual chapter 4 updated; ~/.local/share/vm registered in checks/manual.sh as created-on-first-use, matching the existing precedent for ~/Pictures/wallpapers.

Verified: checks/session.sh 98/0, checks/manual.sh 8/0 (and it now counts 10 helpers rather than 9, so it sees vm). checks/packages.sh reports exactly the 7 declared-but-not-installed and nothing else. checks/sway-commands.sh reports only qemu-img and qemu-system-x86_64 as not installed - every other command in the requires header resolves.

A 15-case harness for the parts that do not need qemu passes 15/0, and it demonstrably goes red: it failed once on a wrong expectation before being corrected, so the green is worth something.

Two findings worth keeping:

  * nodatacow is CONFIRMED working, not assumed - lsattr on a freshly created store on real Btrfs reports ---------------C------.
  * 'cond && action' as the LAST statement of a function or loop body is fatal under set -e: the function returns the failed condition's status and the script exits silently having printed nothing. Demonstrated in this session; 'vm rm' on a stopped machine would have been the first casualty. Every such site in the script is now a full if block, with a comment saying why. This is a general trap and is not in the scripting-traps skill.

Blocked on one thing only: the packages need installing before the clone, run, OVMF-discovery and device-detection paths can be exercised, and sudo needs a password.
<!-- SECTION:NOTES:END -->
