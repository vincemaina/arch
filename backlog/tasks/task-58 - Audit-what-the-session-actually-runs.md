---
id: TASK-58
title: Audit what the session actually runs
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-21 10:20'
updated_date: '2026-08-21 21:18'
labels:
  - desktop
  - repo
dependencies:
  - TASK-14
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Nothing has ever checked the list of processes a logged-in session leaves running. It has accumulated, and at least one entry is now provably doing nothing.

WHAT A LOOK ALREADY FOUND

nm-applet, 41M resident, started by app-nm\x2dapplet@autostart.service from an XDG autostart file shipped with networkmanager. It is a system tray applet, and this bar has no tray - the systray module was removed when waybar's native network module replaced it, because a GTK tray icon cannot be themed to match the rest of the bar. So it is drawing into nothing. Nothing in setup/ starts it; it arrives with the package and autostarts itself, which is why it survived a change that removed its only reason to exist.

Others worth a look, none yet established as waste:

  * at-spi-dbus-bus and its atspi Registry - the accessibility bus, started by GTK.
  * gvfs-daemon and gvfs-metadata - from Thunar, whose future is TASK-44.
  * Two xdg-desktop-portal processes.
  * Xwayland, which is only needed while an X11 client is running.

spice-vdagent is the one the complaint named, and it is the one that turns out to be justified. It exists so the SPICE client can coordinate the pointer with the guest - without it the client draws its own cursor, which is a second cursor on screen, and that is a bug this repository has already fixed once. The package comment says it is harmless on real hardware because the daemon finds no channel and exits. That claim should be tested rather than trusted, and if it holds, spice-vdagent is right where it is until TASK-14 brings machine profiles.

WHAT THIS IS NOT

Not an exercise in shaving megabytes. The machine has zram and earlyoom and is not short of memory. It is about the same thing the rest of this repository keeps finding: something configured that does nothing, which looks deliberate and is not. A process nobody can explain is a process nobody will question when it starts misbehaving.

The useful output is a decision per entry - needed, needed only on some machines, or not needed - and a way to notice the next one. An autostart that arrives with a package is invisible in this repository today: setup/ says nothing about it, so nothing reviews it.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Every process a fresh session leaves running is accounted for, with a reason recorded for each
- [ ] #2 Anything established as unnecessary is stopped in a way that survives a rebuild, not just killed on this machine
- [x] #3 The claim that spice-vdagent exits harmlessly on hardware without a SPICE channel is tested rather than taken on trust
- [x] #4 Anything that is needed only on some machines is identified as such, so TASK-14 has a concrete list to work from rather than a hypothesis
- [ ] #5 XDG autostart files shipped by packages are visible to this repository somehow, since that is how the dead one got in and nothing would have caught it
- [ ] #6 checks/session.sh notices if a process that was decided against comes back
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
spice-vdagent investigated ahead of the rest, since it was the one named. Findings, all from the running system rather than from the manifest:

THE PACKAGE COMMENT IS WRONG. desktop.txt says the agent stops the SPICE client drawing its own pointer, "which is a second cursor on screen alongside the one sway draws". The commit that added it (3c365ae, "Add the SPICE guest agent, and rule it out as the cursor fix") says in its own message: "It was worth trying and it did not fix the ghost cursor." The comment states the theory it was tried under as though it were the outcome. The cursor was actually fixed by WLR_NO_HARDWARE_CURSORS, in the user environment and in greetd's config. Anyone reading the manifest today would conclude the agent is load-bearing for the cursor; it is not.

MOST OF WHAT IT DOES FAILS HERE. It is documented as "Spice guest agent X11 session agent" and every feature the man page lists is X11 or GNOME. On this Wayland session the journal is a wall of failures at startup: "xrandr output ID NOT FOUND", "failed to call GetCurrentState from mutter over DBUS", "card0 not found while listing DRM devices", "Unable to open file (null)", each twice. It holds zero X11 socket file descriptors and is not connected to Xwayland at all, so clipboard sharing - the main reason people install it - is not merely unused but impossible as configured.

WHAT IT DOES DO. Audio volume sync with the client, which the journal shows working: vdagent_audio_playback_sync, with per-channel levels. That is the only feature observed functioning. Whether client mouse mode works is not answerable from inside the guest: the second pointer is drawn by the SPICE client on the host, so a screenshot from here contains one cursor either way. That is the test the user has to make, and it is the only thing standing between this and removal.

