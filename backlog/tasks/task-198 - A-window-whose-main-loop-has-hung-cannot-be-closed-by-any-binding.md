---
id: TASK-198
title: A window whose main loop has hung cannot be closed by any binding
status: Done
assignee:
  - '@claude'
created_date: '2026-08-31 09:40'
updated_date: '2026-08-31 09:54'
labels: []
dependencies: []
ordinal: 203000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
$mod+q is sway's `kill`, which sends xdg_toplevel.close - a request the client must act on. When a client's main loop is wedged, that request is never processed, and there is no other binding that ends the window. On 2026-08-31 deluge-gtk's 'Move Download Folder' file chooser hit a GTK3 grab bug ("Window ... is already mapped at the time of grabbing") and spun its main thread at 95% CPU, emitting the same warning ~35,000 times a second - journald suppressed just over a million messages per 30-second window. The dialog's own buttons did nothing, $mod+q did nothing, and SIGTERM did nothing either, because Python only runs signal handlers between bytecodes in the main thread and that thread was inside C. Only SIGKILL ended it, and only from a terminal that happened to be open.

sway was not at fault and every other window kept working; the gap is that the desktop offers no escalation past the polite close. This is about the missing escape hatch, not about deluge - the same wedge in any GTK client would be equally unkillable.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A binding exists that ends the focused window's process outright, independent of whether that process is servicing its event loop
- [x] #2 The binding is deliberately harder to hit than $mod+q, so an unsaved editor is not lost to a slip
- [x] #3 It resolves the process from the focused window rather than by name, so it works on any client
- [x] #4 It reports what it killed, rather than failing silently when there is no focused window or no pid
- [x] #5 checks/sway-bindings.sh still passes, and any new helper carries a '# requires:' header so checks/sway-commands.sh passes
- [x] #6 docs/manual/ chapter 3 covers the binding and says plainly when to reach for it
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. New helper setup/dotfiles/dot_local/bin/executable_sway-force-kill, '# requires: swaymsg python3 rofi notify-send kill'. Reads swaymsg -t get_tree, walks to the focused node, takes its pid, app_id/class and name.
2. Refuse rather than guess in three cases: no focused window; a focused node with no pid; and a pid belonging to Xwayland, where sway reports the X server rather than the client and SIGKILL would take every X application at once. Each says why, via notify-send, because nothing launched from a keybinding has a stderr anyone reads.
3. Confirm through rofi in the power-menu idiom - 'Cancel' first so the rofi cursor starts on the safe answer, -no-custom, -replace - with the window named in the prompt. This is what makes $mod+Shift+q survivable next to $mod+q, which is the only thing separating them.
4. SIGKILL, not SIGTERM. $mod+q is already the polite request; a second polite request is not an escalation, and SIGTERM was measured doing nothing to the wedged deluge on 2026-08-31. Report the kill with notify-send.
5. Bind $mod+Shift+q in 50-keybindings.conf with --no-repeat, next to $mod+q, with a trailing comment so tools/shortcuts.sh gives it a description.
6. Prose in docs/manual/03-the-keyboard.md: what separates the two bindings and when to reach for the second.
7. Verify: checks/sway-bindings.sh, checks/sway-commands.sh, checks/manual.sh, checks/session.sh; then chezmoi apply and prove the binding on a real wedged process rather than reading the config back.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented as ~/.local/bin/sway-force-kill on $mod+Shift+q, chosen by the user.

WHAT IT DOES. Reads the focused node from `swaymsg -t get_tree` before rofi opens (rofi takes focus, and would otherwise be the window it reported on), takes its pid, and SIGKILLs it after one rofi confirmation in the power-menu idiom - Cancel on the first row, -no-custom, -replace. SIGKILL rather than SIGTERM because $mod+q is already the polite request; a second polite request is not an escalation. Reports through notify-send, since nothing launched from a keybinding has a stderr anyone reads; refusals are critical urgency so they persist rather than timing out unseen.

A BUG THE TESTING FOUND, worth recording because it is this repository's usual shape. The three fields came back tab-separated into `IFS=$'\t' read -r pid app_id title`. bash strips LEADING fields when IFS is a whitespace character, so an empty pid shifted the window NAME into $pid - and the focused node on an empty workspace is the workspace, whose name is its number. It really did reach `kill -KILL on pid 90` for workspace 90, one EPERM away from killing an unrelated process. Fixed by delimiting with \x1f, which is not whitespace, plus an explicit `^[1-9][0-9]*$` guard on the pid. Nothing about the script looked wrong; only running it on an empty workspace showed it.

XWAYLAND GUARD. wlroots takes an X client's pid from _NET_WM_PID, and a client that never sets it leaves sway reporting the X server. SIGKILL there would take every X11 application at once, so the script refuses when /proc/PID/comm is Xwayland. Confirmed against a real X client: `GDK_BACKEND=x11 thunar` appears as shell=xwayland, app_id=None, class=Thunar, pid=26381, comm=thunar - so the guard correctly does NOT fire on a well-behaved X app, and `window_properties.class` is the right fallback for the label. Xwayland's own pid read comm=Xwayland, so the comparison is against a real value.

VERIFICATION. The one that matters was a deliberately wedged window - foot on a headless output, SIGSTOPped, so it services no event loop and cannot act on SIGTERM (state TNsl):
  1. swaymsg '[con_id=30] kill'  (what $mod+q sends)  -> still alive after 2s
  2. kill -TERM                                        -> still alive after 2s
  3. sway-force-kill                                   -> killed
That reproduces the deluge failure shape and shows the new binding is the escalation that works. Also killed a live foot and a live thunar end to end; refused an empty workspace before prompting; notifications confirmed present in makoctl history with app-name sway-force-kill.

The confirmation was driven by a stub `rofi` on PATH returning the last row, because nothing here can inject keystrokes (no wtype or ydotool) - the stub also captured the exact rows and argv, which is how the row order and prompt text were checked. rofi's real rendering was observed separately; note it places itself on the pointer's output, not the focused one, so it does not appear on a headless capture.

Testing was done on a headless output, focus handed straight back after each run and both outputs unplugged. Focus was parked there too long once early on and some of the user's keystrokes landed in the invisible test window - the hazard desktop-verification warns about, met in practice.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
$mod+Shift+q now force quits the focused window: ~/.local/bin/sway-force-kill resolves the pid from sway's focused node and SIGKILLs it after one rofi confirmation (Cancel first, in the power-menu idiom), reporting through notify-send. It refuses, and says why, when the focused thing is not a window and when sway reports Xwayland's own pid rather than the client's - killing that would take every X11 application at once.

Proven on a deliberately wedged window (foot, SIGSTOPped so it services no event loop): sway's own `kill` - what $mod+q sends - was ignored, SIGTERM was ignored, sway-force-kill ended it. Also exercised end to end against a live Wayland client and a live XWayland client, and against an empty workspace, where it refuses before prompting.

Testing found and fixed a real bug in the process: tab-separated fields plus bash's leading-whitespace stripping in `read` shifted the window name into $pid when the pid was empty, which on an empty workspace meant attempting to kill the process whose pid matched the workspace NUMBER. Now delimited with \x1f and guarded with a numeric check.

checks/sway-bindings.sh (78 bindings, none duplicated), checks/sway-commands.sh, checks/manual.sh (8 passed) and checks/session.sh (140 passed, 0 failed) all pass. checks/packages.sh fails on 15 pre-existing hand-installed packages on this machine and touches nothing in this change.
<!-- SECTION:FINAL_SUMMARY:END -->
