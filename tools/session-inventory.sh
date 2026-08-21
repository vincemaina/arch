#!/usr/bin/env bash
set -euo pipefail

# What is this session actually running, and who asked for it?
#
# `checks/session.sh` answers "does the machine match what the repo intends".
# This answers the question the repo could not previously ask at all: **what is
# running that the repo never mentioned**. Those are different failures. A
# missing unit is caught by the first; a process that arrives with a package,
# starts itself, and is never named anywhere in setup/ is invisible to it.
#
# That is exactly how nm-applet survived losing its reason to exist. The systray
# module was removed from waybar because a GTK tray icon cannot be themed to
# match the bar, and nm-applet - which exists only to draw a tray icon - kept
# starting, because it is started by an XDG autostart file that ships inside
# network-manager-applet and nothing in this repository has ever read
# /etc/xdg/autostart.
#
# So this is a report, not a check: it never exits non-zero for a surprising
# process, because whether a process is wanted is a judgement. It puts the
# provenance in front of someone who can make it.
#
# For each thing running it reports:
#
#   * what started it - a unit this repo ships, a unit that came with a package,
#     an XDG autostart file, a D-Bus activation, or the compositor itself.
#   * which package owns the binary, and whether setup/packages/ declares it.
#   * RSS and PSS. RSS is what `ps` shows and double-counts shared pages; PSS
#     divides each shared page between its users and is the honest figure for
#     "what would come back if this went away". They differ by a lot here - the
#     GTK helpers are almost entirely shared libraries - and quoting RSS alone
#     has already produced one wrong conclusion in this repository's history.
#
# Everything comes from the running system and nothing needs root. PSS for a
# process you do not own is root-only, so system daemons are reported RSS-only
# and said to be.
#
# Usage:
#   tools/session-inventory.sh            # the whole report
#   tools/session-inventory.sh --brief    # skip the per-process table
#
# requires: systemctl pacman ps python3 busctl

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRIEF=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --brief) BRIEF=1; shift ;;
        -h|--help) sed -n '3,40p' "$0"; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

export LC_ALL=C

banner() { printf '\n==> %s\n' "$*"; }

# ------------------------------------------------------------------ autostart

banner "XDG autostart"
cat <<'EOF'
Desktop files in /etc/xdg/autostart are run by uwsm through
wayland-session-xdg-autostart@sway.target, which BindsTo the generic
xdg-desktop-autostart.target. They are shipped by packages, they are not
mentioned anywhere in setup/, and until this report nothing in this repository
looked at them. Each one below is a process this session starts that the repo
never asked for by name.

OnlyShowIn / NotShowIn are honoured by systemd-xdg-autostart-generator against
XDG_CURRENT_DESKTOP, so an entry can be present and correctly skipped.

EOF
python3 - "$REPO_ROOT" <<'PY'
import glob, os, subprocess, sys

repo = sys.argv[1]

declared = set()
for path in glob.glob(os.path.join(repo, "setup/packages/*.txt")):
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#"):
                declared.add(line)

current = os.environ.get("XDG_CURRENT_DESKTOP", "")
desktops = [d for d in current.split(":") if d]

entries = sorted(glob.glob("/etc/xdg/autostart/*.desktop"))
if not entries:
    print("  nothing in /etc/xdg/autostart")
    sys.exit()

units = subprocess.run(
    ["systemctl", "--user", "list-units", "--all", "--no-legend", "--no-pager",
     "--type=service"],
    capture_output=True, text=True).stdout

