---
name: scripting-traps
description: Concrete footguns that have already cost time in this repository — load before writing check scripts, editing config files programmatically, killing processes, or building rofi/dmenu menus.
---

# Scripting traps

Every trap below actually happened here. Each one is written symptom first,
because the symptom is what you will meet.

## `grep -q` in a pipeline under `pipefail`

**Symptom.** A check reports failure while the thing it checks is plainly
working. `checks/session.sh` announced that keyd had grabbed no input device on
a machine where keyd was running and the journal showed the match.

**Cause.** `grep -q` exits at the first match and closes the pipe. The writer
then takes SIGPIPE and exits 141, and `checks/session.sh` sets `pipefail`, so
the pipeline reports 141 rather than grep's 0.

Worse, it is intermittent by construction: if the writer finishes before grep
exits there is no SIGPIPE and the check passes. The zram check has the same
shape and had only ever passed by luck, because `swapon` writes one line.

**Fix.** Count instead, since `grep -c` reads its input to the end:

```bash
if [[ "$(cmd | grep -c pattern)" -gt 0 ]]; then
```

## Moving a command out of an `if` condition arms `set -e`

**Symptom.** Rewriting `if ! cmd | grep -q .; then` into an assignment — to fix
the `grep -q` trap above — makes a script that worked start exiting silently
part-way through, printing no error at all.

**Cause.** `set -e` does **not** apply to commands in an `if` condition; that is
the whole point of a condition being allowed to fail. Capturing the same command
into a variable removes that protection, because the assignment takes the
command substitution's exit status and `set -e` acts on it.

Here the command was `find` over three directories, one of which
(`/usr/local/share/applications`) does not exist. find prints exactly what it
was asked for and **still exits 1**, because a directory was missing. Harmless
as a condition; fatal as an assignment.

It hid, as well. An entry living in the *first* directory searched matched
before find reached the missing one, so find quit early and exited 0. Only an
entry in the **last** directory ever triggered it — and the symptom read as
"that desktop file is not installed" when it was sitting right there.

**Fix.** Decide what the exit status means, and say so:

```bash
found="$(find ... -print -quit 2>/dev/null || true)"
[[ -n "$found" ]] || echo "not found"
```

**The general form, which is the part worth keeping:** changing *where* a
command sits changes whether `set -e` is watching it. Moving one out of a
condition, out of a pipeline, or off the left side of `&&` is not a refactor —
it changes the error handling, silently, and the same code now behaves
differently.

## Bash variables cannot hold NUL

**Symptom.** Every row of a rofi menu renders as the visible text `icon`
followed by the icon name, instead of showing an icon.

**Cause.** rofi's per-row icon protocol is `text\0icon\x1f<name>` and needs a
literal NUL. A shell string cannot carry one; it is dropped silently, leaving
the marker text behind.

**Fix.** Build the menu in Python, write it to a file — files have no such
limitation — and give rofi the file. Write any parallel data, such as the
action for each row, to a second file so the index still maps back.

## `pkill -f` matches your own command line

**Symptom.** The shell dies mid-command, reported as exit code 144. Happened
three separate times in one session.

**Cause.** The pattern you are searching for is present in the command line of
the process doing the searching.

**Fix.** Get the pid another way — `pgrep` and filter out `$$`, or read it from
`swaymsg -t get_tree` — or do not use `-f`.

## Rendering to a scratch destination is no longer a dry run

**Symptom.** A command that only meant to preview templates changed the real
system: `xdg-mime` ran against the live machine.

**Cause.** `setup/dotfiles/` contains `run_onchange_` scripts, and chezmoi runs
scripts regardless of `--destination`. There are two now, and the second is more
disruptive than the first: the theme-reload script restarts waybar and reloads
sway on the machine you are sitting at.

**Fix.** Pass `--exclude=scripts` whenever the point is to see what a template
produces:

```bash
chezmoi --source ./setup --destination /tmp/render apply --force --exclude=scripts
```

Templates are safe to render; scripts are not sandboxed by pointing chezmoi
elsewhere. This is also what makes a before/after render diff trustworthy — it
is the cleanest way to prove a refactor of the templates changed no output, which
is exactly how the move from one palette to several themes was verified.

## A replace can match a comment about the section

**Symptom.** The edit reports success and the effect never appears. foot then
rejected its config outright.

**Cause.** Inserting `alpha=0.85` after the first occurrence of `[colors-dark]`
in `foot.ini` landed inside a comment mentioning that section, two lines above
the real one.

**Fix.** Anchor on the start of a line — `sed '/^\[colors-dark\]/a ...'` — or
match enough surrounding context to be unambiguous. More generally: when a
replace succeeds but the effect does not appear, check what it matched.

## `python3 -` and a heredoc fight over stdin

**Symptom.** A python block inside a shell script gets empty input and dies on
`JSONDecodeError: Expecting value: line 1 column 1 (char 0)`, even though the
command feeding it plainly produces output when run alone.

