#!/usr/bin/env python3
"""The only thing that speaks mpv's JSON IPC for focus-music.

~/.local/bin/focus-music owns the menus; this owns the connection, the queue
operations and the titles. The split follows desktop_config.py: one writer for
one piece of external state, because the last time two callers each had their
own copy of a format they disagreed about it and broke everything downstream.

WHY A TITLE MAP EXISTS

mpv only knows what a file is called once it has loaded it. Ask it for the
playlist and the entry being played comes back with a title while everything
queued behind it comes back as a bare URL - which is useless as a queue view,
since a YouTube URL says nothing about what it is.

So titles are remembered here, keyed by URL, when an entry is added. The map is
strictly a lookup: mpv's playlist remains the source of truth for what is
queued and in what order, and the map is pruned against it on every read. It
can therefore be stale or incomplete, but it cannot make the queue lie about
itself - the worst case is an entry showing its URL, which is what mpv said
anyway.

Anything added to mpv by something other than this helper simply has no entry
and displays as its URL.
"""
from __future__ import annotations

import json
import os
import socket
import sys

CONNECT_TIMEOUT = 2.0
REPLY_TIMEOUT = 10.0


def socket_path() -> str:
    # The override exists so the whole thing can be exercised against a
    # throwaway mpv, rather than against whatever is playing right now.
    override = os.environ.get("FOCUS_MUSIC_SOCKET")
    if override:
        return override
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return os.path.join(runtime, "focus-music.sock")


def titles_path() -> str:
    override = os.environ.get("FOCUS_MUSIC_TITLES")
    if override:
        return override
    state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return os.path.join(state, "focus-music", "titles")


class Mpv:
    def __init__(self, path: str):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(CONNECT_TIMEOUT)
        self.sock.connect(path)
        self.sock.settimeout(REPLY_TIMEOUT)
        self.buf = b""

    def command(self, *args):
        payload = json.dumps({"command": list(args)}).encode() + b"\n"
        self.sock.sendall(payload)
        while True:
            while b"\n" in self.buf:
                line, self.buf = self.buf.split(b"\n", 1)
                if not line.strip():
                    continue
                message = json.loads(line)
                # Events arrive unsolicited on the same connection; the reply
                # is the next object that is not one.
                if "event" in message:
                    continue
                return message
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("mpv closed the connection")
            self.buf += chunk

    def get(self, prop):
        reply = self.command("get_property", prop)
        return reply.get("data") if reply.get("error") == "success" else None

    def playlist(self):
        return self.get("playlist") or []


def connect() -> Mpv:
    return Mpv(socket_path())


def load_titles() -> dict[str, str]:
    try:
        with open(titles_path(), encoding="utf-8") as handle:
            pairs = {}
            for line in handle:
                url, _, title = line.rstrip("\n").partition("\t")
                if url and title:
                    pairs[url] = title
            return pairs
    except OSError:
        return {}


def save_titles(mapping: dict[str, str]) -> None:
    path = titles_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        for url, title in mapping.items():
            handle.write(f"{url}\t{title}\n")
    os.replace(tmp, path)


def remember(url: str, title: str) -> None:
    mapping = load_titles()
    mapping[url] = title
    save_titles(mapping)


def quoted(option: str, value: str) -> str:
    # mpv's %n% form prefixes the byte length, so a comma, quote or newline in
    # a title cannot terminate the option list early.
    return f"{option}=%{len(value.encode())}%{value}"


