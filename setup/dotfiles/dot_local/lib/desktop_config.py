#!/usr/bin/env python3
"""The machine-local chezmoi configuration, read and written in one place.

    python3 desktop_config.py get data.theme neon
    python3 desktop_config.py set data.wallpaper.slate grid

Or, from python:

    import desktop_config
    desktop_config.set_value("data.theme", "ember")

WHY THIS EXISTS

Two scripts write this file - ~/.local/bin/theme and ~/.local/bin/wallpaper -
and for a while each had its own copy of the writer. They disagreed. The theme
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
theme uses, and where the checkout driving it lives. Deliberately not tracked -
switching a theme should not produce a diff, and two machines syncing the same
repository should be able to disagree. chezmoi merges it over .chezmoidata, so
anything set here wins.

It is written whole each time rather than patched, and every key is preserved,
so a value put here by something else survives.
"""

import os
import pathlib
import sys
import tomllib

CONFIG = pathlib.Path(
    os.environ.get("XDG_CONFIG_HOME") or (pathlib.Path.home() / ".config")
) / "chezmoi" / "chezmoi.toml"

HEADER = """\
# chezmoi's machine-local configuration.
#
# Written by ~/.local/bin/theme and ~/.local/bin/wallpaper, both through
# ~/.local/lib/desktop_config.py - which is the only thing that writes it, after
# two separate writers disagreed about nested tables and broke every apply.
#
# Deliberately NOT part of the Arch repository. It holds the decisions that
# belong to this machine rather than to the setup - which theme is selected,
# which wallpaper each theme uses, and where the checkout driving it lives - so
# that switching leaves no diff, and so that two machines syncing the same
# repository can disagree.
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


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "get":
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