AC #3 IS ANSWERED: the "harmless on real hardware" claim holds, and is now verified rather than trusted. /usr/lib/udev/rules.d/70-spice-vdagentd.rules starts spice-vdagentd.socket only on ACTION=="add" for a virtio-port whose DEVLINKS is /dev/virtio-ports/com.redhat.spice.0, and the user unit carries ConditionPathExists=/run/spice-vdagentd/spice-vdagent-sock. No virtio port means no socket, which means the condition fails and the agent never starts. So on hardware it costs a package on disk and nothing at runtime.

It is also worth recording that it is 45M resident in this VM, not the 129 KiB the commit message quotes - that figure is the package size on disk.

The user agent was stopped to test. Not yet restarted pending the pointer observation.

Confirmed by the user with the agent stopped: still one cursor, tracking normally. So nothing in this VM depended on it, and spice-vdagent is removed from packages/desktop.txt.

The lesson generalises and is now in CLAUDE.md's failure-mode section as its own named variant: a fix that did not work, kept anyway, with the hypothesis recorded as though it were the outcome. That is worse than no comment, because it reads as justification.

nm-applet remains the open item, and is the same shape - something that survived losing its reason to exist because nothing in setup/ mentions it.

AUDIT OF THE WHOLE SESSION, 2026-08-21. Everything below is from a command run on the reference VM.

NEW TOOL. tools/session-inventory.sh. checks/session.sh answers 'does the machine match what the repo intends'; this answers the question the repo could not previously ask at all, 'what is running that the repo never mentioned'. Sections: XDG autostart entries with their package and whether the generator actually started them; every active user unit grouped by where its unit file came from (this repo / uwsm / a package / generated from autostart / generated by D-Bus); every process with PSS, RSS, CPU, what started it, which package owns the binary and whether setup/packages declares it; Xwayland's on-demand status; system services with how each was activated; and what has been left behind. It is a report, not a check - it never exits non-zero, because whether a process is wanted is a judgement.

Three things it had to learn the hard way, all recorded in comments in the script:

  * 'systemctl show -p A -p B --value' prints properties in systemd's own order, not the order asked for, and omits an empty one entirely. Positional parsing therefore lines values up against the wrong keys, and the first version of this reported every unit as package-shipped, including the five this repository ships. Ask without --value and read the key=value pairs.
  * A process carrying file capabilities is marked non-dumpable by the kernel, and /proc/PID/exe and smaps_rollup then need root even for your own process. sway has cap_sys_nice=ep. So the naive loop skipped the compositor - the largest thing in the session - and nothing said so.
  * comm is truncated to 15 characters by the kernel, so xdg-desktop-portal, -gtk and -wlr all read as 'xdg-desktop-por' and three different programs looked like three copies of one, which the leak detector duly reported.

WHAT IS RUNNING THAT NOTHING IN setup/ ASKED FOR

nm-applet - CONFIRMED WASTE, now TASK-92. Started by /etc/xdg/autostart/nm-applet.desktop, shipped inside network-manager-applet, generated into app-nm\\x2dapplet@autostart.service by systemd-xdg-autostart-generator, which uwsm reaches through wayland-session-xdg-autostart@sway.target. 11.9 MiB PSS / 37.5 MiB RSS, 0.2 CPU-s. 'busctl --user list' shows no StatusNotifierWatcher and no org.kde.* name at all on the session bus, so there is not merely no tray in the bar - there is nowhere on the machine for a tray icon to go. It holds a Wayland connection and has no window in swaymsg -t get_tree. Nothing under setup/dotfiles/, checks/ or tools/ names it. The package ships only nm-applet and that desktop file; nm-connection-editor is a separate package and is not installed.

xdg-user-dirs - JUSTIFIED, and not the shape the lead suggested. Its autostart entry exists, but the generator skips it because xdg-user-dirs ships its own user unit of the same name. What actually runs is xdg-user-dirs.service, WantedBy=graphical-session-pre.target, Type=oneshot, and the journal shows it starting and finishing in the same second at each of this boot's three logins. It is inactive/dead now. Cost at runtime: zero. The package is declared in desktop.txt for exactly this.