for path in entries:
    keys = {}
    with open(path, errors="replace") as fh:
        for line in fh:
            if "=" in line and not line.startswith("["):
                k, v = line.split("=", 1)
                keys.setdefault(k.strip(), v.strip())

    pkg = subprocess.run(["pacman", "-Qoq", path],
                         capture_output=True, text=True).stdout.strip() or "?"

    only = [d for d in keys.get("OnlyShowIn", "").split(";") if d]
    notin = [d for d in keys.get("NotShowIn", "").split(";") if d]
    if only and not any(d in only for d in desktops):
        verdict = f"skipped (OnlyShowIn={';'.join(only)})"
    elif any(d in notin for d in desktops):
        verdict = f"skipped (NotShowIn={';'.join(notin)})"
    else:
        verdict = "started"

    # The generator names its unit app-<escaped basename>@autostart.service, and
    # skips the entry entirely when a user unit of the same name already exists.
    stem = os.path.basename(path)[: -len(".desktop")]
    generated = [ln.split()[0].lstrip("*● ") for ln in units.splitlines()
                 if "@autostart.service" in ln and stem.replace("-", r"\x2d") in ln]
    state = ""
    for u in generated:
        shown = subprocess.run(
            ["systemctl", "--user", "show", u, "-p", "ActiveState", "--value"],
            capture_output=True, text=True).stdout.strip()
        state = f"  unit {u} is {shown}"

    mark = "declared" if pkg in declared else "NOT DECLARED in setup/packages"
    print(f"  {os.path.basename(path)}")
    print(f"      exec       {keys.get('Exec', '?')}")
    print(f"      package    {pkg}  ({mark})")
    print(f"      generator  {verdict}")
    if state:
        print(f"     {state}")
    print()
PY

# ------------------------------------------------------------------ units

