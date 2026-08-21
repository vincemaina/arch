#!/usr/bin/env bash
# What does this machine actually cost to run?
#
# A report, not a check: it never exits non-zero for a slow number, because
# "slow" here is a judgement and the point is to put the figures in front of
# someone who can make it. `checks/` gives verdicts; `tools/` gives something
# to read.
#
# Everything below comes from the running system - /proc, systemd's own
# accounting, the journal - and nothing needs root. Anything that would need
# root is printed under "Not measured" rather than guessed at.
#
# Usage:
#   tools/performance.sh                 # full report, 15s CPU sample
#   tools/performance.sh --sample 30     # longer sample, steadier numbers
#   tools/performance.sh --no-sample     # skip the sampling window entirely
#
# requires: systemd-analyze systemctl journalctl ps awk grep swaymsg

set -euo pipefail

SAMPLE_SECONDS=15

while [[ $# -gt 0 ]]; do
    case "$1" in
        --sample) SAMPLE_SECONDS="${2:?--sample needs a number of seconds}"; shift 2 ;;
        --no-sample) SAMPLE_SECONDS=0; shift ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

banner() { printf '\n==> %s\n' "$*"; }
rule()   { printf -- '----------------------------------------------------------------\n'; }

# ---------------------------------------------------------------- boot