at-spi2-core - a dependency, not declared, and it leaks. Its autostart entry is correctly skipped (OnlyShowIn=GNOME;Unity against XDG_CURRENT_DESKTOP=sway); what starts it is D-Bus activation from the GTK applications in the session. Three at-spi2-registryd processes are running, started at 10:58, 12:57 and 16:10 - one per login. The two older ones are orphans: busctl --user status on the bus connections that activated them (:1.15, :1.231) reports 'No such device or address'. Cost is 6.2 MiB RSS but under 0.5 MiB PSS each, so it is a process leak rather than a memory one. Raised as TASK-95.

gvfs - JUSTIFIED, and the manifest comment is now verified rather than plausible. The comment says gvfs is there so the GTK file chooser can reach removable volumes. The journal caught the whole chain firing at 20:53:55 today: xdg-desktop-portal-gtk opened a file chooser, which activated gvfs-udisks2-volume-monitor, which activated udisks2 and dconf. Five gvfs processes, 13.0 MiB PSS in total.

dconf, upower, udisks2, accountsservice - all D-Bus activated, none declared, all with a traceable requester. udisks2 by the gvfs volume monitor, as above. upower at 11:05:04, two seconds after systemd-timedated, which is btop (show_battery = true) or fastfetch in the greeting card. accounts-daemon at 10:57:52, before any user session - that is ReGreet listing users. None is a surprise once traced, and none of the traces existed before today.

playerctld - D-Bus activated by waybar's mpris module, 0.8 MiB PSS. playerctl is declared. It does log 'could not get properties for active player' for TrackList and Playlists roughly every three seconds while a player is present; 82 journal lines this boot, against 2642 from sway. Noise, not a problem.

Xwayland - THE LEAD WAS A MEASUREMENT ARTEFACT, and the manifest comment is right. It is not running, and was not when this audit started. The figure recorded in TASK-66 was real, but transient: starting one X11 client (DISPLAY=:0 xprop -root -spy) brought Xwayland up at 138944 kB RSS = 135.7 MiB, which is the 135.8 MiB that was reported, and killing that client took it away again within fourteen seconds. sway runs it lazily with -terminate 10. The trap in the original reading is worth keeping: an X11 client that only reads a property never creates a window, so 'no X11 client in swaymsg -t get_tree' is not evidence that no X11 client exists. The /tmp/.X11-unix/X0 socket exists from sway startup regardless - sway creates the listening socket and spawns the server only on connect. Nothing declared in setup/packages/ is an X11 client, exactly as the desktop.txt comment claims.

spice-vdagentd - AC #3 is fully closed, and the situation has moved on since the comment. No spice package is installed at all; /usr/lib/systemd/system/spice-vdagentd.service and /usr/lib/udev/rules.d/70-spice-vdagentd.rules are both gone from the filesystem. Process 825 is still running from a deleted binary, and systemctl reports the unit as 'not-found' and 'active (running)' simultaneously. It is pure machine state and goes at the next reboot. Nothing in setup/ can or should address it; tools/session-inventory.sh reports it under 'Left behind' and says so.

TWO STALE FILES IN ~/.config/environment.d, raised as TASK-94. Replaying every deletion under setup/dotfiles/ out of git and checking which target paths still exist and are absent from 'chezmoi managed' turns up exactly two: 10-cursor.conf (deleted in 87abc7c) and 20-path.conf (deleted in ea2af45). chezmoi never removes a file it has stopped shipping. environment.d is the worst place for this, because the user manager reads *.conf in lexicographic order and the last wins - 10-cursor.conf sorts after 10-appearance.conf, so it would silently override a cursor change the repo makes, on this machine and not on a fresh one.

WHAT IS RUNNING BECAUSE THIS REPOSITORY ASKED FOR IT

Five units from setup/dotfiles/dot_config/systemd/user - autotiling, greeting, mako, polkit-agent, swayidle - plus waybar through its override drop-in, all active and all correctly under wayland-session@sway.target. No sway 'exec' line exists anywhere in the config, source or rendered, which is the rule CLAUDE.md states and is now checked rather than assumed. swaybg is spawned by sway itself from 'output * bg', which is how sway does backgrounds.

AC #4 - WHAT IS MACHINE-SPECIFIC, FOR TASK-14