def cmd_add(mode: str, url: str, title: str, finite: bool = False) -> int:
    mpv = connect()
    empty = not mpv.playlist()

    # The -play suffix on mpv's loadfile flags means "start playback if nothing
    # is playing", NOT "switch to this one now". insert-next-play therefore
    # puts the file in the right place and, with music already on, leaves it
    # sitting there - which makes "play now" behave exactly like "play next"
    # while looking correct in the source. Playing it now takes a second,
    # explicit step.
    flag = "append-play" if empty else {
        "now": "insert-next",
        "next": "insert-next",
        "queue": "append-play",
    }[mode]

    # keep-open=yes in mpv.conf stops mpv exiting when a stream drops, which is
    # right for radio and wrong at the end of a queue: the last track finishes
    # and mpv sits on it paused at EOF forever, so the bar goes on showing music
    # that stopped. Setting it per-file rather than globally confines the change
    # to finite tracks queued here - a film watched in the same mpv, and a radio
    # stream that blips, both keep the behaviour the config asked for.
    parts = []
    if title:
        parts.append(quoted("force-media-title", title))
    if finite:
        parts.append("keep-open=no")
    options = ",".join(parts)

    reply = mpv.command("loadfile", url, flag, 0, options)
    if reply.get("error") != "success":
        print(f"mpv refused the file: {reply.get('error')}", file=sys.stderr)
        return 1

    if title:
        remember(url, title)

    if mode == "now" and not empty:
        # The new entry is directly after the current one, which is what
        # insert-next means, so advancing is the same as playing it.
        skip = mpv.command("playlist-next", "force")
        if skip.get("error") != "success":
            print(f"queued, but could not switch to it: {skip.get('error')}",
                  file=sys.stderr)
            return 1
    return 0


def cmd_list() -> int:
    mpv = connect()
    entries = mpv.playlist()
    mapping = load_titles()

    live = {e.get("filename") for e in entries if e.get("filename")}
    pruned = {url: name for url, name in mapping.items() if url in live}
    if pruned != mapping:
        save_titles(pruned)

    for index, entry in enumerate(entries):
        filename = entry.get("filename") or ""
        title = entry.get("title") or pruned.get(filename) or filename
        current = "1" if entry.get("current") else "0"
        # Tabs separate the fields, so strip any the title happens to contain.
        print(f"{index}\t{current}\t{title.replace(chr(9), ' ')}")
    return 0


def cmd_count() -> int:
    print(len(connect().playlist()))
    return 0


def cmd_current() -> int:
    mpv = connect()
    title = mpv.get("media-title")
    if not title:
        for entry in mpv.playlist():
            if entry.get("current"):
                title = entry.get("title") or entry.get("filename")
                break
    print(title or "")
    return 0


def simple(name: str, *args) -> int:
    reply = connect().command(name, *args)
    if reply.get("error") != "success":
        print(f"mpv refused {name}: {reply.get('error')}", file=sys.stderr)
        return 1
    return 0


USAGE = """mpv_queue.py <command> [args]

  running                 exit 0 if focus-music's mpv is listening
  playing                 exit 0 if it is listening and not idle
  add <now|next|queue> <url> [title] [finite]
  list                    index, 1 if current, title - tab separated
  count
  current                 title of what is playing
  play <index>
  move <from> <to>
  remove <index>
  clear                   drop everything except what is playing
  next                    skip to the next entry
  quit
"""


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(USAGE)
        return 0

    command, args = argv[0], argv[1:]
    try:
        if command == "running":
            connect()
            return 0
        if command == "playing":
            # Running is not the same as playing: once a finite queue runs out
            # mpv stays alive and goes idle, which is nothing playing.
            mpv = connect()
            return 0 if not mpv.get("idle-active") else 1
        if command == "add":
            mode, url = args[0], args[1]
            title = args[2] if len(args) > 2 else ""
            finite = len(args) > 3 and args[3] == "finite"
            if mode not in ("now", "next", "queue"):
                print(f"unknown mode '{mode}'", file=sys.stderr)
                return 2
            return cmd_add(mode, url, title, finite)
        if command == "list":
            return cmd_list()
        if command == "count":
            return cmd_count()
        if command == "current":
            return cmd_current()
        if command == "play":
            return simple("playlist-play-index", int(args[0]))
        if command == "move":
            return simple("playlist-move", int(args[0]), int(args[1]))
        if command == "remove":
            return simple("playlist-remove", int(args[0]))
        if command == "clear":
            return simple("playlist-clear")
        if command == "next":
            return simple("playlist-next", "force")
        if command == "quit":
            return simple("quit")
    except (OSError, ConnectionError):
        # No socket, a stale one, or mpv going away mid-command. Every caller
        # treats this as "nothing of ours is playing", which is what it means.
        return 1
    except (IndexError, ValueError) as problem:
        print(f"bad arguments: {problem}", file=sys.stderr)
        return 2

    print(f"unknown command '{command}'", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