banner "Boot"
systemd-analyze 2>&1 || true
echo
echo "Slowest units (devices excluded - a .device unit's time is the kernel"
echo "finding the hardware, not systemd waiting on anything):"
systemd-analyze blame 2>/dev/null | grep -v '\.device$' | head -12 || true
echo
echo "Critical chain (what the boot actually waited on):"
systemd-analyze critical-chain 2>/dev/null | tail -n +3 || true
echo
# systemd-analyze reports firmware and loader time only when the bootloader
# exported LoaderTimeInitUSec / LoaderTimeExecUSec. OVMF here does not, so the
# figure above silently starts at the kernel and the menu wait is invisible.
if [[ -r /boot/loader/loader.conf ]]; then
    t=$(awk '/^[[:space:]]*timeout/ { print $2 }' /boot/loader/loader.conf)
    entries=$(ls /boot/loader/entries/*.conf 2>/dev/null | wc -l)
    echo "Not in that figure: the boot menu. systemd-boot's timeout is ${t:-unset}s"
    echo "across $entries entries, and this firmware exports no loader timing, so"
    echo "the number above starts at the kernel and the wait in front of it is"
    echo "counted nowhere."
fi
echo
echo "What is on the ESP, and which of it a boot actually reads:"
ls -l /boot/*.img /boot/vmlinuz-* 2>/dev/null \
    | awk '{ printf "  %8.1f MiB   %s\n", $5/1048576, $NF }' || true
awk '/^(linux|initrd)/ { print "  named by a loader entry: " $2 }' /boot/loader/entries/*.conf 2>/dev/null | sort -u || true
df -h /boot 2>/dev/null | tail -1 | awk '{ print "  ESP " $3 " used of " $2 }' || true

# ---------------------------------------------------------------- session

banner "Session start"
echo "greetd hands over to uwsm, which starts sway. The gap between the"
echo "greeter appearing and a password being accepted is a human, not the"
echo "machine, so it is reported separately from the part we control."
echo
python3 - <<'PY'
import re, subprocess

out = subprocess.run(
    ["journalctl", "-b", "--no-pager", "-o", "short-monotonic"],
    capture_output=True, text=True).stdout

marks = [
    ("greeter session opened",   r"session opened for user greeter"),
    ("user session opened",      r"session opened for user (?!greeter)"),
    ("sway launched by uwsm",    r"Starting Main service for Sway"),
    ("sway ready",               r"Started Main service for Sway"),
    ("waybar started",           r"Started Highly customizable Wayland bar"),
    ("mako started",             r"Started Notification daemon"),
    ("greeting card started",    r"Started Greet empty workspaces"),
]

times = {}
for line in out.splitlines():
    m = re.match(r"\[\s*([0-9.]+)\]", line)
    if not m:
        continue
    t = float(m.group(1))
    for name, pat in marks:
        if name not in times and re.search(pat, line):
            times[name] = t

if not times:
    print("  (no session markers in this boot's journal)")
else:
    for name, _ in marks:
        if name in times:
            print(f"  {times[name]:8.3f}s  {name}")
    if "greeter session opened" in times and "user session opened" in times:
        print(f"\n  greeter waiting for a password: "
              f"{times['user session opened'] - times['greeter session opened']:.3f}s (human)")
    if "user session opened" in times and "sway ready" in times:
        print(f"  password accepted -> sway ready:  "
              f"{times['sway ready'] - times['user session opened']:.3f}s (ours)")
PY

echo
echo "Slowest user units:"
systemd-analyze --user blame 2>/dev/null | grep -vE '^\s*[0-9]+us' | head -12 || true

# ---------------------------------------------------------------- memory

banner "Memory"
free -m 2>&1 || true
echo
echo "Per-component, from systemd's own cgroup accounting."
echo
echo "wayland-wm@sway is excluded from the total: its cgroup holds every window"
echo "sway has ever spawned, so it measures your browser, not the compositor."
echo "greeting.service used to have the same problem and no longer does - it"
echo "launches each greeting terminal into its own transient scope - but the"
echo "journal still carries gigabyte-sized figures for it from before that fix."
echo
python3 - <<'PY'
import subprocess

units = subprocess.run(
    ["systemctl", "--user", "list-dependencies", "wayland-session@sway.target",
     "--plain", "--no-pager"],
    capture_output=True, text=True).stdout

names = sorted({w.strip("●○│├└─ ") for w in units.split()
                if w.strip("●○│├└─ ").endswith(".service")})

rows, total = [], 0
for u in names:
    show = subprocess.run(
        ["systemctl", "--user", "show", "-p", "MemoryCurrent", "-p", "CPUUsageNSec",
         "-p", "ActiveState", "--value", u],
        capture_output=True, text=True).stdout.split("\n")
    if len(show) < 3:
        continue
    state, mem, cpu = show[0], show[1], show[2]
    if state != "active":
        continue
    try:
        mem_mb = int(mem) / 1024 / 1024
        cpu_s = int(cpu) / 1e9
    except ValueError:
        continue
    rows.append((mem_mb, cpu_s, u))
    if not u.startswith("wayland-wm@"):
        total += mem_mb

for mem_mb, cpu_s, u in sorted(rows, reverse=True):
    tag = "   (holds every window sway spawned)" if u.startswith("wayland-wm@") else ""
    print(f"  {mem_mb:8.1f} MiB   {cpu_s:9.1f} CPU-s   {u}{tag}")

print(f"\n  {total:8.1f} MiB   session components, compositor excluded")
PY

echo
echo "Compositor and helpers, from /proc (RSS, so shared pages are counted"
echo "once per process - the true figure is lower):"
ps -eo rss=,comm=,args= 2>/dev/null \
  | awk '$2 ~ /^(sway|waybar|mako|swayidle|autotiling|nm-applet|keyd|swaybg|polkit-gnome-au|foot)$/ {
        printf "  %8.1f MiB   %s\n", $1/1024, $2 }' \
  | sort -rn || true

echo
echo "System-wide slices, so the desktop's share is separable from the daemons':"
for slice in system.slice user.slice init.scope; do
    systemctl show "$slice" -p MemoryCurrent --value 2>/dev/null \
        | awk -v s="$slice" '$1 ~ /^[0-9]+$/ { printf "  %8.1f MiB   %s\n", $1/1048576, s }'
done
echo
echo "Largest processes overall (what is actually eating this machine):"
ps -eo rss=,pmem=,comm= --sort=-rss 2>/dev/null | head -10 \
  | awk '{ printf "  %8.1f MiB  %5s%%  %s\n", $1/1024, $2, $3 }' || true

# ---------------------------------------------------------------- swap

banner "Swap and zram"
# zswap first, because if it is on it sits IN FRONT of zram and everything
# below it describes a device that barely gets used. The Arch kernel ships
# CONFIG_ZSWAP_DEFAULT_ON=y, so this is on unless something turns it off, and
# nothing in this repository does.
if [[ -r /sys/module/zswap/parameters/enabled ]]; then
    zswap_on=$(cat /sys/module/zswap/parameters/enabled)
    echo "  zswap enabled: $zswap_on   compressor: $(cat /sys/module/zswap/parameters/compressor 2>/dev/null)   pool cap: $(cat /sys/module/zswap/parameters/max_pool_percent 2>/dev/null)% of RAM"
    if [[ "$zswap_on" == "Y" ]]; then
        awk '/^Zswap:/ {pool=$2} /^Zswapped:/ {stored=$2}
             END {
               printf "  zswap pool        %8.1f MiB of RAM\n", pool/1024;
               printf "  holding           %8.1f MiB of swapped pages", stored/1024;
               if (pool > 0) printf "  (%.2fx)", stored/pool;
               printf "\n";
             }' /proc/meminfo
        awk '/^zswpout / {out=$2} /^zswpin / {in_=$2} /^zswpwb / {wb=$2}
             END {
               printf "  pages in / out    %8d in, %d out\n", in_, out;
               printf "  written back      %8d pages to the swap device below", wb;
               if (out > 0) printf "  (%.1f%% of everything swapped)", wb*100/out;
               printf "\n";
             }' /proc/vmstat
        echo "  ^ zswap absorbs the swap traffic; only the written-back share reaches zram."
        echo
    fi
fi
if [[ -e /sys/block/zram0/mm_stat ]]; then
    zramctl 2>&1 || true
    echo
    read -r orig compr used _limit maxused same _rest < /sys/block/zram0/mm_stat
    disksize=$(cat /sys/block/zram0/disksize)
    ram_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    awk -v orig="$orig" -v compr="$compr" -v used="$used" -v maxused="$maxused" \
        -v same="$same" -v disksize="$disksize" -v ram_kb="$ram_kb" 'BEGIN {
        printf "  disksize          %8.1f MiB  (%.0f%% of RAM)\n", disksize/1048576, disksize*100/(ram_kb*1024);
        printf "  data stored       %8.1f MiB  (uncompressed)\n", orig/1048576;
        printf "  compressed to     %8.1f MiB", compr/1048576;
        if (orig > 0) printf "  (%.2fx)", orig/compr;
        printf "\n  RAM actually used %8.1f MiB  (incl. allocator overhead)\n", used/1048576;
        printf "  high water mark   %8.1f MiB  (most RAM zram has ever held)\n", maxused/1048576;
        printf "  same-filled pages %8.0f       (stored as a flag, costing nothing)\n", same;
    }'
    echo
    # The smoking gun for a zswap-in-front-of-zram setup: the kernel has
    # allocated swap slots out of zram's address space, but the pages those
    # slots stand for are sitting in zswap's pool, not in zram.
    awk -v orig="$orig" '/^\/dev\/zram0/ {
        used_mib = $4/1024;
        stored_mib = orig/1048576;
        printf "  swap slots in use %8.1f MiB, of which zram actually holds %.1f MiB\n", used_mib, stored_mib;
        if (used_mib > 4 * (stored_mib + 1))
            printf "  ^ the gap is zswap: the pages exist, they are just not in this device.\n";
    }' /proc/swaps
    echo
    echo "  vm.swappiness   $(cat /proc/sys/vm/swappiness)"
    echo "  vm.page-cluster $(cat /proc/sys/vm/page-cluster)"
else
    echo "  no zram device on this machine"
fi
echo
echo "Reclaim pressure since boot - kswapd's CPU time is how hard the kernel has"
echo "had to work to find free pages. On a machine with headroom it is near zero."
ps -eo times=,comm= 2>/dev/null \
  | awk '$2 ~ /^(kswapd|kcompactd|khugepaged)/ { printf "  %6ds  %s\n", $1, $2 }' || true
awk '/^(pgscan_kswapd|pgsteal_kswapd|pswpin|pswpout|oom_kill)/ { printf "  %-16s %s\n", $1, $2 }' /proc/vmstat || true

# ---------------------------------------------------------------- lifetimes

banner "What each component has cost over a whole session"
echo "systemd prints an accounting line every time a unit stops. These are the"
echo "most trustworthy figures here - a full session's CPU and peak memory,"
echo "measured by the thing that supervises the unit, not sampled by us."
echo
# systemd logs the same figure twice - once on stop, once as the new instance
# starts - and the second copy carries a wall clock of a few milliseconds. Drop
# those, or every unit appears to have run for no time at all.
journalctl --user -b --no-pager 2>/dev/null \
    | grep -oE '[A-Za-z0-9@\\.x_-]+\.service: Consumed [^,]+ CPU time over [^,]+ wall clock time, [^,]+ memory peak' \
    | grep -v 'over [0-9]*m\?s wall' \
    | sort -u | tail -20 | sed 's/^/  /' || true
echo
echo "(Repeats are separate sessions. wayland-wm@sway carries the same caveat as"
echo "above, and greeting.service lines older than the transient-scope fix do"
echo "too - a gigabyte there is a terminal, not a greeter.)"

# ---------------------------------------------------------------- the bar

banner "The bar"
CFG="$HOME/.config/waybar/config.jsonc"
if [[ -r "$CFG" ]]; then
    echo "Polling intervals in the rendered config. A wake-up on a timer is a bar"
    echo "redraw, and under llvmpipe a redraw is CPU work - but measurably not much"
    echo "of it. Three throwaway waybars on a headless output, 60s each: shipped"
    echo "intervals cost 0.22% of one core, the same bar slowed to 10/30/30 also"
    echo "0.22%, and a bar with every polled module removed 0.18%. So the polling"
    echo "is worth 0.04% of one core and the rest is waybar existing. Slowing these"
    echo "buys nothing measurable - see TASK-66 before spending a readout on it."
    echo
    python3 - "$CFG" <<'PY'
import json, re, sys

raw = open(sys.argv[1]).read()
raw = re.sub(r"^\s*//.*$", "", raw, flags=re.M)
cfg = json.loads(raw)

shown = []
for key in ("modules-left", "modules-center", "modules-right"):
    shown += cfg.get(key, [])

# waybar's own defaults for the modules this bar uses, from waybar-*(5).
defaults = {"clock": 60, "battery": 60}

wakes_per_min = 0.0
for m in shown:
    conf = cfg.get(m, {})
    interval = conf.get("interval", defaults.get(m))
    if interval is None:
        print(f"  {m:16} event-driven (no timer)")
    else:
        print(f"  {m:16} every {interval}s")
        wakes_per_min += 60.0 / interval

print(f"\n  {wakes_per_min:.0f} timer wake-ups per minute across the whole bar")
PY
else
    echo "  no rendered waybar config at $CFG"
fi
echo
if pid=$(pgrep -x waybar 2>/dev/null | head -1) && [[ -n "$pid" ]]; then
    read -r _ _ _ _ _ _ _ _ _ _ _ _ _ ut st _ < /proc/"$pid"/stat
    hz=$(getconf CLK_TCK)
    up=$(awk '{print int($1)}' /proc/uptime)
    start=$(awk '{print $22}' /proc/"$pid"/stat)
    awk -v ut="$ut" -v st="$st" -v hz="$hz" -v up="$up" -v start="$start" 'BEGIN {
        alive = up - start/hz;
        cpu = (ut+st)/hz;
        printf "  waybar has used %.1f CPU-seconds in %.0f seconds alive = %.2f%% of one core\n", cpu, alive, cpu*100/alive;
        printf "  extrapolated: %.0f CPU-seconds per hour\n", cpu*3600/alive;
    }'
