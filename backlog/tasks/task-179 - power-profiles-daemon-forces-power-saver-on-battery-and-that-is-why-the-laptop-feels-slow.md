---
id: TASK-179
title: >-
  power-profiles-daemon forces power-saver on battery, and that is why the
  laptop feels slow
status: To Do
assignee: []
created_date: '2026-08-25 18:19'
labels: []
dependencies: []
priority: high
type: bug
ordinal: 186000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The machine runs at 800MHz instead of 3400MHz - 23% of clock - whenever it is on battery, and nothing in this repository chose that.

Cause found in /var/lib/power-profiles-daemon/state.ini:

    [State]
    battery_aware=true
    Profile=power-saver

battery_aware makes power-profiles-daemon switch to power-saver automatically
on battery and switch back on AC. So 'powerprofilesctl set balanced' works and
is silently undone - observed twice in one session, which is what led to
looking for a cause rather than assuming a stray command.

WHAT IT COSTS, measured on this machine, same harness, same session:

                    power-saver   balanced   ratio
    foot                 126 ms     48 ms     2.6x
    zsh -i             1104 ms     243 ms     4.5x
    qutebrowser cold   3161 ms    1057 ms     3.0x
    qutebrowser warm   2093 ms     678 ms     3.1x

This is the single largest performance factor on the machine, larger than any
software change considered alongside it, and it explains the original report
that 'everything is starting to feel a bit slower' on the laptop where it did
not on a desktop - a desktop is never on battery, so battery_aware never fires.

It also makes checks/session.sh fail: the interactive-shell check reports
around 1000ms against a 400ms threshold, purely because of the clock. At full
speed the same shell is 243ms and passes. So this check is currently a
thermometer for the power profile rather than for the shell - worth knowing
before TASK-175 optimises compinit against a moving baseline.

The toggle is 'powerprofilesctl configure-battery-aware --disable'.

WHAT TO DECIDE, and it is a genuine trade rather than a bug to squash:
  - Leave it on: the laptop is slow on battery, always, and quietly.
  - Turn it off: full speed on battery, at whatever the runtime cost is -
    unmeasured, and worth measuring before choosing.
  - Something in between: keep it on, but bind a quick way to override, since
    ~/.local/bin/power-profile and the bar's battery icon already exist.

Whichever is chosen, this repository should set it rather than inherit
whatever the daemon defaults to, or a rebuilt machine gets it by accident -
which is how it arrived. setup/system/apply-config.sh is the one place
machine-wide configuration belongs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The battery_aware setting is chosen deliberately and the reasoning recorded in DECISIONS.md
- [ ] #2 Whatever is chosen is applied by setup/system/apply-config.sh, so a rebuilt machine gets it rather than inheriting the daemon default
- [ ] #3 If battery-aware is disabled, the battery cost is measured rather than assumed
- [ ] #4 checks/session.sh either accounts for the power profile when timing the shell, or says which profile its threshold assumes
<!-- AC:END -->
