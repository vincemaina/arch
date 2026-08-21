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
