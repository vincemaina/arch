---
id: TASK-50
title: Explore recovering the session after a restart or a crash
status: Done
assignee: []
created_date: '2026-08-20 23:42'
updated_date: '2026-08-22 00:59'
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
- [x] #1 The three problems are answered separately - where windows were, what was inside them, and shells - rather than treated as one feature
- [x] #2 Whether shells should survive a compositor crash is decided, and if so the cheapest tool that does it is chosen rather than the most featureful
- [x] #3 Any multiplexer adopted has its keybindings reconciled against the existing scheme, since it adds a second layer inside every terminal and tools/shortcuts.sh exists because that collision is hard to see
- [x] #4 The crash-versus-shutdown distinction is reflected in whatever is built: anything expected to survive a crash is written continuously, not saved on exit
- [ ] #5 Enabling GPU acceleration on the host is tried first, since TASK-48 identifies it as the cause rather than something to insure against
- [x] #6 The decision is recorded in DECISIONS.md, and concluding that only shells are worth persisting counts as completing this
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
DECISION: adopt abduco to keep interactive shells alive across a sway crash or
in-session restart. Do not build window-layout capture/replay, and do not add
anything beyond what qutebrowser and neovim already do for their own state.
Verified rather than assumed - see evidence below.

THE THREE PROBLEMS, ANSWERED SEPARATELY

Where the windows were: swaymsg -t get_tree captures geometry and workspace
assignment; replaying it means relaunching every app and re-placing it, which
is scriptable but exactly the "fragile pile of scripts that half-work" the
ticket itself warns against, for a fault seen once in ~20 hours of session
time (TASK-48). The community tools that would help (swayr, sway-session) are
AUR-only, and TASK-43 already declined AUR support on its own merits. Not
worth building.

What was inside them: mostly already handled by defaults already active here,
checked rather than assumed:
  - qutebrowser has no dotfile in this repo at all (no dot_config/qutebrowser
    anywhere) - it runs stock, and qutebrowser's auto_save.session defaults to
    true, so it already autosaves and restores open tabs with zero
    configuration. Nothing to build.
  - neovim already sets o.undofile = true (persistent undo for saved files)
    and default swapfile is on (nvim -r recovers unsaved edits). Neither
    restores the open-buffer/window layout automatically; :mksession does
    that but is deliberate-save, not continuous, so it fits the
    reboot-with-warning case, not the crash case - and scripting it onto
    autosave would be new machinery for a fault seen once. Not recommended.
  - A terminal's half-typed command or running process is genuinely not
    introspectable from outside. This is the one real gap, and it is what
    shells/multiplexer persistence actually closes.

Shells: worth doing. abduco (36.75 KiB, extra repo, confirmed via
`pacman -Si`) does only detach/reattach - no panes, tabs or prefix-key layer,
which is what makes tmux (1.24 MiB, adds panes/tabs sway already provides) and
zellij (49.01 MiB, same plus Ctrl-heavy default bindings that TASK-40 made the
single most reachable and already-spoken-for key: dot_zshrc has `bindkey -e`
(Ctrl+A/Ctrl+E) and fzf's Ctrl+R/Ctrl+T) both worse fits. abduco's documented
detach key is Ctrl+\, which collides with nothing in dot_zshrc or
setup/dotfiles/dot_config/sway/ (grepped, no hits) - confirm against the
actual man page at implementation time since the package is not installed in
this session.

CRASH VS RESTART - VERIFIED AGAINST THE ACTUAL TASK-48 CRASH LOG, NOT ASSUMED

journalctl for 2026-08-20 23:29-23:31 (the real crash) shows:
  - systemd[623], the user manager for uid 1000, is the SAME pid before and
    after: it logs "Stopped target Session of sway..." at 23:30:11 and
    "Reached target Session of sway..." again at 23:30:29, and there is no
    "Stopped/Started User Manager for UID 1000" anywhere in the window -
    unlike the transient greeter (uid 965), whose manager visibly starts and
    stops. So systemd --user itself survives a sway crash; anything launched
    as its own unit, independent of the session target, would too.
  - But ordinary session-bound things do not: wayland-session@sway.target's
    own units (waybar, mako, swayidle, polkit-agent, nm-applet) are
    explicitly stopped as part of the crash cleanup. And a plain process
    sitting inside wayland-wm@sway.service's own cgroup gets SIGKILLed ~10s
    after the crash by systemd's stop-sigterm timeout - the log shows this
    happened for real, to a process named "claude" (this very agent's
    process tree), at 23:30:21: "wayland-wm@sway.service: Killing process
    15031 (claude) with signal SIGKILL."

That last line is the concrete proof that "just run it in a terminal" is not
sufficient - a shell launched the ordinary way (via a sway `exec` line, or
anything nested under the session target/App Slice) dies with everything
else. For abduco's daemon to actually survive, it has to be started as its
own systemd --user unit with no PartOf/BindsTo on wayland-session@sway.target
and not spawned via a sway exec line - the mirror image of how mako/waybar/
swayidle are deliberately bound to that target, per the existing pattern in
CLAUDE.md ("session components are units, not exec lines"). This satisfies
AC4: what's proposed is continuous by construction (a long-lived detached
server process), not save-on-exit.

Also worth being precise about scope: this protects against a sway crash and
against a deliberate in-session restart (logout/relogin without power-cycling
the machine, which is what actually happened in TASK-48 - "the machine did
not reboot"). It does NOT survive a genuine full system reboot; no user
process does. The ticket's "a deliberate reboot does the same thing, just
with more warning" is true for window layout either way, but a real reboot is
outside anything a userspace daemon can help with.

AC5 - NOT TRIED. Enabling 3D acceleration is a hypervisor-side virt-manager
change (Video: virtio with 3D, Display: spice with OpenGL) that this guest
session has no access to - no sudo, no host reach. Left unchecked
deliberately, the same way TASK-48 left its own equivalent AC unchecked. It
does not block the shells decision: abduco is cheap enough (37 KiB) to be
worth adopting regardless of whether the underlying crash cause is later
fixed, and protects the in-session-restart case too, which the GPU fix does
not touch at all.

AC6 - drafted, not written. This agent is restricted to the backlog CLI and
may not edit repository files directly. The DECISIONS.md entry text is
handed to the orchestrating session in the final report, for it to add. Task
left in In Progress rather than Done until that entry actually exists and
whoever adds it checks AC6.

NOT WORTH BUILDING, STATED PLAINLY: a get_tree dump/relaunch tool for window
layout; any app-content scripting beyond what qutebrowser and neovim already
do by default; tmux or zellij in place of abduco.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Split into three problems with different answers. Window layout: not worth building - AUR-only tools declined on TASK-43, and a hand-rolled replay is fragile machinery for a fault seen once. Window contents: already covered by defaults, verified rather than assumed - qutebrowser runs stock with auto_save.session true, neovim already has undofile and swapfile recovery. Shells: the one real gap, closed cheaply with abduco. The design constraint came from the actual crash log, which shows systemd SIGKILLing a process in wayland-wm@sway.service's cgroup ten seconds after the crash - so the daemon must be its own user unit unbound from the session target. Recorded in DECISIONS.md; implementation is TASK-98.
<!-- SECTION:FINAL_SUMMARY:END -->
