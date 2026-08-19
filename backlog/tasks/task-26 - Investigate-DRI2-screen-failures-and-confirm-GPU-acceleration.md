---
id: TASK-26
title: Investigate DRI2 screen failures and confirm GPU acceleration
status: To Do
assignee: []
created_date: '2026-08-19 19:08'
labels:
  - foundation
  - performance
dependencies: []
references:
  - 'https://bbs.archlinux.org/viewtopic.php?id=293632'
priority: medium
type: spike
ordinal: 25000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Running sway --validate on the VM prints "failed to create dri2 screen" warnings. This is a libEGL message emitted when Mesa cannot create a hardware DRI screen and falls back to software rendering - swrast or zink rather than a real GPU driver.

On the VM this is very likely expected, because virtio-gpu without 3D acceleration enabled has no hardware path to offer, and everything still works because llvmpipe renders in software. It is worth confirming rather than assuming, for two reasons. First, software rendering is exactly the thing that produces dropped frames and a desktop that does not feel immediate, which is the opposite of the goal. Second, if the same warning appears on real hardware it means no acceleration there either, and that would be a genuine problem rather than a VM artefact.

Not caused by the config.d restructure in TASK-17: nothing in that change touches outputs, renderers or EGL, and the warning appears during backend probing rather than config parsing.

Worth establishing what the setup should require of a GPU, since setup/packages/ currently declares no Mesa or Vulkan packages at all and relies entirely on whatever arrives as a dependency of sway.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The cause of the warning on the VM is identified, and whether it indicates software rendering is confirmed rather than assumed
- [ ] #2 It is established whether the same warning appears on real hardware, and if so why
- [ ] #3 Whether the compositor is hardware accelerated is verifiable with a documented command rather than inferred from the absence of warnings
- [ ] #4 Any graphics packages the setup should declare explicitly rather than inherit as dependencies are identified
- [ ] #5 If the warning is harmless on the VM, that is written down so it is not re-investigated later
<!-- AC:END -->