**Cause.** `python3 -` means *read the program from stdin*, and a heredoc **is**
stdin. Piping data in as well does not add a second channel — the heredoc wins,
the piped data is discarded, and `sys.stdin` is already at EOF by the time the
program runs.

```bash
printf '%s' "$json" | python3 - "$arg" <<'EOF'   # the JSON never arrives
data = json.load(sys.stdin)                      # reads nothing
EOF
```

**Fix.** Pick one channel for the program and another for the data. Passing the
data by path is the clearest:

```bash
tmp="$(mktemp)"; printf '%s' "$json" > "$tmp"
python3 - "$arg" "$tmp" <<'EOF'
with open(sys.argv[2]) as fh:
    data = json.load(fh)
EOF
rm -f "$tmp"
```

## A heredoc whose body contains its own delimiter

**Symptom.** `(eval):89: unmatched ` — a shell syntax error pointing at a line
far past where you thought the command ended.

**Cause.** Writing documentation *about* heredocs, using `<<'PY'` as the outer
delimiter, where the text being written contains a `PY` line of its own. The
outer heredoc ends at the first one, and the rest of the prose is parsed as
shell.

This bites hardest when generating scripts with scripts, which this repository
does constantly.

**Fix.** Choose an outer delimiter that cannot appear in the body
(`<<'OUTER_EOF'`), or write the payload to a file with an editor tool and splice
it in — which is more robust than picking a rarer word and hoping.

## zsh does not word-split unquoted parameters

**Symptom.** A `for f in $FILES` loop over a multi-line list runs exactly once,
with `$f` set to the entire list, and whatever it calls fails with a path that is
obviously several paths concatenated.

**Cause.** The interactive shell here is **zsh**, and zsh does not perform word
splitting on unquoted parameter expansions the way bash does. The habit is a bash
habit, and it fails quietly — the loop body still runs, so there is output and an
exit status, just for one bogus item. It looked like the edit had been applied to
every file when it had been applied to none.

**Fix.** Do not build a list in a shell variable when the loop matters. Use a
literal list, `${(f)VAR}` in zsh, or move the loop inside the language actually
doing the work:

```bash
for f in a.txt b.txt c.txt; do ...; done      # literal list: fine everywhere
```

Scripts in this repository run under `#!/usr/bin/env bash`, where splitting does
happen — so this only bites in ad-hoc commands, which is exactly where it is
least expected.

## `HOME=` is not enough to fake a home directory

**Symptom.** A test of whether a config file takes effect appears to prove it
does not. Setting `HOME=/tmp/fake` and writing
`/tmp/fake/.config/chezmoi/chezmoi.toml` produced a run that ignored the file
entirely — which nearly became a wrong conclusion recorded as a fact.

**Cause.** `XDG_CONFIG_HOME` is already set in this session, to the *real*
`~/.config`. Anything resolving configuration through XDG ignores `$HOME`
completely, so the program was reading the real directory and never looked at the
fake one.

**Fix.** Set both:

```bash
HOME=$T/home XDG_CONFIG_HOME=$T/home/.config cmd ...
```

The general form, which is the part worth keeping: **a test that fails to observe
an effect is not evidence the effect does not exist** until you have shown the
test could have observed it at all. Prove the mechanism in the positive direction
before trusting a negative result from it.

## A replace whose match string contains a glyph matches nothing

**Symptom.** A scripted edit reports success, the file looks untouched, and the
program behaves exactly as before. Five of seven edits to the waybar config
vanished this way and the fault only surfaced two steps later, in a screenshot,
because the bar still showed the old layout.

**Cause.** `str.replace` returns the string unchanged when the pattern is absent.
That is not an error — there is nothing to catch and nothing to log. So any
match string that is subtly wrong silently does nothing.

The subtly-wrong part here is the one this repository already warns about:
**Nerd Font glyphs do not survive being typed into a match string.** The config
holds `"format": " {usage}%"` with a real glyph; the match string ends up
holding a space where the glyph was; the two never match.

```python
s = s.replace('"format": " {usage}%",', ...)   # the glyph is not really there
```

**Fix.** Two rules, both cheap:

1. **Assert every replacement.** `assert old in s, old[:40]` turns a silent
   no-op into a loud failure at the point of the mistake.
2. **Never put a glyph in a match string.** Match on the *key*, not the value,
   and edit by line:

```python
prefix = '        "format":'
for i, line in enumerate(lines):
    if line.startswith(prefix):
        lines[i] = f'{prefix} "{{:%a %d %b}}",'
        break
else:
    sys.exit("no format line found")
```

Afterwards, count the glyphs before and after and diff the sets — a deliberate
removal is then distinguishable from an accidental one:

```python
glyphs = lambda s: sorted(f"U+{ord(c):04X}" for c in s if 0xe000 <= ord(c) <= 0xf8ff)
```

## waybar's PATH is not your PATH

