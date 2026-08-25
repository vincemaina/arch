# qutebrowser configuration.
#
# `config` and `c` are injected by qutebrowser when it execs this file; they
# are not imported and cannot be. An editor or type checker will report both
# as undefined, and that report is wrong rather than a thing to fix - adding
# imports to satisfy it is how a working config file gets broken.
#
# This repository shipped no qutebrowser config at all until TASK-174, and
# DECISIONS.md said so as a deliberate choice: the browser ran stock. That
# held for as long as nothing needed changing. Two things did.
#
# THE FIRST LINE IS LOAD-BEARING AND IS NOT A FORMALITY
#
# The moment this file exists, qutebrowser IGNORES autoconfig.yml entirely
# unless it is loaded back explicitly. autoconfig.yml is where qutebrowser
# writes everything set from inside the browser with `:set` - and this
# machine already had a real setting in it, granting chatgpt.com microphone
# access. Creating this file without the line below would have revoked that
# silently, with nothing to see in any diff: the exact shape of failure
# CLAUDE.md describes as this repository's characteristic bug.
#
# It is first, not last, so that anything set here wins over a value the
# browser wrote for itself.

config.load_autoconfig()

# ----------------------------------------------------------------------
# Asking for a browser gives you a browser WINDOW
# ----------------------------------------------------------------------
#
# qutebrowser's default is `tab`: with an instance already running, every
# launch - $mod+b, the launcher, `gio open`, a link from another program -
# opens a tab in the last-focused window and raises that window instead.
#
# That is a reasonable default for a browser and the wrong one here, where
# every other application answers a launch with a new instance. $mod+e opens
# a new file manager; $mod+Return opens a new terminal; $mod+b silently did
# not, and the difference was invisible because a tab appearing in a window
# somewhere else looks like nothing happening at all.
#
# Measured before changing it, because the assumption on the way in was that
# the launcher already behaved correctly and only the keybinding did not:
# with one qutebrowser open, `qutebrowser https://example.com` produced no
# window::new event on sway's IPC and left the window count at 1. So the
# launcher was never the counter-example - it had only ever been tried with
# nothing running.
#
# Setting it here rather than in the keybinding is what makes every entry
# point agree. A `--target window` on the sway binding alone would have
# fixed $mod+b and left the launcher, the default-handler and every link
# opened from another application still making tabs.
#
# This is also why ~/.local/bin/browser is gone. It existed to move the
# already-open window to the current workspace, which is the behaviour being
# reversed; with that removed it had nothing left to do that
# `qutebrowser` does not.

c.new_instance_open_target = 'window'

# ----------------------------------------------------------------------
# Closing the browser stops being destructive
# ----------------------------------------------------------------------
#
# Closing qutebrowser's LAST window quits the process, and on a clean quit
# qutebrowser deletes its own sessions/_autosave.yml - so an ordinary close
# discards every open tab with no prompt and nothing to recover from except
# history. That was demonstrated the expensive way while working on
# TASK-134: the browser was killed during a benchmark and the tabs were
# simply gone.
#
# `auto_save.session` keeps the session written so it can be restored;
# `lazy_restore` means a restored tab is not actually loaded until it is
# focused, so restoring many tabs costs one page load rather than twenty.
# The second is what stops the first being a startup-time regression on a
# browser this repository is separately trying to make start faster.

c.auto_save.session = True
c.session.lazy_restore = True
