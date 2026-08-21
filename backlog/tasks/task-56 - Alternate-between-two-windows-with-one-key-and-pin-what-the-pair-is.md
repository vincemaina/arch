---
id: TASK-56
title: 'Alternate between two windows with one key, and pin what the pair is'
status: To Do
assignee: []
created_date: '2026-08-21 10:20'
labels:
  - desktop
  - feel
dependencies:
  - TASK-19
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Moving between two windows you are actively working across - an editor and a terminal, a browser and the thing it is documenting - currently means directional focus, and the direction depends on where the windows happen to be. Across workspaces it means remembering which workspace the other one is on. Neither is the gesture wanted, which is "the other one", on one key.

Two related things are asked for:

1. Ctrl+Tab alternates with the last focused window, the way it works in most tabbed interfaces and the way $mod+Ctrl+j already works for workspaces. Pressing it repeatedly should flip between two windows rather than walking backwards through a stack - the second press must return where it came from, or it is a most-recently-used list rather than an alternation.

2. A window can be pinned as one half of that pair, from anywhere. With something pinned, Ctrl+Tab always flips between the pinned window and wherever you were, across workspaces, rather than following focus history at all. That makes the pair deliberate rather than accidental - the thing you are referring to stays reachable however much you move around.

WHAT SWAY GIVES AND WHAT IT DOES NOT

There is no built-in "focus last window". Sway has `focus prev`/`focus next`, which walk the tree in order, and workspace `back_and_forth`, which is the workspace-level version of exactly this feature but has no window equivalent. So the history has to be kept outside sway, by a small daemon subscribing to the window::focus IPC event - the same shape as sway-workspace-greeter, which already subscribes to workspace events and can be read as a worked example.

Two details that will decide whether this feels right or not:

  * The daemon must ignore focus changes it causes itself, or alternating updates the history and the next press goes nowhere.
  * Windows close. A history holding a dead con_id must fall through to the next live entry rather than doing nothing, and a pinned window that is closed has to unpin itself or the binding becomes permanently dead.

Ctrl+Tab specifically is worth checking before committing to it: Control is now the key beside the space bar after TASK-40, so it is comfortable, but Ctrl+Tab is also a binding applications use themselves - a browser with tabs will want it. A sway binding takes it globally and the application never sees it. Whether that is acceptable, or whether this belongs on $mod+Tab (currently free, since $mod+Tab was given up when workspace switching moved to $mod+Ctrl+j), is the first thing to settle.

How pinning is invoked and how you can tell something is pinned both need answering. A pin nobody can see is a mode with no indicator, which is the sort of thing that gets forgotten and then confuses. The bar is the obvious place to show it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One key alternates between the current window and the previously focused one, and pressing it twice returns to where you started
- [ ] #2 It works across workspaces, following the window rather than the workspace
- [ ] #3 Any window can be pinned as the fixed half of the pair, and unpinned again
- [ ] #4 While something is pinned, the alternation is always between it and the current window
- [ ] #5 Closing a window - pinned or merely in the history - leaves the binding working rather than dead
- [ ] #6 Whether taking Ctrl+Tab globally is acceptable is decided, given applications bind it themselves
- [ ] #7 Whether something is pinned is visible without pressing anything
<!-- AC:END -->
