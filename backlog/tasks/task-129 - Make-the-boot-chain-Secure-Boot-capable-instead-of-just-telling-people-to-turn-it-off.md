---
id: TASK-129
title: >-
  Make the boot chain Secure-Boot-capable instead of just telling people to turn
  it off
status: To Do
assignee: []
created_date: '2026-08-22 19:37'
labels: []
dependencies: []
ordinal: 133000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-128 closed the gap where the install docs never mentioned Secure Boot at all, by documenting the quick answer: disable it in firmware before installing, because 03-system.sh's bootctl install writes an unsigned systemd-boot binary and an unsigned kernel image that a Secure-Boot-on machine refuses to execute.

That answer is correct but leaves value on the table, particularly for a laptop: Secure Boot defends the boot chain against tampering (an evil-maid attack, a bootkit written to the ESP) during the window a machine is out of your hands, which is exactly the laptop's threat model. It is not a substitute for full-disk encryption (this repo deliberately has none, see DECISIONS.md) - it says nothing about data confidentiality if the drive itself is read on another machine - but it is a real, close-to-free layer once set up.

The standard Arch-native way to keep Secure Boot on rather than off is sbctl: generate your own signing keys, enroll them into firmware, and sign systemd-boot and the kernel image with them. Two things make this more than a one-line fix:

1. Key enrollment requires the firmware to be in 'Setup Mode', which cannot be scripted from a running OS - that's deliberate, so a compromised OS can never silently add a trusted key. This has to stay a manual, once-per-machine, documented step.
2. Once enrolled, ongoing signing has to be automated (a pacman hook that re-signs systemd-boot and the kernel image after every update that touches them), or the very next kernel upgrade produces a machine that boots today and silently refuses to boot after 'sync.sh' - exactly the invisible-failure pattern this repository keeps hitting.

VMs do not need special-casing: OVMF (the usual VM firmware) ships Secure Boot off by default, so nothing here should force signing on a machine where it was never on to begin with.

Worth deciding when this is picked up, not now: whether plain systemd-boot signing (bootloader + kernel PE binaries, but NOT the initramfs, which UEFI's verification does not cover) is enough, or whether it is worth moving to a Unified Kernel Image (kernel+initrd+cmdline as one signed EFI binary) to close that gap.

Not install-time-only: signing can be layered onto an already-installed machine, so this does not block installing the laptop with Secure Boot off today per TASK-128's current guidance.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 sbctl is added to the appropriate package manifest and checks/packages.sh passes
- [ ] #2 A documented one-time procedure exists (in docs/manual/09-installing.md or a recipe chapter) for entering firmware Setup Mode, generating and enrolling sbctl keys, and signing the installed systemd-boot binary and kernel image
- [ ] #3 A pacman hook re-signs the boot binaries automatically after a kernel or systemd-boot package update, so a routine sync.sh or system update does not produce an unbootable Secure-Boot machine
- [ ] #4 docs/manual/09-installing.md and README.md's pre-install checklists are updated so Secure Boot can be kept on and made boot-chain-friendly, not only turned off, superseding TASK-128's guidance
- [ ] #5 A decision is recorded (DECISIONS.md or the task itself) on whether plain kernel+bootloader signing is sufficient or a Unified Kernel Image is worth adopting to also cover the initramfs
<!-- AC:END -->