else
    echo "  waybar is not running"
fi

# ---------------------------------------------------------------- sampling

if [[ "$SAMPLE_SECONDS" -gt 0 ]]; then
    banner "Live CPU over ${SAMPLE_SECONDS}s"
    echo "Leave the machine alone while this runs - typing into a terminal is"
    echo "sway and foot rendering glyphs, and it will dominate the sample."
    echo
    python3 - "$SAMPLE_SECONDS" <<'PY'
import os, sys, time

seconds = int(sys.argv[1])
hz = os.sysconf("SC_CLK_TCK")

def snapshot():
    out = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/stat") as fh:
                fields = fh.read().rsplit(") ", 1)[1].split()
            name = open(f"/proc/{pid}/comm").read().strip()
            out[pid] = (name, int(fields[11]) + int(fields[12]))
        except (OSError, IndexError):
            continue
    return out

a = snapshot()
time.sleep(seconds)
b = snapshot()

ncpu = os.cpu_count() or 1
rows = []
for pid, (name, ticks) in b.items():
    if pid in a:
        delta = ticks - a[pid][1]
        if delta > 0:
            rows.append((delta / hz / seconds * 100, name, pid))

rows.sort(reverse=True)
total = sum(r[0] for r in rows)
for pct, name, pid in rows[:15]:
    print(f"  {pct:6.2f}% of one core   {name} ({pid})")