banner "User units, and where each unit file came from"
cat <<'EOF'
A unit under ~/.config/systemd/user is one this repository ships. A unit under
/usr/lib/systemd/user arrived with a package and starts itself - either wanted
by a target uwsm reaches, or activated on demand by D-Bus. A unit under
/run/user/*/systemd is generated: either from an autostart file or transiently
by dbus-broker when a client asks for a bus name.

EOF
python3 - "$REPO_ROOT" <<'PY'
import glob, json, os, subprocess, sys

repo = sys.argv[1]
home = os.path.expanduser("~")

# systemctl show prints properties in its own order, not the order they were
# asked for, and --value drops the labels that would let you tell which is
# which. An empty property is omitted entirely, so positional parsing lines the
# values up against the wrong keys and reports every unit as package-shipped.
# Ask without --value and read the key=value pairs.
def show(unit, *props):
    args = ["systemctl", "--user", "show", unit]
    for p in props:
        args += ["-p", p]
    out = subprocess.run(args, capture_output=True, text=True).stdout
    d = {p: "" for p in props}
    for line in out.splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            d[k] = v
    return d

out = subprocess.run(
    ["systemctl", "--user", "list-units", "--all", "--no-legend", "--no-pager",
     "--type=service"],
    capture_output=True, text=True).stdout

names = []
for line in out.splitlines():
    parts = line.replace("●", " ").split()
    if parts and parts[0].endswith(".service"):
        names.append(parts[0])

groups = {"shipped by this repository": [], "shipped by uwsm": [],
          "shipped by a package": [], "generated from an XDG autostart file": [],
          "generated transiently by D-Bus activation": [], "unit file is gone": []}

for u in names:
    d = show(u, "FragmentPath", "SourcePath", "ActiveState", "SubState")
    frag, src = d["FragmentPath"], d["SourcePath"]
    state, sub = d["ActiveState"], d["SubState"]
    if state != "active":
        continue

    if not frag:
        key = "unit file is gone"
    elif frag.startswith(os.path.join(home, ".config/systemd/user")):
        key = "shipped by this repository"
    elif src.startswith("/etc/xdg/autostart"):
        key = "generated from an XDG autostart file"
    elif "/systemd/transient/" in frag:
        key = "generated transiently by D-Bus activation"
    elif os.path.basename(frag).startswith(("wayland-session", "wayland-wm")):
        key = "shipped by uwsm"
    else:
        key = "shipped by a package"

    pkg = ""
    if frag:
        pkg = subprocess.run(["pacman", "-Qoq", frag],
                             capture_output=True, text=True).stdout.strip()
    groups[key].append((u, f"{state}/{sub}", pkg, src))

for key in ("shipped by this repository", "shipped by uwsm", "shipped by a package",
            "generated from an XDG autostart file",
            "generated transiently by D-Bus activation", "unit file is gone"):
    rows = groups[key]
    if not rows:
        continue
    print(f"  {key}:")
    for u, state, pkg, src in sorted(rows):
        tail = f"  [{pkg}]" if pkg else ""
        if src:
            tail += f"  from {src}"
        print(f"      {state:16} {u}{tail}")
    print()
PY

# ------------------------------------------------------------------ processes

if [[ "$BRIEF" -eq 0 ]]; then
banner "Every process in this session"
cat <<'EOF'
PSS is the honest column. RSS counts every shared page in full against every
process holding it, so the GTK helpers below each appear to cost several
megabytes of libgtk that all of them are sharing one copy of.

"asked for" means setup/packages/ declares the package that owns the binary. It
is not the same question as whether the process is wanted - a declared package
can still be starting something nobody wants, which is the whole point of the
autostart section above.

EOF
python3 - "$REPO_ROOT" <<'PY'
import glob, os, subprocess, sys

repo = sys.argv[1]
home = os.path.expanduser("~")
uid = os.getuid()
hz = os.sysconf("SC_CLK_TCK")

declared = set()
for path in glob.glob(os.path.join(repo, "setup/packages/*.txt")):
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#"):
                declared.add(line)

# When did the current graphical session start? Anything session-shaped that
# predates it belongs to a session that has already ended.
session_start = subprocess.run(
    ["systemctl", "--user", "show", "wayland-wm@sway.service",
     "-p", "ActiveEnterTimestampMonotonic", "--value"],
    capture_output=True, text=True).stdout.strip()
session_start = int(session_start or 0) / 1e6   # seconds since boot

procs = []
for pid in os.listdir("/proc"):
    if not pid.isdigit():
        continue
    try:
        st = os.stat(f"/proc/{pid}")
        if st.st_uid != uid:
            continue
        with open(f"/proc/{pid}/stat") as fh:
            fields = fh.read().rsplit(") ", 1)[1].split()
        comm = open(f"/proc/{pid}/comm").read().strip()
        argv = [a for a in open(f"/proc/{pid}/cmdline").read().split("\0") if a]
        cgroup = open(f"/proc/{pid}/cgroup").read().strip()
    except OSError:
        continue

    # A process carrying file capabilities is marked non-dumpable by the
    # kernel, and /proc/PID/exe and smaps_rollup then need root even for your
    # own process. sway has cap_sys_nice=ep, so it is exactly the compositor
    # that vanishes if a missing exe link is treated as a dead process. Fall
    # back to argv[0] and report the memory as unreadable rather than dropping
    # the row.
    try:
        exe = os.readlink(f"/proc/{pid}/exe")
    except OSError:
        exe = argv[0] if argv else ""

    cpu = (int(fields[11]) + int(fields[12])) / hz
    started = int(fields[19]) / hz          # starttime, clock ticks since boot
    rss = pss = 0
    try:
        for line in open(f"/proc/{pid}/smaps_rollup"):
            if line.startswith("Rss:"):
                rss = int(line.split()[1])
            elif line.startswith("Pss:"):
                pss = int(line.split()[1])
    except OSError:
        pass

    unit = ""
    for part in cgroup.split("/"):
        if part.endswith(".service") or part.endswith(".scope"):
            unit = part
    procs.append(dict(pid=int(pid), comm=comm, argv=argv, exe=exe, cpu=cpu,
                      rss=rss, pss=pss, unit=unit, started=started))

# Which package owns each binary. An interpreter answers "python" for every
# script it runs, which is useless - autotiling and the workspace greeter are
# not the same thing - so for an interpreter, ask about the script instead.
INTERPRETERS = ("python", "bash", "sh", "zsh", "perl", "ruby", "node")
lookup = {}
for p in procs:
    target = p["exe"]
    base = os.path.basename(target)
    # python3.13, not python3: the version is in the file name, so match on the
    # prefix rather than an exact name.
    if any(base.startswith(i) for i in INTERPRETERS):
        for a in p["argv"][1:]:
            if a.startswith("/") and os.path.exists(a):
                target = a
                break
    p["owner_path"] = target
    lookup.setdefault(target, "")

owner = {}
for path in lookup:
    if not path:
        owner[path] = ""
        continue
    one = subprocess.run(["pacman", "-Qoq", path], capture_output=True, text=True)
    owner[path] = one.stdout.strip() or ""

frag_cache = {}
def provenance(unit):
    if unit in frag_cache:
        return frag_cache[unit]
    if not unit:
        frag_cache[unit] = "not under a unit"
        return frag_cache[unit]
    # Not --value: see the note in the units section above.
    out = subprocess.run(
        ["systemctl", "--user", "show", unit, "-p", "FragmentPath", "-p", "SourcePath"],
        capture_output=True, text=True).stdout
    props = {"FragmentPath": "", "SourcePath": ""}
    for line in out.splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            props[k] = v
    frag, src = props["FragmentPath"], props["SourcePath"]
    if unit.endswith(".scope"):
        # uwsm launches every application into its own transient scope, which is
        # why a terminal shows up here rather than inside wayland-wm@sway.
        v = "launched app"
    elif src.startswith("/etc/xdg/autostart"):
        v = "XDG autostart"
    elif frag.startswith(os.path.join(home, ".config/systemd/user")):
        v = "repo unit"
    elif "/systemd/transient/" in frag:
        v = "D-Bus activation"
    elif os.path.basename(frag).startswith(("wayland-session", "wayland-wm")):
        v = "uwsm"
    elif frag.startswith("/usr/lib/systemd/user"):
        v = "package unit"
    elif not frag:
        v = "UNIT FILE GONE"
    else:
        v = frag
    frag_cache[unit] = v
    return v

procs.sort(key=lambda p: -p["pss"])
print(f"  {'PID':>7} {'PSS':>9} {'RSS':>9} {'CPU-s':>8}  {'process':22} {'started by':16} {'package':24} declared")
print("  " + "-" * 118)

total_pss = total_rss = 0
stale_pids = set()
for p in procs:
    # Our own audit's shell pipeline is noise; it did not exist a second ago.
    if p["pid"] in (os.getpid(), os.getppid()):
        continue
    pkg = owner.get(p["owner_path"], "")
    prov = provenance(p["unit"])
    if not pkg:
        mark = "-"
    elif pkg in declared:
        mark = "yes"
    else:
        mark = "NO"
    note = ""
    # A component of the *graphical* session that started before this login
    # belongs to a login that has ended. Services in the user manager -
    # pipewire, dbus - legitimately outlive a logout and are not flagged.
    if prov in ("XDG autostart", "D-Bus activation", "repo unit") \
            and p["started"] + 5 < session_start:
        note = "  <- from an earlier login"
        stale_pids.add(p["pid"])
    if p["pss"] == 0 and p["rss"] == 0:
        note += "  <- non-dumpable, needs root"
    total_pss += p["pss"]
    total_rss += p["rss"]
    print(f"  {p['pid']:>7} {p['pss']/1024:8.1f}M {p['rss']/1024:8.1f}M {p['cpu']:8.1f}  "
          f"{p['comm'][:22]:22} {prov:16} {(pkg or '?')[:24]:24} {mark}{note}")

print("  " + "-" * 118)
print(f"  {'':>7} {total_pss/1024:8.1f}M {total_rss/1024:8.1f}M   total for the user session")

# The same binary running once per past login is the shape of a leak. It is
# worth naming separately because each copy is cheap and the count is not.
# Compare on the binary, not on comm: the kernel truncates comm to 15
# characters, so xdg-desktop-portal, -gtk and -wlr all read as
# "xdg-desktop-por" and three different programs look like three copies of one.
#
# Restricted to processes already marked "from an earlier login": a second
# dbus-broker is one bus per bus, not one per session, and flagging it teaches
# the reader to ignore the section. Only something session-scoped that outlived
# its session belongs here.
from collections import Counter
stale_exes = Counter(p["exe"] for p in procs if p["pid"] in stale_pids)
if stale_exes:
    print()
    print("  Session-scoped processes that outlived the session that started them:")
    for exe, n in sorted(stale_exes.items()):
        total = sum(1 for p in procs if p["exe"] == exe)
        print(f"    {n} of the {total} running copies of {exe}")
    print("    One per login, accumulating until reboot. Whatever starts these is")
    print("    not bound to wayland-session@sway.target.")
PY
fi

# ------------------------------------------------------------------ on demand

banner "On demand, and normally absent"
cat <<'EOF'
Not everything that costs memory is running now. Xwayland is the one that
matters: sway starts it lazily on the first X11 connection and it exits ten
seconds after the last one, so it is either absent or it is the largest single
process in the session. A snapshot that catches it running is not evidence that
something keeps it running.

It also does not need a window. An X11 client that only reads a property never
appears in `swaymsg -t get_tree`, so "no X11 window" does not mean "no X11
client" - which is how a transient 136 MiB was once read as a permanent one.

EOF
if pgrep -x Xwayland >/dev/null 2>&1; then
    ps -o pid=,rss=,args= -C Xwayland | awk '{ printf "  Xwayland IS running: pid %s, %.1f MiB RSS\n", $1, $2/1024 }'
    echo "  X11 clients connected right now:"
    if command -v xlsclients >/dev/null 2>&1; then
        xlsclients 2>/dev/null | sed 's/^/    /' || true
    else
        echo "    (xlsclients is not installed, so the client list is unavailable)"
    fi
else
    echo "  Xwayland is not running, which is the expected state: nothing declared"
    echo "  in setup/packages/ is an X11 client. Confirm the mechanism rather than"
    echo "  the absence with:"
    echo
    echo "    DISPLAY=:0 xprop -root -spy >/dev/null & sleep 2; ps -o rss= -C Xwayland"
    echo
fi
if [[ -S /tmp/.X11-unix/X0 ]]; then
    echo "  The X11 socket exists regardless - sway creates the listening socket at"
    echo "  startup and only spawns the server when something connects to it."
fi

# ------------------------------------------------------------------ system

banner "System services this session pulled up"
cat <<'EOF'
These run as root, so PSS is not readable and the figures are RSS. Several are
not enabled by anything: they are D-Bus activated the first time something asks
for their bus name, which means they appear minutes into a session with no unit
in setup/ naming them.

EOF
# A unit whose file is gone is listed with a leading bullet, which LC_ALL=C
# renders as "*" rather than "●" - so strip both, or the marker is read as the
# unit name and the whole row comes out empty.
systemctl list-units --type=service --state=running --no-legend --no-pager \
  | sed -e 's/^[[:space:]]*[*●][[:space:]]*/  /' \
  | awk '{ print $1 }' \
  | while read -r unit; do
        frag=$(systemctl show "$unit" -p FragmentPath --value | tr -d '\n')
        when=$(systemctl show "$unit" -p ActiveEnterTimestamp --value | tr -d '\n')
        trig=$(systemctl show "$unit" -p TriggeredBy --value | tr '\n' ' ')
        wanted=$(systemctl show "$unit" -p WantedBy --value | tr '\n' ' ')
        trig="${trig%% }"; wanted="${wanted%% }"
        pkg=""
        [[ -n "$frag" ]] && pkg=$(pacman -Qoq "$frag" 2>/dev/null || true)
        if [[ -z "$frag" ]]; then
            how="UNIT FILE GONE - package removed without stopping it"
        elif [[ -n "$trig" ]]; then
            how="triggered by $trig"
        elif [[ -n "$wanted" ]]; then
            how="wanted by $wanted"
        else
            how="D-Bus activated or started by hand"
        fi
        printf '  %-26s %-16s %s\n' "$unit" "${pkg:-?}" "$how"
        printf '  %-26s %-16s since %s\n' "" "" "${when:-?}"
    done

