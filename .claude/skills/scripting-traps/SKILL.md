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

## Killing by `app_id` kills the terminal you are running in

**Symptom.** The session's own terminal closes, taking Claude Code and every
background agent with it. The tool result is exit 137 and nothing else. Repeated
three times before the cause was looked for, because "the terminal closed" reads
like a crash rather than like something the command did.

**Cause.** This:

```bash
swaymsg '[app_id=greeting] kill'      # tidying up a test window
```

`app_id=greeting` is not the test window. It is EVERY window with that app_id,
and the login greeting card from `greeting.service` is a full interactive shell
that this repository's own user works in - so it matched the terminal running
the command.

**Fix.** Target the specific container, never the class:

```bash
swaymsg -t get_tree | ...            # find the con_id of the window YOU spawned
swaymsg "[con_id=$id] kill"
```

or match on the pid you launched, or exclude the focused window explicitly.

Before killing anything by a selector, ask what the selector matches right now:

```bash
swaymsg -t get_tree | python3 -c "...print pid, app_id, focused for every node..."
```

The general form is the same as `pkill -f` two entries below: **a selector that
describes a category will match members of that category you did not have in
mind, including the one you are standing in.** The greeting card was the trap
here specifically because it looked transient - a fastfetch splash - and was
actually the everyday terminal. TASK-113 removed `greeting.service` itself, but
the app_id it warns about lives on as `floating-term` (see
`40-window-rules.conf`), and the lesson applies to any category selector, not
just that one.

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


## chezmoi will not create the destination root

**Symptom.** The render-to-a-scratch-directory check documented in `CLAUDE.md`
reports a failure for *every* theme:

```
chezmoi: .config: mkdir /tmp/.../out/.config: no such file or directory
```

which reads like the template is broken for all eight palettes at once.

**Cause.** `--destination` names where to write, it does not create it. chezmoi
makes directories *below* the destination root but not the root itself.

**Fix.** `mkdir -p` it first:

```bash
mkdir -p "$T/out"
chezmoi --source ./setup --destination "$T/out" apply --force --exclude=scripts
```

The trap is not the missing directory, it is that a harness fault is
indistinguishable from the fault it was built to detect. Eight themes failing
identically is a signal about the harness, not about the eight themes.

## `chezmoi managed` includes what `.chezmoiremove` deletes

**Symptom.** A check written to find dotfiles this repository deleted but left
on disk passed on a machine that demonstrably had one. Putting a stale file back
by hand and re-running produced a green result.

**Cause.** The check asked whether the target path was still managed, on the
reasoning that a file deleted and re-added under a different source name — a
plain file becoming a `.tmpl` — is legitimately still managed and must not be
reported. That much is right. What is not obvious is that `chezmoi managed`
also lists **every path in `.chezmoiremove`**, because managing a file's removal
is a kind of managing it:

```console
$ grep 10-cursor setup/dotfiles/.chezmoiremove
.config/environment.d/10-cursor.conf
$ chezmoi managed | grep 10-cursor
.config/environment.d/10-cursor.conf      # listed, despite being a removal
```

So the files the check existed for were exactly the files it skipped. It would
have passed forever.

**Fix.** Subtract `.chezmoiremove` from the managed set before comparing:

```python
managed = set(run(["chezmoi", "managed"]).stdout.split())
for line in open(source_dir + "/.chezmoiremove"):
    line = line.strip()
    if line and not line.startswith("#"):
        managed.discard(line)
```

The general form, and the reason this is worth a section: **a check that has
never failed has not been tested.** This one was written, run, and passed on the
first try, and the passing was the bug. Break the condition on purpose and watch
it go red before believing a green result — the same discipline as the
contrast-floor and language-server checks elsewhere in this repository, both of
which were also proven by deliberately breaking them.

## One patch is not a measurement

**Symptom.** Two contradictory conclusions about the same thing, both from
screenshots. Whether a translucent window actually masks what is behind it was
measured three times and answered wrongly twice:

- A before/after taken while the window behind was a *scrolling terminal*
  compared two different scenes, and reported that 75% of the content still
  showed through. There was no phenomenon to explain — the numbers described
  different pictures.
- A single 140x24 patch sampled inside the window came back perfectly uniform,
  and was read as proof it masked correctly. The patch had landed in a blank gap
  between two blocks of text.

**Cause.** Both are the same error: sampling something that varies, at one point
or one moment, and generalising.

**Fix.** Hold the scene still, sample a region rather than a point, and compare a
statistic rather than pixels:

```bash
swaymsg workspace 9        # static content, nothing redrawing
grim -t ppm -g '930,420 400x200' before.ppm
# ... open the window ...
grim -t ppm -g '930,420 400x200' after.ppm
# compare the 1st-to-99th percentile luminance spread of each
```

Spread through / spread behind came to 3%, against a window set to 97% opacity —
which is the answer, and is checkable against a number that was known in advance.
**Predict what the measurement should say before taking it**; that is what turns
a sample into evidence rather than a Rorschach test.

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

## keyd ignores a uinput device that is not keyboard-shaped

To prove what a keyd binding actually emits, you can create a uinput device,
inject a chord on it, and read back what appears on keyd's virtual keyboard.
That is real evidence rather than a config read-back, and it is worth the
trouble.

The first attempt declared only the fifteen key codes it intended to press.
keyd left the device alone:

```
DEVICE: ignoring dead:beef:a35c1de0  (keyd-probe)
```

despite `[ids]` being `*`. keyd decides what counts as a keyboard from the key
bitmap a device advertises, and a device with a dozen keys is not one. Every
injected key therefore bypassed keyd entirely, and the probe printed:

```
  plain k             -> (nothing)
  leftalt + k         -> (nothing)
  leftalt + semicolon -> (nothing)
```

which reads exactly like three broken bindings and was nothing of the kind.
The bindings were fine; the apparatus was not measuring.

Two fixes, and the second matters more than the first:

- Declare a whole keyboard — `open_uinput(range(1, 249))` — and inject only
  the keys you care about.
- **Make the probe prove it was grabbed before it reports anything.** Read
  `journalctl -u keyd` for the device name and abort loudly on `ignoring`.
  Without that check the probe cannot distinguish "the binding does not work"
  from "keyd never saw the key", and those two print identically.

The tell, if you meet this again: an unbound key. On a device keyd has grabbed,
even a key with no binding reappears on keyd's virtual keyboard. `plain k ->
(nothing)` means the device was never grabbed, not that `k` is broken.

The general shape is worth naming, because it is not specific to keyd: **a
measurement apparatus that silently is not measuring produces confident
negative results.** Every probe should first demonstrate that it is connected
to the thing it claims to observe.
