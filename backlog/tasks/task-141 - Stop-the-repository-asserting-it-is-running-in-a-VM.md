---
id: TASK-141
title: Stop the repository asserting it is running in a VM
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 11:06'
updated_date: '2026-08-23 11:12'
labels: []
dependencies: []
priority: medium
type: chore
ordinal: 145000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Several tracked files state as fact that the machine is a KVM guest. That was true of the reference machine and is not true of the ThinkPad this repo now runs on, so the claims are both machine-specific and wrong - and the setup is meant to be generic enough to publish.

The Caps Lock LED note is the clearest case. setup/system/keyd/default.conf says 'IT IS THE VM, AND ONLY THE VM' and predicts the LED will behave correctly on physical hardware, then explicitly asks whoever boots it on metal to come back and correct it whichever way it goes. TASK-133 is the first time this build has run on real hardware, so that invitation is now claimable - and it has to be measured, not assumed, because the comment's whole point is that it was reasoned about rather than observed.

Sites found:
  setup/system/keyd/default.conf:153,162   Caps Lock LED, asserts KVM guest
  docs/manual/03-the-keyboard.md:245,251   same, as a 'Known limitation'
  docs/manual/09-installing.md:209         same
  setup/dotfiles/dot_config/cava/config.tmpl:16   'this desktop is CPU-rendered in a VM'
  setup/dotfiles/dot_config/fastfetch/config.jsonc:22   refers to the VM rendering entry
  docs/manual/02-the-desktop.md:155        battery module 'expected for a VM'

Explicitly NOT in scope, having been checked: sway's 'output Virtual-1 resolution 1920x1080' in 20-output.conf is named deliberately so it is inert on any machine without a QEMU output, and its comment already says so. Phrases like 'measured on this machine' elsewhere are provenance rather than machine-specific claims and should stay.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The Caps Lock LED behaviour is measured on physical hardware and the keyd comment records what was observed rather than what was expected
- [x] #2 No tracked file outside backlog/ states that the machine is a VM or KVM guest as a fact
- [x] #3 Wording that is genuinely conditional (behaviour differs on a VM) is phrased as a condition, not as this machine's identity
- [x] #4 checks/manual.sh and checks/session.sh still pass and the manual still builds
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Measured on the ThinkPad, which is the first time this build has run on physical hardware:

  input3::capslock   (AT Translated Set 2 keyboard, phys isa0060/serio0)  0 -> 1 across a tap
  input26::capslock  (keyd virtual keyboard)                              0 -> 1 across a tap

and the user confirms there is a physical lamp on the Caps Lock key and that it lights. So the prediction the old comment recorded as 'an expectation and not a result' is confirmed: the LED follows caps state on real hardware, and the VM behaviour was the guest having no lamp attached rather than anything in this repository.

Secondary finding worth keeping: sway sets LED state on a device keyd holds an exclusive grab on. A grab blocks other readers, not LED writes.

Also confirmed incidentally: overloadt2(scroll, capslock, 200) behaves as designed on real hardware - hold gives the scroll layer with no caps, tap gives caps.

Corrected six sites: keyd/default.conf (the LED block), manual ch3 and ch9 (the 'Known limitation' and 'VM artefact' paragraphs), cava/config.tmpl, fastfetch/config.jsonc, manual ch2 (battery). The battery claim was independently stale as well as VM-specific: this machine reports BAT0 at 67% and waybar logs no battery complaint.

Left alone deliberately, having been checked: sway's 'output Virtual-1 resolution 1920x1080' is named so it is inert without a QEMU output and its comment says so; DECISIONS.md:2021 phrases the VM case as a condition and describes how checks/session.sh distinguishes it; 'measured on this machine' elsewhere is provenance, not a machine-specific claim.

Note for anyone writing about these devices: keyd's virtual keyboard moved from input24 to input26 during this session, because restarting keyd tears the device down and recreates it. Do not pin an inputN number in prose.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed every claim in tracked files that this build runs in a VM, and settled the one that could only be settled on real hardware.

The keyd config recorded the Caps Lock LED not following caps state as a VM artefact, predicted it would resolve on physical hardware, said plainly that this was an expectation rather than a result, and asked whoever booted on metal to correct it. Measured: both /sys/class/leds caps entries - the real i8042 keyboard's and keyd's virtual one - go 0 to 1 across a tap, and there is a lit lamp on the key. The prediction was right, and the comment now records the observation instead.

Six sites corrected across setup/system/keyd/default.conf, docs/manual/02, 03 and 09, cava/config.tmpl and fastfetch/config.jsonc. Three sites deliberately left: the named Virtual-1 output rule, DECISIONS.md's conditional phrasing, and 'measured on this machine' provenance notes.

Verified with checks/manual.sh 8/0, checks/session.sh 92/0, sway-bindings, packages and sway-commands all passing, keyd check clean, and the manual rebuilt.
<!-- SECTION:FINAL_SUMMARY:END -->
