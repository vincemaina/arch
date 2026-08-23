#!/usr/bin/env python3
"""The machine-local chezmoi configuration, read and written in one place.

    python3 desktop_config.py get data.theme neon
    python3 desktop_config.py set data.wallpaper.slate grid
    python3 desktop_config.py source

Or, from python:

    import desktop_config
    desktop_config.set_value("data.theme", "ember")
    desktop_config.data()["theme"]

WHY THIS EXISTS

Three scripts write this file now - ~/.local/bin/theme, ~/.local/bin/wallpaper
and ~/.local/bin/glow - and for a while the first two each had their own copy of
the writer. They disagreed. The theme
switcher's copy handled one level of tables and flattened anything deeper, so
choosing a wallpaper and then switching theme turned

    [data.wallpaper]
    slate = "grid"

into

    wallpaper = "{'slate': 'grid'}"

which is not a table, so every subsequent `chezmoi apply` died inside the sway
template and the desktop stopped being able to change at all. The bug was not
that the writer was wrong; it was that there were two of them and only one had
been taught about nesting.

WHAT THIS FILE IS

chezmoi's own config, holding the decisions that belong to this machine rather
than to the repository: which theme is selected, which wallpaper style each
theme uses, whether the bar glows for each theme, and where the checkout driving
it lives. Deliberately not tracked - switching a theme should not produce a
diff, and two machines syncing the same repository should be able to disagree.
chezmoi merges it over .chezmoidata, so anything set here wins.

It is written whole each time rather than patched, and every key is preserved,
so a value put here by something else survives.

The second half of this file answers the other side of the same question: not
what this machine has chosen, but what chezmoi will therefore render. Both
~/.local/bin/wallpaper and ~/.local/bin/glow need that, and a copy each is
exactly how the writer above went wrong.
"""

import json
import os
import pathlib
import subprocess
import sys
import tomllib

CONFIG = pathlib.Path(
    os.environ.get("XDG_CONFIG_HOME") or (pathlib.Path.home() / ".config")
) / "chezmoi" / "chezmoi.toml"

HEADER = """\
# chezmoi's machine-local configuration.
#
# Written by ~/.local/bin/theme, ~/.local/bin/wallpaper and ~/.local/bin/glow,
# all through ~/.local/lib/desktop_config.py - which is the only thing that
# writes it, after two separate writers disagreed about nested tables and broke
# every apply.
#
# Deliberately NOT part of the Arch repository. It holds the decisions that
# belong to this machine rather than to the setup - which theme is selected,
# which wallpaper each theme uses, whether the bar glows for each theme, and
# where the checkout driving it lives - so that switching leaves no diff, and so
# that two machines syncing the same repository can disagree.
#
# chezmoi merges this over .chezmoidata, so anything set here wins.
"""


def load():
    if not CONFIG.exists():
        return {}
    try:
        with open(CONFIG, "rb") as fh:
            return tomllib.load(fh)
    except (OSError, tomllib.TOMLDecodeError):
        return {}


def _quote(value):
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def _scalars(table):
    return [f"{k} = {_quote(v)}" for k, v in table.items()
            if not isinstance(v, dict)]


def save(config):
    """Serialise back to TOML.

    tomllib parses and does not write, and the file is small and shallow enough
    that hand-writing it is honest rather than clever. Tables are emitted after
    the bare keys because a key written after a [table] header would silently
    belong to that table - which is the classic way to corrupt a TOML file by
    generating it.
    """
    lines = [HEADER]
    lines += _scalars(config)

    for name, table in config.items():
        if not isinstance(table, dict):
            continue
        lines += ["", f"[{name}]"]
        lines += _scalars(table)
        for sub, nested in table.items():
            if isinstance(nested, dict):
                lines += ["", f"[{name}.{sub}]"]
                lines += _scalars(nested)

    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    CONFIG.write_text("\n".join(lines).rstrip("\n") + "\n")


def get_value(path, default=None):
    node = load()
    for key in path.split("."):
        if not isinstance(node, dict) or key not in node:
            return default
        node = node[key]
    return node


def set_value(path, value):
    config = load()
    keys = path.split(".")
    node = config
    for key in keys[:-1]:
        # A value of the wrong shape here is what the old duplicate writer left
        # behind. Replace it rather than crashing on it, so a machine that hit
        # that bug repairs itself the next time something is set.
        if not isinstance(node.get(key), dict):
            node[key] = {}
        node = node[key]
    node[keys[-1]] = value
    save(config)


# ----------------------------------------------------------------------
# Where the repository is, and what the templates can see
# ----------------------------------------------------------------------
#
# The other half of the same job. Everything above answers "what has this
# machine chosen"; this answers "what will chezmoi therefore render", which is
# not the same question, because chezmoi merges the file above OVER
# .chezmoidata. Reading themes.toml directly would be a second implementation
# of that merge, and the two would eventually disagree about which theme is
# current - which is the exact bug the writer above exists to prevent, one
# level up.
#
# It lives here rather than in each command because ~/.local/bin/wallpaper and
# ~/.local/bin/glow both need it, and a copy each is how the writer went wrong.


class NotFound(Exception):
    """The setup directory, or chezmoi's view of it, could not be found.

    Raised rather than exited, because every caller prints its own name in
    front of the message and a library that calls sys.exit takes that choice
    away from them.
    """


def resolve_source():
    """The chezmoi source directory driving this machine.

    In order: an override for anyone working on this; whatever sync.sh
    recorded, which is the live clone; and finally the copy install.sh leaves
    in /opt, so a machine that has never been synced still works.
    """
    if os.environ.get("ARCH_SETUP_SOURCE"):
        return os.environ["ARCH_SETUP_SOURCE"]
    recorded = get_value("sourceDir")
    if recorded and os.path.isdir(recorded):
        return recorded
    if os.path.isdir("/opt/arch-setup"):
        return "/opt/arch-setup"
    raise NotFound(
        "cannot find the setup directory. Run ./sync.sh from the repository "
        "once, or set ARCH_SETUP_SOURCE.")


_data = None


def data():
    """chezmoi's merged view: .chezmoidata with this machine's config over it.

    Cached for the life of the process. Nothing here runs long enough for the
    answer to change underneath it, and the commands that use it ask several
    times.
    """
    global _data
    if _data is None:
        result = subprocess.run(
            ["chezmoi", "--source", resolve_source(), "data"],
            capture_output=True, text=True)
        if result.returncode != 0:
            raise NotFound("chezmoi could not read the theme data")
        _data = json.loads(result.stdout)
    return _data


def current_theme():
    return data()["theme"]


def palette():
    merged = data()
    return merged["themes"][merged["theme"]]


def apply():
    """Re-render the dotfiles, so a value written here takes effect.

    --force because the target files were written by chezmoi and are being
    rewritten by chezmoi: there is no user edit to preserve, and a prompt would
    block a command launched from a menu, where nothing can answer it.
    """
    subprocess.run(
        ["chezmoi", "--source", resolve_source(), "apply", "--force"],
        check=True)


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "source":
        try:
            print(resolve_source())
        except NotFound as error:
            print(f"desktop_config: {error}", file=sys.stderr)
            sys.exit(1)
    elif len(sys.argv) >= 3 and sys.argv[1] == "get":
        value = get_value(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
        if value is None:
            sys.exit(1)
        print(value)
    elif len(sys.argv) == 4 and sys.argv[1] == "set":
        set_value(sys.argv[2], sys.argv[3])
    else:
        print(__doc__.split("WHY THIS EXISTS")[0].strip(), file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
