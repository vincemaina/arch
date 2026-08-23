---
id: TASK-135
title: add spotify
status: In Progress
assignee:
  - '@claude'
created_date: '2026-08-23 09:40'
updated_date: '2026-08-23 16:29'
labels: []
dependencies: []
priority: low
type: feature
ordinal: 139000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
is there we can have spotify on this without having to keep heavy gui programs open e.g. spotify in the browser, or the spotify desktop app.

all i need is a lightweight client that lets me select my playlists and songs, as well as search for songs and playlists.

that would then integrate with the music player thing we already have at the top of the screen.

and our focus timer tool, which i believe just pauses whatevers playing, through one system, rather than having a custom implementation for each sound source.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 spotify-player is declared in setup/packages/desktop.txt and installs from the official repositories, with no AUR support added (TASK-43)
- [ ] #2 Playback runs in a daemon started on demand, in its own transient scope under app.slice, so it survives the launcher, the terminal and an unrelated unit restarting - and nothing Spotify-shaped runs until music is asked for
- [ ] #3 The daemon appears as an MPRIS player: waybar's mpris module shows the track, ~/.local/bin/media controls it, and focus-timer pauses and resumes it - with no Spotify-specific code added to any of the three
- [ ] #4 ~/.local/bin/spotify is a rofi picker that plays a playlist, a saved album or track, or the result of a search, without opening a window - and can stop playback
- [ ] #5 The full TUI opens and hides on a keybinding, and playback continues while it is hidden
- [ ] #6 Exactly one Spotify device and one MPRIS player exist when both the daemon and the TUI are running, verified against the running system rather than assumed
- [ ] #7 First-run authentication is a documented one-time step; no password, token or client secret is stored in this repository
- [ ] #8 checks/session.sh, checks/sway-commands.sh, checks/sway-bindings.sh, checks/packages.sh and checks/manual.sh all pass
- [ ] #9 The manual and DECISIONS.md record the choice of client and the daemon/controller split
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Declare spotify-player in setup/packages/desktop.txt with a comment recording why this client and not ncspot/spotifyd, and that it is in extra so TASK-43 does not bite.
2. Ship ~/.config/spotify-player/app.toml via chezmoi, themed from .chezmoidata like every other consumer. The load-bearing line is enable_streaming = DaemonOnly: only a -d instance creates a librespot device, so the TUI and any CLI-spawned helper are pure controllers and there is exactly one device.
3. Write ~/.local/bin/spotify: a rofi picker in focus-music's idiom. Starts the daemon on demand with systemd-run --user --scope --collect (the same reasoning focus-music documents for mpv), then drives spotify_player get/search/playback over the CLI. Playlists, saved albums, followed artists, liked songs, top tracks, and search.
4. Launch the TUI from the picker and from a keybinding through sway-toggle-window, with -o enable_media_control=false so the TUI never registers a second MPRIS name.
5. Bind the picker and the TUI in sway, add the rofi launcher entry, and give waybar's mpris module a spotify player-icon by codepoint.
6. Verify against the running system: one device in get key devices, one name in playerctl --list-all, the bar showing the track, media controlling it and focus-timer pausing it - none of which can be checked until the account is authenticated once.
7. Update the manual, DECISIONS.md and docs/software, and run all five checks.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented. spotify-player declared in setup/packages/desktop.txt; ~/.config/spotify-player/app.toml.tmpl carries the load-bearing enable_streaming = "DaemonOnly"; ~/.local/bin/spotify is the rofi picker and starts the daemon on demand in a NAMED transient scope (systemd-run --unit=spotify-daemon), so stopping is systemctl --user stop rather than pkill; the TUI is bound to $mod+Shift+m through sway-toggle-window with -o enable_media_control=false so it never claims a second MPRIS name. Window rules, two launcher entries and a waybar player-icon keyed on the MPRIS name spotify_player.

Verified without an account:
- Arch's build has daemon, streaming, media-control, notify and fzf compiled in (spotify_player features against the real binary, extracted from the package rather than assumed).
- dbus_name is "spotify_player" - read from media_control.rs, not guessed - so the waybar player-icons key is right.
- U+F1BC exists in JetBrainsMono Nerd Font (fc-list :charset=f1bc).
- The rendered app.toml parses: the binary accepts it and proceeds to OAuth, while enable_streaming = "Nonsense" errors with 'did not match any variant of untagged enum StreamingTypeOrBool'. So the config is verified by the real parser, not just by tomllib.
- items() and playback_now() tested against JSON in the exact shape of spotify-player's model structs, including URI-form ids, embedded tabs, missing artists, null and garbage input.

Two real bugs found by testing rather than reading: python3 - <<PY puts the SCRIPT on stdin so the piped JSON never reached json.load and every list came back empty at exit 0; and playback_now's fallback had no trailing newline, so read returned non-zero and set -e ended the whole script.

checks/session.sh 102/0, checks/sway-bindings.sh clean, checks/manual.sh 8/0. checks/sway-commands.sh and checks/packages.sh each fail on the same single cause: spotify-player is declared but not installed, which needs sudo.
<!-- SECTION:NOTES:END -->
