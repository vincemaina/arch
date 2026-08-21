---
id: TASK-66
title: Performance review
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 10:32'
updated_date: '2026-08-21 20:44'
labels: []
dependencies: []
priority: medium
type: task
ordinal: 68000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
In general, lets just take a look at performance so far. How efficient are we. Does every default background process earn its place? What things have we added that have a memory, usage cost.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Measure boot with systemd-analyze / blame / critical-chain, and check what systemd-analyze does NOT count (bootloader menu timeout, firmware).
2. Measure session start from the journal: greeter -> password -> sway ready -> bar up, separating the human wait from the machine's.
3. Measure memory per session component from systemd's cgroup accounting and from systemd's own end-of-unit 'Consumed' lines, excluding the two cgroups that hold other people's work (wayland-wm@sway, greeting.service).
4. Measure zram: what it holds, what it has ever held, and whether the swap slots in use agree with it.
5. Measure waybar's CPU cost, and settle whether the module intervals matter by benchmarking throwaway waybar instances on a throwaway headless output - shipped intervals vs slowed vs no polled modules.
6. Measure what is CPU-rendered and costly under llvmpipe from cumulative CPU time per process.
7. Put everything reusable in tools/performance.sh (a report, never a verdict), report findings and raise follow-up tasks rather than changing anything.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
MEASUREMENT RUN 1 - BOOT

systemd-analyze: 866ms kernel + 1.720s initrd + 2.066s userspace = 4.653s; graphical.target at 2.061s.
Slowest units, devices excluded: initrd-switch-root 819ms, NetworkManager 273ms, accounts-daemon 111ms, user@1000 100ms, systemd-udev-trigger 84ms, polkit 68ms, upower 61ms.
Critical chain: graphical.target <- greetd <- systemd-user-sessions <- network.target <- NetworkManager (+273ms). systemd-user-sessions.service carries After=network.target upstream, so the greeter waits on NetworkManager starting even though NetworkManager-wait-online is disabled (confirmed disabled). ~273ms of the 2.066s userspace.

WHAT systemd-analyze DOES NOT COUNT. /boot/loader/loader.conf sets timeout 3 across 2 entries (default + fallback). This firmware (EDK II / OVMF) exports no LoaderTimeInitUSec or LoaderTimeExecUSec - checked, the efivars are absent - so systemd-analyze reports no firmware or loader component at all and its figure starts at the kernel. The real wait to a greeter is 3s of menu on top of 4.653s, i.e. the number everyone quotes leaves out about 39% of it.

ESP: 258M of 1022M used. initramfs-linux-fallback.img is 222M of that; initramfs-linux.img is 15M. Both intel-ucode.img (15M) and amd-ucode.img (307k) sit on the ESP although the microcode hook embeds the right one into the image - /proc/cmdline and both loader entries name only initramfs-linux.img, so neither .img file is loaded at boot.

SESSION START (from the journal, monotonic)
  4.710s greeter session opened
 13.547s user session opened   (8.837s of that is a human typing a password)
 14.200s uwsm starts sway
 15.004s sway ready
 15.006-15.018s greeting, mako, polkit-agent, swayidle, waybar all started
Password accepted to sway ready: 1.457s. Slowest user units: wayland-session-waitenv 800ms and wayland-wm@sway 799ms (the same wait, uwsm waiting for WAYLAND_DISPLAY/SWAYSOCK to appear), wayland-wm-env@sway 183ms, xdg-desktop-portal 136ms, gvfs-udisks2-volume-monitor 102ms. Nothing else above 60ms.

MEASUREMENT RUN 2 - MEMORY, SWAP, THE BAR

THE HEADLINE: ZSWAP SITS IN FRONT OF ZRAM, SO ZRAM BARELY DOES ANYTHING.
/sys/module/zswap/parameters/enabled is Y - the Arch kernel ships CONFIG_ZSWAP_DEFAULT_ON=y and nothing in setup/ turns it off. zswap compresses with zstd into its own pool capped at 20% of RAM, and only writes back to the actual swap device when that pool fills.

Measured after 10.5 hours of use:
  /proc/vmstat zswpout   920,911 pages (3.5 GiB) compressed into zswap
  /proc/vmstat zswpwb      9,415 pages (36 MiB)  ever written back to zram - 1.0%
  /proc/vmstat pswpout     9,415 pages           the same figure, i.e. all of zram's traffic
  /sys/block/zram0/mm_stat orig_data_size 6.5 MiB stored, mem_used_max 7.0 MiB
  zramctl                  1.9G disksize, 6.5M data, 2.2M total
  /proc/swaps              213 MiB of slots in use, of which zram holds 6.5 MiB
  /proc/meminfo            Zswap 105 MiB pool holding Zswapped 197 MiB (1.87x)