A concrete list rather than a hypothesis, from this session:

  * spice-vdagent / spice-vdagentd - VM only, and already resolved by removal rather than by a profile. Kept here because TASK-14 should know it was considered and does not need it: the package is gone from setup/packages/ entirely, and the earlier note in this task establishes that on hardware it would have cost nothing at runtime anyway (its udev rule only fires for a virtio port named com.redhat.spice.0, and the user unit carries ConditionPathExists on a socket that would never appear).
  * WLR_NO_HARDWARE_CURSORS=1 in environment.d/10-appearance.conf - VM only in cause. It is there because virtio's hardware cursor plane renders the pointer upside down once 3D acceleration is on. On real hardware it forces software cursors for no reason. The file documents the cause; nothing scopes it.
  * The battery module in waybar - waybar logs 'No batteries.' at every start on this machine. Harmless, and it is the one entry here that a laptop profile would turn ON rather than off. See also TASK-25.
  * upower - pulled up by btop's show_battery on a machine with no battery. Follows the battery question rather than being its own decision.
  * gvfs and udisks2 - removable-volume support. Justified everywhere, but the VM has no removable volumes, so this is the clearest case of something whose value differs by machine without being wrong on either.
  * keyd - declared and running, and its configuration swaps left Alt and left Control at the evdev layer. That is a decision about a keyboard, not about a machine class, but it is the item most likely to need to differ on a machine with a different keyboard.

Nothing else found in this audit is machine-dependent. The session components, the portals, dconf, at-spi and the autostart entries behave identically on hardware.

VERIFICATION. tools/session-inventory.sh added and committed executable; bash -n clean, and --help, --brief and the full report all run to exit 0. It is the only file this session changed under tools/, and checks/ and setup/ were not touched.

checks/session.sh ends 74 passed / 2 failed on the reference machine right now, and neither failure comes from this work - it added no check. The zswap failure is TASK-89's tmpfiles drop-in waiting for a sync or a reboot. The screenshot failure is the session being locked: with swaylock on screen grim waits forever rather than failing, which is now TASK-96. Note that the check count has moved from 75 to 76 because TASK-89 added one.

FOLLOW-UP TASKS RAISED: TASK-92 (remove network-manager-applet), TASK-93 (make XDG autostart entries fail a check rather than surprise a reader), TASK-94 (chezmoi leaves deleted dotfiles on disk; two live in environment.d), TASK-95 (at-spi2-registryd leaks one per login), TASK-96 (the screenshot check hangs when locked).

ALSO SEEN, not this task's business but worth writing down: thunar is still installed and explicitly marked, while desktop.txt describes it as replaced by yazi and gvfs's own comment says dropping thunar left gvfs standing. checks/packages.sh should catch it; it belongs to TASK-44. And the '# ?' comment above pavucontrol in desktop.txt is stale in the other direction - pavucontrol is genuinely used, as the pulseaudio module's on-click.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-08-21 20:43
---
Measured while doing TASK-66, so these are numbers rather than estimates, all from tools/performance.sh on the reference VM.

nm-applet: 37.5 MiB RSS, 8.5 MiB by cgroup accounting, 0.2 CPU-seconds over the session. The bar genuinely has no tray - the only occurrence of the word in the rendered ~/.config/waybar/config.jsonc is inside a comment explaining that the tray was removed - so it is confirmed drawing into nothing. It is also the only entry in setup/packages/desktop.txt whose preceding comment is literally '# ?'.

The rest of the list, for scale: gvfs-daemon 12.0M, gvfs-metadata 0.9M, gvfs-udisks2-volume-monitor 4.0M, at-spi-dbus-bus 1.3M plus three dbus-activated atspi Registry instances, xdg-desktop-portal 3.4M, xdg-desktop-portal-gtk 6.4M, xdg-desktop-portal-wlr 0.9M, xdg-document-portal 1.4M, xdg-permission-store 0.6M. All the session components together are 88.3 MiB. Note that at-spi-dbus-bus has its own /etc/xdg/autostart entry from at-spi2-core, so it would keep starting even if nm-applet went.

Xwayland is running at 135.8 MiB with no X11 client visible in swaymsg -t get_tree. That is a bigger number than everything on the list above put together and it is not on the list.