**Symptom.** A bar module's `on-click` does nothing. Running the identical
command in a terminal works perfectly. waybar logs nothing at all.

**Cause.** waybar runs as a systemd user service, so its PATH is
`/usr/local/sbin:/usr/local/bin:/usr/bin:...` — and `~/.local/bin` is put on
PATH by `.zshrc`, which applies to interactive shells and to nothing else. A
bare `"on-click": "calendar"` therefore resolves when tested and is inert from
the bar, and waybar reports nothing when a click command cannot be found.

This is the same trap the desktop entries hit, in a second place.

**Fix.** Absolute paths, rendered by chezmoi:

```jsonc
"on-click": "{{ .chezmoi.homeDir }}/.local/bin/calendar"
```

And it applies transitively: a helper that calls a *sibling* helper by bare
name fails the same way. Resolve it relative to the script instead:

```bash
exec "$(dirname "$(readlink -f "$0")")/sway-toggle-window" ...
```

To test a click the way waybar runs it, take waybar's real environment from
`/proc` rather than constructing one — `env -i` with a hand-picked subset is not
faithful and produced two false failures here:

```python
env = dict(p.split("=", 1) for p in
           open(f"/proc/{pid}/environ").read().split("\0") if "=" in p)
subprocess.run(["sh", "-c", command], env=env)
```

## Logging out does not restart `systemd --user`

**Symptom.** A change to `~/.config/environment.d/` is made, the user logs out
of the graphical session and back in, and the variable is still not set. It
looks as though the file is being ignored.

**Cause.** `environment.d` is read by the **user manager**, and the user manager
is not tied to the graphical session. It starts at first login and keeps running
across logouts. So logging out of sway restarts sway, not `systemd --user`, and
the generators never re-run.

```bash
ps -o lstart= -p "$(pgrep -u "$(id -u)" -x systemd | head -1)"
# started at boot, not at the login you just performed
```

**Fix.** `systemctl --user daemon-reload` re-runs the environment generators
without a reboot. Confirm the result by starting something, not by reading the
file back:

```bash
systemd-run --user --pipe --wait --quiet sh -c 'echo $EDITOR'
```

Note that already-running processes keep the environment they started with, so
sway and everything it spawned still have the old values until the next login.

## `environment.d` cannot prepend to `PATH`

**Symptom.** The same file sets two variables. After `daemon-reload` one of them
is present and the other is not:

```
EDITOR=nvim                                    # applied
PATH=/usr/local/sbin:/usr/local/bin:/usr/bin   # unchanged, ours ignored
```

**Cause.** The generator produces the right value — running
`/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator`
by hand shows `PATH` with the addition. The manager does not adopt it, because
`PATH` is already set in its environment. Variables it does not already have are
taken; `PATH` is not.

**Fix.** Do not rely on it. If something must be found **by name**, put it
somewhere already on the default `PATH` — `/usr/local/bin` is on every process's
`PATH` on this machine and needs no session arrangement at all. That is where
`xdg-terminal-exec` lives, because glib looks it up by name and there is nowhere
to give it an absolute path.

For everything else, keep using absolute paths, which is what the desktop
entries and the bar's click commands already do.

**The general lesson**, which is the part worth keeping: *two variables in one
file are not one test.* Both looked configured; only one worked. Check the
variable you care about, in the environment that will actually use it, by
starting a process there.

## Desktop entries need an absolute `Exec`

**Symptom.** A launcher entry does nothing at all. No error anywhere, because
`Terminal=false` means nothing is printed.

**Cause.** `~/.local/bin` is on `PATH` only for interactive shells, added by
`.zshrc`. It is not on the `PATH` sway and rofi hand to what they spawn —
confirm with `systemctl --user show-environment`. So `Exec=notification-centre`
works when you test it from a terminal and fails from the launcher.

**Fix.** Use `{{ .chezmoi.homeDir }}/.local/bin/...` in a `.tmpl` entry. The
"Desktop entries" section of `checks/session.sh` now catches this. The sway
config had already learned the same lesson for keybindings.

## rofi will not start twice

**Symptom.** `Failed to set lock on pidfile: Rofi already running?`

**Cause.** Anything launched *from* rofi that itself runs rofi hits the lock.

**Fix.** Pass `-replace`. Note the warning still prints to stderr even when
`-replace` works, so the warning alone is not evidence of failure — check
whether the window actually appeared.

## dmenu mode ignores `show-icons`

**Symptom.** Icons configured in `config.rasi` do not appear in a dmenu list.

**Cause.** dmenu mode does not inherit it.

**Fix.** Pass `-show-icons` on the command line.

---

Every one of these produced a confident-looking wrong result rather than an
error: a passing check that was lying, a menu that rendered its own protocol as
text, an edit that reported success, a launcher entry that silently did
nothing. That is the same failure mode `CLAUDE.md` describes for configuration,
arriving through the scripts instead.