# ------------------------------------------------------------------ leftovers

banner "Left behind"
cat <<'EOF'
Things running now that belong to something that has already finished: a package
that was removed without its service being stopped, a process from a session
that ended, or a file this repository has deleted that chezmoi left on disk
because chezmoi does not remove what it no longer manages.

EOF
found=0

orphans=$(systemctl list-units --type=service --state=running --no-legend --no-pager \
    | grep -c 'not-found' || true)
if [[ "$orphans" -gt 0 ]]; then
    echo "  Running services whose unit file no longer exists:"
    systemctl list-units --type=service --state=running --no-legend --no-pager \
        | grep 'not-found' | awk '{ print "    " $2 }'
    echo "    These survive until the next reboot: removing a package does not stop"
    echo "    what it started. Nothing in setup/ can fix them - it is machine state."
    echo
    found=1
fi

if systemctl --user list-units --all --no-legend --no-pager --type=service \
     | grep -q 'atspi.Registry'; then
    n=$(systemctl --user list-units --all --no-legend --no-pager --type=service \
        | grep -c 'atspi.Registry' || true)
    if [[ "$n" -gt 1 ]]; then
        echo "  $n at-spi2-registryd instances are running."
        echo "    at-spi's registry is D-Bus activated into app.slice, which is not bound"
        echo "    to wayland-session@sway.target, so one is left behind by every graphical"
        echo "    session and they accumulate until reboot. Each is around 6 MiB RSS but"
        echo "    well under 1 MiB PSS, so this is a process leak rather than a memory one."
        echo
        found=1
    fi
