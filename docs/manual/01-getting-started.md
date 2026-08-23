# Getting started

This machine runs Arch Linux with Sway, a tiling Wayland compositor. There is
no desktop shell underneath it and no window manager in the traditional sense
either: Sway arranges every window itself, almost everything you do has a key
combination, and the whole configuration - packages, system settings and your
own dotfiles - lives in a git repository and can rebuild the machine from
nothing. This manual assumes none of that is familiar yet.

This chapter covers what happens between pressing the power button and having
a usable session, and what to do in the first five minutes once you are in
one. It does not explain why any of this was chosen that way - that is
[DECISIONS.md](../../DECISIONS.md) - or how the repository builds a machine in
the first place - that is [CLAUDE.md](../../CLAUDE.md). This is the manual for
using the result.

## From power button to desktop

Every stage below is a real, separately-running piece of software, and you can
ask each one whether it did its job rather than take this chapter's word for
it.

1. **systemd-boot** loads the kernel. It is the only bootloader configured
   here - see the boot entries under `setup/system/loader/` in the
   repository if you want to see what it hands the kernel.
2. **greetd**, running **ReGreet** as the login screen, asks for your
   username and password, and which session to start - Sway is the default,
   and the only other one is **Virtual machine**, which skips this whole list
   and boots straight into a guest instead. See
   [Applications](04-applications.md) → "Virtual machines" for what that is.
   Log in with Sway selected and it starts the graphical session described
   below.
3. **uwsm** launches Sway as `uwsm start -N Sway -D sway -- sway`. uwsm
   wraps the compositor in systemd units rather than running it as a bare
   process, which is what makes the next step possible.
4. **Sway** starts and, because it was launched through uwsm, reaches
   `wayland-session@sway.target`. That target pulls in a set of systemd user
   units: **Waybar** (the bar), **mako** (notifications), **swayidle** (idle
   and lock handling), a **polkit agent** (authentication prompts) and
   **autotiling** (automatic split direction). None of these are started from
   Sway's own config with `exec` - they are units, which is why they get
   restarted if they crash and shut down cleanly when the session ends.

You can verify every one of these on a running machine rather than trust this
description:

```bash
systemctl --user status waybar.service mako.service swayidle.service \
    polkit-agent.service autotiling.service
swaymsg -t get_version
```

If the session will not start at all, `Ctrl+Alt+F2` reaches a plain text
console - the graphical login only occupies the first virtual terminal. Both
halves of that chord are swapped by keyd before anything else sees them (see
[The keyboard](03-the-keyboard.md)), which is exactly why the swap is
done at that level rather than in Sway alone: the console has to agree with
everything else, including when everything else has failed to start.

## Your first five minutes

Mod4 is the Super/Windows key, and Sway's config calls it `$mod`. Every
binding below uses it. The full reference, generated from the actual
configuration rather than typed out here, is
[The keyboard](03-the-keyboard.md).

- **Open a terminal.** `$mod+Return`.
- **Open the launcher.** `$mod+space` opens a single prompt (rofi in combi
  mode) that searches installed applications, open windows, files and does
  arithmetic, all from the same box. Most things on this desktop that are not
  windows you manage are reached this way rather than through a dedicated
  key.
- **Switch a workspace.** `$mod+1` through `$mod+9`, and `$mod+0` for the
  tenth. Chapter 2 covers what a workspace is and how many exist.
- **Close a window.** `$mod+q`. It closes immediately - there is no
  confirmation, and holding the key does not repeat the action, so a
  fractionally long press does not take the whole workspace with it.
- **Find the shortcut list.** `$mod+Shift+slash` opens a shortcut panel that
  follows whatever window is focused, showing that program's keys rather
  than every key on the system at once. It is also reachable from the
  launcher by typing "shortcuts".
- **Change the theme.** Type "theme" into the launcher, or run `theme` in a
  terminal. Running it with no arguments opens a picker; `theme --list`
  shows what is available and `theme --current` shows what is selected. The
  whole desktop - borders, bar, terminal, launcher, notifications, lock
  screen, prompt and wallpaper - moves together. Changing a theme is a
  machine-local choice, not something this repository's git history records;
  see the theming section of [CLAUDE.md](../../CLAUDE.md) for why.

None of this is everything the desktop does. It is enough that you are not
stranded. Chapter 2 covers the window model and the bar in full, and Chapter
3 is the complete keyboard reference.
