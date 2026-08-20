---
id: TASK-26
title: Investigate DRI2 screen failures and confirm GPU acceleration
status: Done
assignee:
  - '@claude'
created_date: '2026-08-19 19:08'
updated_date: '2026-08-20 23:51'
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
- [x] #1 The cause of the warning on the VM is identified, and whether it indicates software rendering is confirmed rather than assumed
- [ ] #2 It is established whether the same warning appears on real hardware, and if so why
- [x] #3 Whether the compositor is hardware accelerated is verifiable with a documented command rather than inferred from the absence of warnings
- [x] #4 Any graphics packages the setup should declare explicitly rather than inherit as dependencies are identified
- [x] #5 If the warning is harmless on the VM, that is written down so it is not re-investigated later
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Cause established from three independent signals rather than inferred from one.

The kernel, at boot: "[drm] features: -virgl +edid -resource_blob -host_visible" and "number of cap sets: 0". Xwayland, in the user journal: "Refusing to try glamor on llvmpipe" followed by "EGL setup failed, disabling glamor". Mesa: "libEGL warning: egl: failed to create dri2 screen".

So the answer is -virgl. The virtio GPU is presented to the guest without 3D acceleration, Mesa has no hardware path to a DRI screen, and it falls back to llvmpipe - the LLVM software rasteriser. The DRI2 warnings are the symptom of that rather than a fault in the configuration, and the desktop is being drawn by the CPU.

Nothing inside the guest can change it. 3D is enabled on the hypervisor side: in virt-manager, Video set to virtio with 3D acceleration, which also needs Display spice with OpenGL on.

A red herring worth recording. /dev/dri/renderD128 exists, and a render node normally implies rendering is possible, so it reads as evidence of acceleration. It is not - "number of cap sets: 0" says there is nothing behind it. Checking the render node alone would have given the wrong answer.

AC #2 is left unchecked deliberately. Whether the same warning appears on real hardware cannot be established from a VM, and guessing would defeat the point of the criterion. What has been done instead is to make the distinction automatic: checks/session.sh now separates software rendering on a virtio GPU reporting -virgl, which it reports as expected, from software rendering on anything else, which it fails. So real hardware will answer the question the first time it runs rather than needing this reopened.

AC #4: mesa is now declared in packages/desktop.txt. Not because declaring it changes rendering - it arrives as a dependency of sway either way - but for the reason polkit is declared: the desktop relies on the capability directly and a dependency-graph change should not be able to remove it quietly. No Vulkan or driver packages were added: there is no hardware path for them to select.

Consequence worth carrying forward: this VM is a poor place to judge anything about smoothness or compositor performance, because it is all CPU-rendered. That matters for TASK-31, which will want a judgement about how a compositor feels.

Resolved on 2026-08-21 by enabling 3D acceleration on the hypervisor, which was the recommendation this task ended with.

Before: "[drm] features: -virgl", "number of cap sets: 0", and the session full of "failed to create dri2 screen" and "Refusing to try glamor on llvmpipe".

After: "[drm] features: +virgl +edid", "+context_init", "number of cap sets: 2", and zero software-rendering messages for the whole boot.

The check added by this task went from SKIP to PASS on its own, which is the point of having written it as a check rather than a note - nobody had to remember to re-verify.

One consequence arrived with it. Enabling acceleration makes wlroots use the virtio GPU cursor plane, whose implementation renders the cursor upside down; the pointer inverted the moment 3D was turned on. Fixed by setting WLR_NO_HARDWARE_CURSORS=1 in environment.d, which makes wlroots composite the cursor itself - the same thing that was happening while everything was software rendered. Worth recording because it looks like an unrelated fault and is a direct consequence of the fix.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The DRI2 warnings are the virtio GPU being presented without 3D acceleration: the kernel reports -virgl with zero capability sets, so Mesa has no hardware path and falls back to llvmpipe. Confirmed from three independent signals - the kernel at boot, Xwayland refusing glamor on llvmpipe, and libEGL itself - rather than assumed from the warning alone. It cannot be fixed from inside the guest; 3D is enabled on the hypervisor. /dev/dri/renderD128 exists and is misleading, since nothing sits behind it. checks/session.sh now reports software rendering on a -virgl virtio GPU as expected while failing it anywhere else, so real hardware answers the remaining question automatically. mesa is declared explicitly, for the same reason polkit is. AC #2 is left unchecked rather than guessed, since it cannot be established from a VM.
<!-- SECTION:FINAL_SUMMARY:END -->