fi

# chezmoi does not delete a file when the repo stops shipping it. A dead file in
# environment.d is the worst case, because it is read by the user manager and a
# later-sorting name overrides an earlier one.
if command -v chezmoi >/dev/null 2>&1 && [[ -d "$REPO_ROOT/setup" ]]; then
    managed=$(chezmoi --source "$REPO_ROOT/setup" managed --path-style absolute 2>/dev/null || true)
    stray=""
    for f in "$HOME"/.config/environment.d/*.conf; do
        [[ -e "$f" ]] || continue
        if ! printf '%s\n' "$managed" | grep -qxF "$f"; then
            stray+="    $f"$'\n'
        fi
    done
    if [[ -n "$stray" ]]; then
        echo "  Files in ~/.config/environment.d that this repository does not ship:"
        printf '%s' "$stray"
        echo "    environment.d is read in lexicographic order and the last file wins, so"
        echo "    one of these can silently override a value the repo does set. They also"
        echo "    mean the running session's environment is not the one a rebuild produces."
        echo
        found=1
    fi
fi

if command -v swaymsg >/dev/null 2>&1 && swaymsg -t get_outputs >/dev/null 2>&1; then
    heads=$(swaymsg -t get_outputs 2>/dev/null | grep -c '"HEADLESS' || true)
    if [[ "$heads" -gt 0 ]]; then
        echo "  $heads headless output(s) still plugged in - see tools/performance.sh."
        echo
        found=1
    fi
fi

[[ "$found" -eq 0 ]] && echo "  nothing left behind."

# ------------------------------------------------------------------ not measured

banner "Not measured"
cat <<'EOF'
  Needs root, so left blank rather than guessed:
    - PSS for system daemons. /proc/PID/smaps_rollup is root-only for processes
      you do not own, so the system table above is RSS and overstates them.
    - memory for a process carrying file capabilities, even your own. sway has
      cap_sys_nice=ep, which makes the kernel mark it non-dumpable, so its
      smaps_rollup is root-only and it is reported 0.0M above. `ps` still shows
      its RSS because that figure comes from /proc/PID/stat.
    - which client asked D-Bus to activate a system service. dbus-broker logs
      the activation, not the requester, and the audit log needs root.

  Not answerable from a running system:
    - what a session would cost without a component, which needs a fresh boot
      with that component absent. Stopping it here proves nothing about a
      rebuild, which is the only thing that matters for reproducibility.
EOF
echo
