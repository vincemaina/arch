---
id: TASK-196
title: 'Choose the file explorer with explorer --use, and keep both'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-29 14:30'
updated_date: '2026-08-29 14:39'
labels: []
dependencies:
  - TASK-190
type: feature
ordinal: 201000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-190 asked which of Thunar and yazi goes. This answers it differently: NEITHER goes, and the choice moves behind a switch, exactly as TASK-178 did for the browsers.

WHY THIS IS NOT SIMPLY IGNORING TASK-190

TASK-190's premise is this repository's own argument that two things doing one job is a smell, and that premise is sound where the two things are interchangeable - two browsers, two Escape keys. It is wrong here, and the owner's own account of use is the evidence: yazi for everything, because it is quicker and reads like the rest of a keyboard-driven system; Thunar for the involved jobs it is genuinely better at - a directory of thumbnails, bulk rename, dragging a file into another window, a sidebar of drives. Those are not two implementations of one job. They are two jobs.

So the cost TASK-190 wanted to reclaim - 20.5 MiB and 7 packages - is knowingly not reclaimed, and the ticket is answered rather than left open contradicting the code.

WHAT CHANGES

A ~/.local/bin/explorer helper on the browser's exact model: --list, --current, --use <name>, arguments passed through, a one-line state file in ~/.local/state read with cat because it sits on the keypress path between $mod+e and a window. Default yazi.

$mod+e opens the selected one. $mod+Ctrl+e opens the one that is NOT selected, so Thunar stays a keypress away without switching the default and switching back. That is the difference from the browser, where one key was enough, and it exists because the two are reached for differently rather than interchangeably.

The sway variables $explorer and $explorer_tui both collapse into the helper. Both window rules stay - the app_ids are unchanged - and so does the shared 1100x700 geometry.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A ~/.local/bin/explorer helper exists with --list, --current, --use <name> and --help, passes arguments through, carries a '# requires:' header, and falls back to the default on a missing, empty or unrecognised state file rather than failing
- [x] #2 The default is yazi on a machine that has never run 'explorer --use', and the state file is a plain one-line file in ~/.local/state, not chezmoi.toml, for the reason DECISIONS.md records for the browser and the sound pack
- [x] #3 $mod+e opens the selected explorer and $mod+Ctrl+e opens the one that is not selected, verified at runtime for both settings of the switch
- [x] #4 Both explorers still open floating at 1100x700, and 'shortcuts' still shows the right key table for whichever window is focused
- [x] #5 The manual's 'The file managers' section describes the switch instead of a decision that is about to be made, and no surface still claims one of them is going
- [x] #6 DECISIONS.md records that TASK-190 was answered by keeping both, and why the 20.5 MiB is knowingly not reclaimed
- [ ] #7 checks/session.sh, checks/packages.sh, checks/sway-commands.sh, checks/sway-bindings.sh and checks/manual.sh all pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Write setup/dotfiles/dot_local/bin/executable_explorer on the browser's model: SUPPORTED=(yazi thunar), DEFAULT=yazi, STATE=~/.local/state/explorer, '# requires: yazi foot thunar'. --list/--current/--use/--help, plus --other for the second binding (next entry after the selected one, wrapping, so it generalises past two). yazi launches as 'foot --app-id=explorer -e yazi'; thunar launches bare. Arguments pass through both.
2. sway/config: replace 'set $explorer thunar' and 'set $explorer_tui foot --app-id=explorer -e yazi' with a single 'set $explorer ~/.local/bin/explorer'. Rewrite the comment block - it currently says two file managers are on a clock and TASK-190 ends it, which is no longer true.
3. 50-keybindings.conf: $mod+e exec $explorer, $mod+Ctrl+e exec $explorer --other. Rewrite the TASK-190 comment.
4. 40-window-rules.conf: keep both app_id rules and the shared geometry; rewrite the 'while TASK-190 decides' comment to say why the geometry stays matched.
5. checks/sway-commands.sh and checks/sway-bindings.sh: the $explorer_tui prefix-collision comments now describe a variable that no longer exists. Keep the longest-name-first sort and its lesson, reword to past tense.
6. dot_local/bin/executable_shortcuts: add a description for the explorer helper alongside the browser one at line ~175, so $mod+e is described as the helper rather than as one file manager.
7. docs/manual/04-applications.md: rewrite 'The file managers: Thunar and yazi' - the switch, the two keys, and the division of labour, mirroring the browser --use block at line 274. Update the $mod+Ctrl+e references in the yazi and Thunar subsections.
8. DECISIONS.md: a section recording that TASK-190 was answered by keeping both, the reasoning, and the cost knowingly not reclaimed.
9. Close TASK-190 as answered by this task rather than leaving it open contradicting the code.
10. Verify on the running machine: sync.sh, then explorer --list/--current/--use both ways, both bindings at runtime via swaymsg, and all five checks.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
VERIFIED ON THE RUNNING MACHINE, not read back from the config.

