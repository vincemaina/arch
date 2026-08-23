---
id: TASK-69.1
title: >-
  Run virtual machines at all: qemu, and a vm command that clones and launches
  them
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 15:57'
updated_date: '2026-08-23 16:41'
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
- [x] #1 qemu and OVMF are declared in the manifests and marked explicit, so checks/packages.sh passes
- [x] #2 A VM can be created by cloning a qcow2 and launched full-screen with KVM acceleration
- [x] #3 The image directory is nodatacow before any image is written into it
- [x] #4 A running guest is protected from earlyoom, and its memory is capped so that protection cannot starve the host
- [x] #5 checks/sway-commands.sh and checks/packages.sh both pass
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

VERIFICATION (all on this machine, 2026-08-23)

AC1: checks/packages.sh 6/0, 'The manifests describe this machine.' Note a mistake worth recording: installing with 'pacman -S --asexplicit' marks every package in the TRANSACTION explicit, dependencies included, which produced 20 failures. sync.sh does not have this bug - it marks only declared packages. Repaired with pacman -D --asdeps on the 20 the check named.

AC2: clone harness 10/10 - new, list, reset, reset-refuses-a-whole-disk, rm. An overlay on a 10 GiB base is 196 KiB with a correct absolute backing file. Boot proven by screenshot on a throwaway headless output: TianoCore renders, then Boot0002 not found and PXE fallback, which is exactly right for an empty disk and proves firmware discovery, pflash pairing and the display path. /proc/PID/cmdline confirms -machine q35,accel=kvm and -device virtio-vga-gl. Caveat: the guest filled a tiled sway window rather than being literally fullscreen; true kiosk full-screen arrives with TASK-69.3.

AC3: lsattr shows C on ~/.local/share/vm AND on probe/disk.qcow2 inside it. The inheritance is the part that matters - it proves the attribute was set before any file existed, not merely that it is set.

AC4: /proc/PID/cmdline of the running earlyoom shows --avoid ^(...|qemu-system-x86)$. Read from the process, because systemctl show reports the unit file with $EARLYOOM_ARGS unexpanded. The cap is real too: the booted guest ran with -m 3840, from vm.conf. earlyoom.conf is in apply-config.sh's file map, so it reaches a running machine through sync.sh and not only a fresh install.

AC5: sway-commands 0 failures, packages 6/0.

Also: session 102/0, manual 8/0 (now counting 10 helpers, so it sees vm), bindings clean, and the 15-case offline harness 15/0.

FINDING THAT CHANGED THE PACKAGE LIST. Two -gl display packages were not enough. The -gl devices are subclasses of the plain ones, so with only the -gl modules installed qemu listed NEITHER - '-device help' showed no virtio device at all and nothing explained why. Four packages are needed. The runtime detection is what surfaced this: it fell through to std VGA instead of failing, which is the behaviour it was written for.

LEFT BEHIND: nothing. The probe machine and the stand-in base image were removed; 'vm list' reports an empty store. /etc/default/earlyoom was updated in place with pkexec, matching what apply-config.sh would install.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Declares qemu and drives it from ~/.local/bin/vm - list, new, run, rm, reset, --current, and a rofi menu. Machines are one directory each under ~/.local/share/vm/, and one cloned from the base image is a qcow2 overlay rather than a copy, so it costs 196 KiB against a 10 GiB base and appears instantly.

No libvirt: both run the same qemu with the same guest RAM, so the ~100-300 MiB difference is scaffolding rather than the point. Chosen for fewer moving parts and for skipping the SPICE round trip. Full rationale, with the numbers, in DECISIONS.md.

Nine packages rather than the five planned. The virtio display devices are separate packages in Arch, and all four are needed: the -gl devices are subclasses of the plain ones, so with only the -gl modules installed qemu lists neither and says nothing about why. The script asks '-device help' what exists and degrades to std VGA with a warning rather than asserting, which is how that was found.

qemu joins earlyoom's --avoid list, paired with a fixed -m, because killing a guest is a power cut to the machine inside it. The two are one decision: an exemption without a cap is a host that cannot defend itself.

Verified against the running system rather than the files: a blank machine boots to TianoCore and falls through to PXE (screenshot, taken on a throwaway headless output so the user's screen was untouched); /proc/PID/cmdline confirms KVM and virtio-vga-gl; nodatacow is inherited by the disk image, which proves the ordering and not just the attribute; and the running earlyoom really does avoid qemu, read from its cmdline because systemctl show reports the unit file unexpanded. Checks: session 102/0, packages 6/0, manual 8/0, sway-commands clean, bindings clean, plus 25 cases across two purpose-built harnesses.

One general bug found by testing: 'cond && action' as the last statement of a function or loop body is fatal under set -e - the script exits silently having printed nothing. 'vm rm' on a stopped machine would have been the first casualty. Every such site is now a full if block.
<!-- SECTION:FINAL_SUMMARY:END -->