AC #3 has moved: spice-vdagent was removed from the machine at 11:49 on 2026-08-21 and no longer appears in setup/packages/. The daemon is still running from a unit file that no longer exists - systemctl reports spice-vdagentd.service as 'not-found (Reason: Unit not found)' and 'active (running)' at the same time - because removing the package did not stop it. It will go at the next reboot. So the question AC #3 asks may now be about a package this repository no longer ships; worth re-reading before starting.

None of this is a memory problem, which matches what the description already says. system.slice is 121.8 MiB in total and the session is 88.3 MiB; on this VM the pressure comes from the tools being run, not from the desktop.
---

author: @claude
created: 2026-08-21 21:14
---
AC #5 and #6 are the two left, and both need an edit to checks/session.sh, which this session was not permitted to make. Handing over the exact block, run and verified against the live machine rather than written from memory - on the reference VM it produces 2 PASS and 2 FAIL, the failures being nm-applet's entry and the unit generated from it, and it will fall to 3 PASS / 0 FAIL as soon as TASK-92 removes the package.

It answers both criteria at once: #5 because the accepted set lives in the repository and a new entry is a failure rather than a surprise, and #6 because a process decided against coming back is exactly the case of an entry reappearing that is not in the list.

# ----------------------------------------------------------------------
section "XDG autostart (TASK-58)"

# /etc/xdg/autostart is how a package starts a process in this session without
# anything in setup/ saying so: uwsm reaches xdg-desktop-autostart.target
# through wayland-session-xdg-autostart@sway.target, and systemd generates a
# unit for every entry whose OnlyShowIn/NotShowIn lets it run under sway.
#
# That is exactly how nm-applet survived losing its reason to exist. The tray
# it drew into was removed from waybar, and nothing in this repository named
# nm-applet, so nothing reviewed it. Nothing here had ever read this directory.
#
# ACCEPTED is the set of entries this repository has looked at and decided to
# keep. A new name appearing means a package started something nobody reviewed.
ACCEPTED_AUTOSTART=(
    at-spi-dbus-bus.desktop     # at-spi2-core; OnlyShowIn=GNOME so it is skipped here
    xdg-user-dirs.desktop       # xdg-user-dirs; superseded by the unit of the same name
)

for entry in /etc/xdg/autostart/*.desktop; do
    [[ -e "$entry" ]] || continue
    name="$(basename "$entry")"
    known=0
    for allowed in "${ACCEPTED_AUTOSTART[@]}"; do
        [[ "$name" == "$allowed" ]] && known=1
    done
    if [[ "$known" -eq 1 ]]; then
        pass "XDG autostart: $name is an entry this repository has reviewed"
    else
        owner="$(pacman -Qoq "$entry" 2>/dev/null || true)"
        fail "XDG autostart: $name arrived with ${owner:-an unowned file} and nothing in setup/ has reviewed it - read it, decide, and add it to ACCEPTED_AUTOSTART or remove the package"
    fi
done

# The entries above are what is on disk. This is the shorter and more important
# list: what the generator actually turned into a running process. An entry can
# be present and correctly skipped, so the two lists are not the same question.
#
# mapfile rather than a `while read` loop: a pipeline into `while` runs in a
# subshell, and every pass/fail it records is discarded when that subshell ends.
mapfile -t autostarted < <(
    systemctl --user list-units --type=service --state=running --no-legend --no-pager 2>/dev/null \
        | awk '/@autostart\.service/ { print $1 }'
)
if [[ "${#autostarted[@]}" -eq 0 ]]; then
    pass "no XDG autostart entry is running a process in this session"
else
    for unit in "${autostarted[@]}"; do
        src="$(systemctl --user show "$unit" -p SourcePath | cut -d= -f2-)"
        fail "$unit is running, started by ${src:-an autostart entry} rather than by anything in setup/ - see TASK-58"
    done
fi

Two things worth keeping about writing it. mapfile rather than a 'while read' loop, because a pipeline into while runs in a subshell and every pass/fail recorded there is discarded when the subshell ends - the section would report nothing and still exit 0. And the two loops are deliberately separate questions: what is on disk, and what the generator actually started. at-spi-dbus-bus.desktop is present and correctly skipped, so checking only one of the two would either miss an entry or fail on one that is behaving.

ORDERING. If this lands before TASK-92 it fails on nm-applet, which is correct but means checks/session.sh does not end clean until the package goes. Either land TASK-92 first, or land both together.
---
<!-- COMMENTS:END -->
