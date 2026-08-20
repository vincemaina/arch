---
id: TASK-50
title: Explore recovering the session after a restart or a crash
status: To Do
assignee: []
created_date: '2026-08-20 23:42'
updated_date: '2026-08-20 23:42'
labels:
  - desktop
  - foundation
dependencies:
  - TASK-48
priority: low
type: spike
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Tonight sway segfaulted and took every window with it - workspaces, terminals, whatever was half-typed. Logging back in gave a clean desktop and no way back to what had been there. A deliberate reboot does the same thing, just with more warning.

The want is to come back to the same windows on the same workspaces. That is worth separating into three problems, because they have very different answers and only one of them is easy.

WHERE THE WINDOWS WERE. sway has no save or restore of its own - the words appear zero times in sway(5) - so this is scriptable at best: dump swaymsg -t get_tree, and on the way back relaunch each application and place it. Positions and workspaces survive. Nothing inside a window does. The community tools for this are AUR-only (swayr, sway-session), which lands on TASK-43.

WHAT WAS INSIDE THEM. Mostly per-application and mostly not scriptable from outside. qutebrowser and neovim both keep their own session state and could be asked to restore it; a terminal cannot be asked what was half-typed in it.

Shells are the exception, and the reason this is worth doing at all: a multiplexer keeps them in a server process that outlives the compositor, so a crash costs nothing and reattaching puts every shell back mid-command. Options, priced: abduco at 37 KiB does only detach and reattach and nothing else, which is a remarkably close fit for the actual want; tmux at 1.2 MiB adds panes and tabs that sway already provides; zellij at 49 MiB adds those plus layouts and plugins, and its default bindings lean on Ctrl, which after TASK-40 is the most reachable key and already spoken for by readline and fzf.

CRASH VERSUS SHUTDOWN, which is the distinction that decides the design. A deliberate logout can save state on the way out. A crash cannot, so anything that must survive one has to be written continuously as it changes - which is exactly what a multiplexer does for shells and what a save-on-exit script cannot do for window layout.

Worth being honest about the ceiling. Configuration is reproducible here because it is declared; session state is not the same kind of thing, and chasing a perfect restore tends to produce a fragile pile of scripts that half-work. It may be that the proportionate answer is small: keep shells alive, let windows be relaunched by hand, and accept that a compositor crash costs the layout.

And the first move is not in this ticket at all. TASK-48 found the crash is llvmpipe, because the VM has no GPU acceleration. Enabling it on the host removes the fault rather than insuring against it, and should be tried before any of this is built.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The three problems are answered separately - where windows were, what was inside them, and shells - rather than treated as one feature
- [ ] #2 Whether shells should survive a compositor crash is decided, and if so the cheapest tool that does it is chosen rather than the most featureful
- [ ] #3 Any multiplexer adopted has its keybindings reconciled against the existing scheme, since it adds a second layer inside every terminal and tools/shortcuts.sh exists because that collision is hard to see
- [ ] #4 The crash-versus-shutdown distinction is reflected in whatever is built: anything expected to survive a crash is written continuously, not saved on exit
- [ ] #5 Enabling GPU acceleration on the host is tried first, since TASK-48 identifies it as the cause rather than something to insure against
- [ ] #6 The decision is recorded in DECISIONS.md, and concluding that only shells are worth persisting counts as completing this
<!-- AC:END -->
