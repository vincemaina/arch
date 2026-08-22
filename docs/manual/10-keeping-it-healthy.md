# Keeping it healthy

Once a machine is installed, this repository's job changes: instead of
building the system, it has to stay a true description of it. This chapter
covers updating a machine, the checks that verify it, and how to figure out
what actually went wrong when something does not work.

## Updating

`./sync.sh` applies the repository to the machine it runs on. Run it as your
normal user, never as root — it uses `sudo` itself only where a step
genuinely needs root, such as installing packages.

```bash
./sync.sh
./sync.sh --dry-run     # show what would change; change nothing
```

It reconciles the machine against the repository in a fixed order: packages
first, then machine-wide configuration
(`setup/system/apply-config.sh --activate`), then dotfiles through chezmoi,
then the login shell. That order matters — a unit only exists once its
package is installed, and switching the login shell before its configuration
is in place would hand you a broken shell at your next login.

Packages are reconciled with `pacman -T` (which understands a name satisfied
by a different package) to find anything declared but missing, then
`pacman -S --needed` installs it. **Nothing is ever removed.** A package
installed by hand outside the manifests is left alone; see "Package drift" below
for what `sync.sh` does notice about it.

For dotfiles, `sync.sh` runs `chezmoi status` before `apply`, so it reports
which files differ before touching anything, and afterwards prints the
`chezmoi re-add` command for each one — useful if a file differs because you
edited it on this machine rather than because the repository moved on. For a
change that should live only on this machine and never be synced either way,
use `~/.config/zsh/local.zsh`, which chezmoi deliberately ignores.

`--dry-run` shows the package diff and a `chezmoi diff`, and changes nothing.
Details of exactly what each phase does, and why the order is fixed, are in
[FLOW.md](../../FLOW.md).

## The four checks

Each of these lives under `checks/` and runs on the machine itself — clone
the repository there, or use an existing checkout, and run them from its
root. They are read-only: none of them installs, removes, restarts or
deletes anything. Each ends in a verdict and exits non-zero when it finds a
problem, which is the difference between `checks/` and `tools/` (below):
**checks give a verdict, tools give something to read.**

| Check | Answers | Run it |
| --- | --- | --- |
| `checks/session.sh` | Does the running machine match what the repository intends — swap, the OOM handler, session units, the boot path, the wallpaper, the selected theme? | After any change; it is the general-purpose one |
| `checks/packages.sh` | Does what is installed match `setup/packages/*.txt`, in both directions? | After changing a manifest, or when you suspect drift |
| `checks/sway-commands.sh` | Does every command the session invokes — from sway's config, from session units, from helper scripts — resolve to a package this repository declares? | After changing sway config, a session unit, or a helper script |
| `checks/sway-bindings.sh` | Is any key bound twice? Prints the whole binding table either way. | After changing a keybinding |
| `checks/manual.sh` | Does this manual still name files, helper scripts and `$mod` bindings that exist? | After changing a binding, renaming a helper, or editing a chapter |

A failure is not noise to dismiss — it names the exact thing that is wrong
and, in most cases, the exact command that fixes it. `checks/packages.sh` and
`checks/session.sh` in particular print the remedy alongside the failure
rather than leaving you to work it out.

`checks/manual.sh` is the odd one out: it checks a document rather than the
machine. It is there because prose goes stale exactly the way configuration
does, and a chapter describing a keybinding nobody bound reads precisely like
one that is right.

Know its limit, though — it can only tell you that the things the manual names
exist, never that a sentence about them is true. `$mod+Shift+minus` was Sway's
own default for sending a window to the scratchpad, and now shrinks one
instead. It was bound before and it is bound now, so the check has nothing to
say about it in either state, and a chapter still describing it as the
scratchpad key would pass. Existence is checkable. Meaning is not.

**`checks/session.sh` can hang, and this is expected, not a bug in the
check.** Its screenshot check calls `sway-screenshot`, and if the screen is
locked, `swaylock` holds an exclusive lock on every output — a screen
capture request against a locked output is not refused, it is queued until
the output is readable again. The check knows about this specific case and
skips it rather than hanging when it detects `swaylock` running, but it is
still bounded with a 15-second timeout for anything else that might hold the
output. If you run it manually and it appears to hang, check whether the
screen is locked before assuming something is broken.

`checks/session.sh` also prints a short list of things at the end that no
script can verify — whether the volume and playback keys actually change
anything, whether a screenshot binding produces a file you can see, whether a
polkit prompt actually appears. Those need a human, once, after any change
that could plausibly affect them.

## `checks/` versus `tools/`

`tools/` produces a report to read, not a pass/fail verdict, and never exits
non-zero for something that merely looks worth a second look:

- **`tools/shortcuts.sh`** — every keyboard shortcut this setup defines,
  grouped by the context it applies in (sway, a mode, the scroll layer,
  individual applications), derived from the live configuration rather than
  a hand-maintained list. Useful for finding out what a key does anywhere in
  the session, and for spotting the same physical key meaning different
  things in different tools.
- **`tools/performance.sh`** — what the machine actually costs to run: boot
  time, memory, CPU, all read from the running system rather than assumed.
- **`tools/session-inventory.sh`** — what is actually running in this
  session and who started it: a unit this repository ships, a unit that
  arrived with a package, an XDG autostart file, or the compositor itself.
  This is the tool that catches a process nobody in the repository ever
  asked for.

## Package drift, in both directions

`setup/packages/*.txt` is meant to describe the set of packages that should
be explicitly installed on this machine — not everything `pacman -Q` lists,
which includes the full dependency closure nobody chose directly.
`checks/packages.sh` compares that intent against the real system and reports
drift in either direction:

- **Installed but not declared.** Something was installed by hand — to try
  it, usually — and never added to a manifest. A rebuilt machine will not
  have it, and this is usually discovered long after whoever installed it
  has forgotten they did.
- **Declared but not installed.** A manifest asks for something the machine
  does not have. Run `./sync.sh`, or drop the line if it is no longer wanted.

There is a third, quieter case, and it is the one this repository actually
got wrong once: **a package can be declared, present, and still not treated
as wanted.** `pacman -S --needed` skips a package that is already installed
and does not change its install *reason* while skipping it — so a package
that arrived as someone else's dependency and is then added to a manifest
stays marked "installed as a dependency" forever. `pacman -T` reports it as
satisfied, so `sync.sh` never even tries to install it. The practical
consequence: `pacman -Rns` on whatever pulled it in takes the declared
package with it, exactly as if it had never been listed at all —
`polkit`, `mesa`, `adwaita-cursors` and `xdg-desktop-portal-gtk` were all
found in exactly this state on the reference machine. Both `sync.sh` and the
installer now mark every declared package explicit after installing it, and
`checks/packages.sh` fails if one drifts back to being merely a dependency.
The fix, when it does, is `sudo pacman -D --asexplicit <package>`.

## Reading logs when something fails

Read the log or the source before guessing. Every wrong guess in this
repository's history took longer than the two minutes it would have taken to
look.

- **A specific user unit**: `journalctl --user -u <unit>` for its log,
  `systemctl --user status <unit>` for whether it is running and its recent
  log tail together.
- **The whole session**: `journalctl --user -b` for everything the current
  session has logged since it started; `journalctl -b -k` for what the
  kernel saw over the same boot.
- **Sway's own state**, rather than its config file: `swaymsg -t get_outputs`,
  `get_inputs`, `get_tree` or `get_workspaces` tell you what sway actually
  applied, live.

**`systemctl show` reports the unit file, not the expansion.** If a unit's
`ExecStart` references an environment variable, `systemctl show <unit>
--property=ExecStart` shows you the literal string from the file, not what it
expanded to when the process actually started. To see what a running process
was actually invoked with, ask the process itself:

```bash
ps -C <name> -o args=
```

This is exactly how a real bug was caught here: earlyoom's `--avoid`/`--prefer`
regex arguments looked right in the unit file, and were only found to be
wrapped in literal quotes — which made them match nothing — by reading the
running process's actual command line rather than the file that produced it.

## Troubleshooting: verify against the running system

The single most common way this repository has broken is **configuration
that looks entirely correct and does nothing.** Reading the file back does
not prove anything applied — only the running system does. Real cases from
this repository's history, each caught by asking the system rather than
reasoning about the file:

- **Media keys called a binary that was never installed.** The playback
  keys ran `playerctl`, which was not in any manifest. Pressing them did
  nothing, and nothing anywhere said why — `playerctl` not existing produces
  no error a user would ever see, because play/pause on an idle system looks
  identical to play/pause silently failing. Found by resolving every command
  the session config invokes against the declared packages, which is exactly
  what `checks/sway-commands.sh` now does on every run.
- **Screenshots were written to a directory nothing had created.** The
  screenshot helper asked `xdg-user-dir PICTURES` for a destination, but on
  a machine where XDG user directories had never been set up, that command
  answered with `$HOME` instead of failing — so the fallback path, which only
  triggered on an *empty* answer, never ran, and files landed in the home
  directory instead of `~/Pictures`. The config looked correct; only
  actually pressing the binding and looking for the file showed otherwise.
- **polkit ran with no agent registered.** The service existed and the
  process was running, which is what a config-reading check would have
  reported as fine. Whether polkit actually routes an authentication request
  to it can only be shown by triggering a real request:
  `pkexec --disable-internal-agent true` (the flag matters — plain `pkexec`
  on a terminal falls back to its own text-mode prompt, which would say
  nothing about whether the graphical agent works at all).
- **A theme's `include` pointed at a file that did not exist**, and empty
  icon strings, and a boot entry naming an initramfs image that had never
  been built — all the same shape: something that parses cleanly, resolves
  to nothing, and fails silently at the point it is used rather than at the
  point it is defined.
- **A fix that did not work, and was kept anyway.** A SPICE guest agent was
  installed specifically to stop a ghost/upside-down cursor. It did not fix
  it, and the manifest comment describing why it was tried was later read as
  though it described the outcome — making the package look load-bearing for
  a bug it never actually fixed. It was eventually removed once the
  cursor issue was traced to a different cause entirely (see
  [Installing on a new machine](09-installing.md) for that story). The lesson this
  repository draws from it: when a fix does not work, take it back out, or
  write down plainly that it failed, where the next reader will actually see
  that before reusing the same idea.

None of these announced themselves. Several had been broken since the day
the relevant config was first committed, and were only found because someone
asked the running system a direct question instead of trusting that a file
which parses must be doing what it says. When something is not working:

1. Ask the specific tool what it actually applied — `swaymsg`, `rofi
   -dump-theme`, `makoctl list -j`, whichever program owns the behaviour —
   rather than re-reading the config that configures it.
2. Ask `systemctl --user status` and `journalctl --user -u <unit>` whether
   the unit is even running, and what it said when it started.
3. If the config references an external command, check that the command is
   actually installed and actually declared: `checks/sway-commands.sh` does
   this for the whole session in one pass.
4. If a fix seems to have not worked, do not leave it in "just in case" —
   either verify it again from first principles, or take it out and say so.