So the zram device sized at 50% of RAM has never held more than 7 MiB in a whole day. TASK-9 configured zram carefully - sizing expression, zstd, swap-priority 100, swappiness 180, page-cluster 0 - and every one of those settings is correctly applied and almost entirely inert, because the pages are intercepted a layer above. DECISIONS.md compares zram against a disk swapfile and never mentions zswap. This is the repository's usual failure mode: configuration that looks correct and does nothing.

Directly relevant to TASK-72 (deliberately not settled here): the effective compressed-swap capacity on this machine is not zram's 1.9 GiB, it is zswap's 20%-of-RAM pool with zram behind it. Any answer about zram sizing has to decide which layer is doing the work first.

MEMORY PRESSURE IS THE REAL COST, AND IT IS THE VM'S SIZE, NOT THE DESKTOP'S.
Session components, from systemd's own cgroup accounting, compositor excluded: 88.3 MiB total. The largest are waybar 15.7M, autotiling 15.4M, gvfs-daemon 12.0M, polkit-agent 8.8M, nm-applet 8.5M, greeting 7.4M; mako 1.1M and swayidle 0.4M. system.slice is 121.8 MiB in total (keyd 35.5M is the largest single daemon, then NetworkManager 18.0M, systemd-udevd 17.6M, journald 16.3M). sway itself 131.5 MiB RSS, swaybg 14.9 MiB. So a whole idle desktop is roughly 350 MiB.

Against that, on 3.9 GiB of RAM: kswapd0 has used 19 CPU-seconds since boot and showed 3.00% of one core in a 20s sample - second only to Claude Code and above sway. pgscan_kswapd 3,666,709 / pgsteal_kswapd 2,888,344 pages, i.e. 14 GiB scanned and 11 GiB of page cache reclaimed in a day on a 3.9 GiB machine. zswpin 449,124 pages read back. earlyoom has never fired (no kill lines, /proc/vmstat oom_kill 0). The desktop is not what is squeezing this machine; the tools being run on it are, and the VM is small.

THE BAR: NO MODULE INTERVAL IS WASTEFUL, MEASURED RATHER THAN ASSUMED.
Shipped intervals are cpu 3s, memory 5s, network 5s, clock 60s, battery 60s - 46 timer wake-ups a minute. Three throwaway waybar instances on a throwaway headless output, 60 seconds each, per the desktop-verification skill:
  shipped 3/5/5          waybar 0.13 CPU-s = 0.22% of one core
  slowed  10/30/30       waybar 0.13 CPU-s = 0.22% of one core
  no polled modules      waybar 0.11 CPU-s = 0.18% of one core
Slowing every interval saves nothing measurable. Removing every polled module saves 0.04% of one core. systemd's own end-of-session accounting agrees across seven sessions: waybar consumed between 1.578s/43min and 11.779s/3h13, i.e. 0.06-0.28% of one core, with a memory peak of 14-27 MiB. autotiling consumed 2.946s over 3h12 (0.026%).

CPU-RENDERED COST UNDER LLVMPIPE. sway itself is cheap: 87 CPU-s over 5h16 (0.46% of one core), 1.0-2.1% in live samples. foot is cheaper still - four terminals, 1 CPU-second between them. The expensive thing is the browser: qutebrowser's QtWebEngine renderer was 18.2% of one core with 860 MiB RSS while a page was open, 35 CPU-s in 304s of life. Nothing the repository itself starts is visibly costly to software-render.

LEFTOVERS FOUND WHILE MEASURING (this machine only, not the repository):
  - spice-vdagentd.service is still running from a unit file that no longer exists. spice-vdagent was removed at 11:49 today, after this boot, and the daemon survived the removal. It will go at the next reboot.
  - A headless output HEADLESS-2 is still plugged in from an earlier session, holding workspace 4 and a stranded floating terminal off-screen. waybar draws a full bar on every output, so each leftover headless output is another 1920px bar being composited. Unplug with: swaymsg 'output HEADLESS-2 unplug'
  - Xwayland is running (135.8 MiB) although no X11 client is visible in the tree.
