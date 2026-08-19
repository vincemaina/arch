---
id: TASK-17
title: Restructure the sway config into config.d modules
status: Done
assignee:
  - '@claude'
created_date: '2026-08-19 18:16'
updated_date: '2026-08-19 19:08'
labels:
  - desktop
  - maintainability
dependencies: []
priority: high
type: chore
ordinal: 16000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
setup/dotfiles/dot_config/sway/config is a 256-line copy of the upstream default with edits scattered through it and appended at the bottom, still carrying stock commentary telling you to copy the file into place. This works against the repository philosophy of small, separately reviewable pieces, makes every future change a noisy diff, and makes it hard to tell our decisions apart from upstream defaults. Splitting it into focused includes is the enabler for the input, keybinding, startup and theming work that follows.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The main config only sets variables and includes config.d fragments
- [x] #2 Fragments are split by concern - at least input, output, keybindings, window rules, startup and appearance
- [x] #3 Upstream boilerplate comments that do not describe our own choices are removed
- [x] #4 The restructure is behaviour-preserving and verified against a running session
- [x] #5 Adding a new binding or window rule touches exactly one fragment
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Capture the current config from git as the reference for behaviour comparison.
2. Reduce the main config to variables plus two includes: the system fragments shipped in /etc/sway/config.d, then this repository fragments under config.d/. Ours load last so a local choice always wins.
3. Split into numbered fragments by concern: input, output, appearance, window rules, keybindings, modes, media keys, startup. Numbering makes load order explicit and leaves room to insert.
4. Create the window rules fragment even though there are no for_window rules yet, so the next rule has an obvious single home.
5. Keep mode entry bindings next to their mode definition rather than in the general keybindings fragment.
6. Strip upstream boilerplate - the copy-this-file header, the example output/idle/input blocks, the commented bar block - while keeping any comment that explains one of our own choices. Note in the keybindings fragment that mod+b and mod+e currently shadow the split verbs, since TASK-2 owns fixing that.
7. Verify behaviour preservation mechanically: normalise the old single file and the new fragment set into sorted directive lists and diff them. Anything that differs must be an intended structural change and nothing else.
8. Note that a live-session check cannot run in this container and must be done on the VM.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Split into setup/dotfiles/dot_config/sway/config plus config.d/{10-input,20-output,30-appearance,40-window-rules,50-keybindings,51-modes,52-media-keys,60-startup}.conf. The main config is now 26 lines of variables and two includes.

Two structural changes beyond the move. The system fragments in /etc/sway/config.d are now included before this repository config.d rather than partway through, so a local setting always wins over a distribution default; nothing currently conflicts, so this has no effect today. And 40-window-rules.conf is created empty, purely so the first for_window rule has an obvious home.

Verified behaviour preservation mechanically: both the old single file and the concatenated new fragment set were normalised to sorted directive lists with comments, blank lines and whitespace stripped. Before: 100 directives. After: 101. The diff is exactly one line, the new "include config.d/*.conf". Every original directive survives byte-identically after whitespace normalisation.

AC #4 is only partly satisfied. The mechanical check above is done, but the live-session half cannot run here: sway is not installed in the development container and there is no root or package manager to add it. Outstanding check to run on the VM:
  sway --validate            # config parses with no errors
  swaymsg reload             # apply without restarting the session
then confirm a binding from each fragment still works - a workspace switch, the resize mode, a media key, and that the wallpaper and border width are unchanged.

Live-session verification completed by the user on the VM: sway --validate parses the split config and the session behaves as before. Unrelated libEGL "failed to create dri2 screen" warnings were observed during validation; tracked separately as TASK-26, since nothing in this change touches outputs, renderers or EGL.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Replaced the 256-line copy of the upstream default with a 26-line main config of variables and two includes, plus eight numbered config.d fragments: input, output, appearance, window rules, keybindings, modes, media keys and startup. Adding a binding, window rule or startup process now touches exactly one file. Upstream boilerplate removed; comments explaining our own choices kept, including a note that mod+b and mod+e shadow the split verbs for TASK-2. System fragments in /etc/sway/config.d now load before ours so a local setting always wins, which changes no behaviour today as nothing conflicts. Verified mechanically by normalising old and new to sorted directive lists - 100 directives before, 101 after, the only difference the new include - and confirmed on the VM by the user with sway --validate and a working session.
<!-- SECTION:FINAL_SUMMARY:END -->