Applied with 'chezmoi --source <worktree>/setup apply' rather than sync.sh: sync.sh needs sudo for the machine-wide step and no setup/system/ file changed, so that step had nothing to do. The manual was built and installed by hand for the same reason.

Both keys were exercised on a THROWAWAY headless output (desktop-verification skill), so the two real screens were never touched, and the evidence is 'swaymsg -t get_tree' rather than a screenshot - the skill warns a headless capture can be inconclusive, and app_id/floating/geometry is what actually needed proving. Focus and workspaces were restored and the output unplugged; confirmed afterwards that workspaces 1/4 are back on HDMI-A-1, 2 on DP-1, focus on 4.

    no state file, explorer --current = yazi
      $mod+e        -> app_id=explorer  floating=True  1094x686
      $mod+Ctrl+e   -> app_id=thunar    floating=True  1100x700
    after 'explorer --use thunar', --current = thunar
      $mod+e        -> app_id=thunar    floating=True  1100x700
      $mod+Ctrl+e   -> app_id=explorer  floating=True  1094x686
    'explorer /etc' -> app_id=thunar, so arguments pass through

Both keys swap with the setting and neither needs a sway reload, which was the point of putting the resolution in the helper rather than in a sway variable.

The 1094x686 is foot rounding 1100x700 down to whole character cells, not the window rule failing - it is what $explorer_tui already did before this change, and thunar lands on 1100x700 exactly.

Every query path of the helper was exercised against a scratch XDG_STATE_HOME: missing, empty, unrecognised and whitespace-padded state files all fall back to yazi; --use rejects an unsupported name and a missing argument; --list marks the selection; --help prints the usage block.

Machine left on the compiled-in default with NO state file, which is the freshly-installed state and selects yazi.

CHECKS. session.sh 140 passed / 0 failed / 2 skipped. manual.sh 8 passed / 0 failed - it needed ~/.local/state/explorer added to its created_on_demand set, exactly as ~/.local/state/browser already was, because the file's absence IS the default. sway-bindings.sh reports 77 bindings, none twice, and resolves Mod4+e and Mod4+Ctrl+e to the helper. sway-commands.sh accounts for every command. 'shortcuts --mode sway' describes the two keys distinctly: 'Open the file explorer' and 'Open the other file explorer'.

AC #7 IS LEFT UNCHECKED AND THAT IS DELIBERATE. checks/packages.sh fails on 5 packages installed by hand on this machine and declared nowhere - gimp, linux-headers, openrgb, steam, vulkan-tools. Pre-existing and untouched by this task, which changed no manifest, so the check's inputs are identical to main. The criterion as written says all five checks pass, and it is not true, so it is not ticked.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Both file managers stay, and the choice moved behind ~/.local/bin/explorer - --list, --current, --use <name>, arguments passed through, a one-line state file in ~/.local/state read with cat because it sits between a keypress and a window. Default yazi.

$mod+e opens the selected one, $mod+Ctrl+e opens the other, both resolved by the helper at launch so a switch needs no sway reload. That is the one deliberate difference from 'browser --use', which puts one choice on one key: three browsers are interchangeable, these two are not, and making Thunar cost a --use and a --use back would price it out of the jobs it is kept for.

This ANSWERS TASK-190 rather than ignoring it. TASK-190 was written to delete one of them, on the standing argument that two things doing one job is a smell. The fortnight showed that premise does not hold here: yazi is what the hand reaches for, and Thunar is reached for rarely and specifically, for four things yazi cannot do at all - thumbnails, bulk rename with a preview column, dragging a file into another window, a sidebar of drives. Deleting it would remove capabilities, not a duplicate. So TASK-190 asked the wrong question, and the 20.5 MiB it was written to reclaim is knowingly not reclaimed. Demoting Thunar to $mod+Ctrl+e does mean most sessions no longer pay its 28.7 MiB of tumblerd/xfconfd, which is the part that improved.

$explorer_tui is gone, collapsed into the helper. The three places carrying comments about it - checks/sway-commands.sh, checks/sway-bindings.sh, executable_shortcuts - keep the longest-name-first sort and its lesson, reworded to past tense, because the next prefix pair will be added by someone who has not read them.

Recorded in DECISIONS.md as 'Both file managers stay, behind explorer --use', with the alternative it took marked as the winner inside the TASK-189 entry it reverses. The manual's file-manager section, docs/software/README.md and both window-rule comments now describe a switch rather than a decision about to be made.

Verified on the running machine: both keys exercised on a throwaway headless output with both settings of the switch, evidence from swaymsg -t get_tree, screens restored. session.sh 140/0, manual.sh 8/0, sway-bindings.sh and sway-commands.sh clean. packages.sh still fails on 5 hand-installed packages that predate this task and no manifest changed.
<!-- SECTION:FINAL_SUMMARY:END -->
