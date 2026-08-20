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

**Cause.** `setup/dotfiles/` now contains a `run_onchange_` script, and chezmoi
runs scripts regardless of `--destination`.

**Fix.** Templates are still safe to render into a scratch directory. Scripts
are not sandboxed by pointing chezmoi elsewhere, so read what is in
`setup/dotfiles/` before assuming a render is harmless.

## A replace can match a comment about the section

**Symptom.** The edit reports success and the effect never appears. foot then
rejected its config outright.

**Cause.** Inserting `alpha=0.85` after the first occurrence of `[colors-dark]`
in `foot.ini` landed inside a comment mentioning that section, two lines above
the real one.

**Fix.** Anchor on the start of a line — `sed '/^\[colors-dark\]/a ...'` — or
match enough surrounding context to be unambiguous. More generally: when a
replace succeeds but the effect does not appear, check what it matched.

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