print(f"\n  {total:6.2f}% of one core in total, across {ncpu} cores "
      f"= {total/ncpu:.2f}% of the machine")
PY
fi

# ---------------------------------------------------------------- leftovers

banner "Leftovers"
echo "Things that are costing memory or compositing without anyone asking them"
echo "to. Every one of these has been left behind by a session that ended badly."
echo
found_leftover=0

# A unit whose file no longer exists but whose process is still running: the
# package was removed without the service being stopped, so it survives until
# the next reboot with nothing left to manage it.
orphans=$(systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null \
    | grep -c 'not-found' || true)
if [[ "$orphans" -gt 0 ]]; then
    echo "  $orphans running service(s) whose unit file no longer exists:"
    systemctl list-units --type=service --state=running --no-legend --no-pager 2>/dev/null \
        | grep 'not-found' | awk '{ print "    " $2 }'
    found_leftover=1
fi

# Headless outputs from `swaymsg create_output`, which the verification skill
# hands out freely. sway composites them like any other screen, and a workspace
# that lands on one is invisible until it is unplugged.
if command -v swaymsg >/dev/null 2>&1 && swaymsg -t get_outputs >/dev/null 2>&1; then
    swaymsg -t get_outputs 2>/dev/null | python3 -c "
import sys, json
outs = [o for o in json.load(sys.stdin) if o['name'].startswith('HEADLESS')]
if outs:
    print(f'  {len(outs)} headless output(s) still plugged in:')
    for o in outs:
        print(f\"    {o['name']}  {o['rect']['width']}x{o['rect']['height']}  showing workspace {o.get('current_workspace')}\")
    print('    unplug with: swaymsg \'output HEADLESS-n unplug\'')
" || true
    if [[ "$(swaymsg -t get_outputs 2>/dev/null | grep -c HEADLESS)" -gt 0 ]]; then
        found_leftover=1
    fi
fi

[[ "$found_leftover" -eq 0 ]] && echo "  nothing left behind."

# ---------------------------------------------------------------- not measured

banner "Not measured"
rule
cat <<'EOF'
  Needs root, so deliberately left blank rather than guessed:
    - per-process PSS for system daemons (NetworkManager, keyd, earlyoom,
      polkitd, udisks2, upower). /proc/PID/smaps_rollup is root-only for
      processes you do not own, so the figures above are RSS for those.
    - I/O accounting per service (/proc/PID/io, same restriction).
    - what is inside each initramfs (lsinitcpio needs to read root-only files;
      the sizes above come from /boot, which is world-readable).

  Not measurable from a running system at all:
    - what boot would cost without a component, which needs a rebuild.
EOF
rule
echo