Both of the first two are now reported by the new tool's 'Leftovers' section.

DELIVERABLE AND VERIFICATION

tools/performance.sh is the reusable half of this. It is a report and never a verdict - it always exits 0 - which keeps the checks/ versus tools/ distinction the CLAUDE.md describes. Sections: Boot (including what systemd-analyze does not count, and what is on the ESP), Session start (separating the human's wait from the machine's), Memory (per component, per slice, largest processes), Swap and zram (zswap first, because it changes the meaning of everything below it), What each component has cost over a whole session (systemd's own end-of-unit accounting, the most trustworthy figures available), The bar, an optional live CPU sample, Leftovers, and Not measured.

Everything needing root is listed under 'Not measured' rather than guessed - there is no password available in this session, so per-process PSS for system daemons, per-service I/O accounting and the contents of the initramfs are all recorded as unmeasured. The RSS figures for root-owned processes are labelled as RSS for that reason.

'Leftovers' exists because the measuring found two: a service running from a unit file that no longer exists, and a headless output left plugged in from an earlier session holding a workspace off-screen. Both were invisible until something looked, which is the failure mode this repository keeps hitting, so the tool now looks every time.

Verified: bash -n passes, chmod +x, and the script was run end to end three times - with --sample 20, --sample 10 and --no-sample - with every section producing output. ./checks/session.sh exits 0 afterwards. Every number in these notes came from a command run on this machine; nothing was inferred from a config file.

The waybar benchmark used the throwaway-headless-output technique from the desktop-verification skill: swaymsg create_output, three waybar instances pinned to it with their own -c and -s, the real bar untouched. The output was unplugged afterwards and the test instances killed by the pid that launched them, never by app_id or pkill -f.

Two measurement traps worth recording. First, a label containing a slash made the per-run log redirect fail, which under set -uo pipefail without -e reported 'waybar exited early' rather than 'could not open the file' - a harness fault indistinguishable from the fault it was built to detect. Second, another session ran a sync partway through the first attempt, restarting earlyoom, keyd, waybar and greeting; the numbers from that window were discarded and the benchmark re-run.

NOT DONE HERE, ON PURPOSE: nothing was changed. TASK-89 raised for the zswap/zram decision, TASK-90 for the boot menu. Measured evidence added as comments to TASK-58 (which already describes the nm-applet finding in detail) and TASK-72 (whose question the zswap finding changes), neither of them settled.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Measured the machine rather than changing it, and added tools/performance.sh as the reusable half - a report that never exits non-zero, covering boot, session start, memory per component, swap, per-unit lifetime cost, the bar, a live CPU sample, leftovers, and an explicit list of what needed root and was therefore left unmeasured.

Three findings carry the weight.

Compressed swap is not doing what the repository thinks. zswap is enabled by default in the Arch kernel and sits in front of zram: 920,911 pages went into zswap and 9,415 of them - 1.0% - ever reached zram, which has never held more than 7.0 MiB since boot despite being sized at 1.9 GiB. Every setting TASK-9 chose is correctly applied and almost entirely inert. Raised as TASK-89, with the numbers also added to TASK-72, whose sizing question has a hidden premise until this is decided.

The desktop is not what is expensive. All session components together are 88.3 MiB and system.slice is 121.8 MiB; a whole idle desktop is around 350 MiB on a 3.9 GiB machine. Against that, kswapd0 has used 19 CPU-seconds and reclaimed 11 GiB of page cache since boot, and showed 3.00% of one core in an idle sample - second only to Claude Code and above sway. The pressure comes from what is run on the VM, not from what the repository starts.

No bar module interval is wasteful, measured rather than assumed. Three throwaway waybar instances on a throwaway headless output, 60 seconds each: shipped intervals 0.22% of one core, slowed to 10/30/30 also 0.22%, every polled module removed 0.18%. The entire polling cost is 0.04% of one core, so slowing the readouts buys nothing. Recorded in the tool so it is not re-derived.

Also found: the boot menu's 3-second timeout is invisible to systemd-analyze on this firmware and is larger than the whole 4.653s it reports (TASK-90); and two leftovers on this machine - spice-vdagentd running from a unit file that no longer exists, and a headless output from an earlier session holding workspace 4 off-screen. The tool now reports both.

Verified with bash -n, three full runs of the script, and ./checks/session.sh exiting 0 afterwards.
<!-- SECTION:FINAL_SUMMARY:END -->
