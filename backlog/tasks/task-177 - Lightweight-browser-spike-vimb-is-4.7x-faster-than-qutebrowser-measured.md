---
id: TASK-177
title: 'Lightweight browser spike: vimb is 4.7x faster than qutebrowser, measured'
status: To Do
assignee: []
created_date: '2026-08-25 17:51'
labels: []
dependencies: []
priority: medium
type: spike
ordinal: 184000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-91 chose the *heavy* browser (firefox) and never questioned whether qutebrowser is the right *light* one - it recorded 'deliberately without an extensive measurement exercise'. This is that measurement, prompted by the browser not feeling as lightweight as wanted.

Cold start, exec to window mapped on sway's IPC event stream, best of 3, power profile 'balanced' (this matters - see TASK-175, power-saver clocks the CPU to 800MHz and multiplies every figure by ~3):

    foot           135 ms    1.0x   (the target: a terminal)
    vimb           354 ms    2.6x   webkit2gtk-4.1
    netsurf        432 ms    3.2x   own engine
    epiphany       843 ms    6.2x   webkitgtk-6.0
    qutebrowser   1673 ms   12.4x   qt6-webengine

Engine sizes: webkit2gtk-4.1 133 MiB, webkitgtk-6.0 131 MiB, qt6-webengine 282 MiB.

THE USEFUL RESULT is not the ranking, it is the floor. vimb is 193 KiB of browser on top of WebKitGTK, so its 354 ms IS the engine - no WebKitGTK browser can start faster than that. epiphany's extra ~490 ms is its own GTK4/libadwaita UI, not the engine. So the choice is genuinely 'engine only' vs 'engine plus a real UI', and there is nothing in between to look for.

qutebrowser's 1673 ms is therefore about 1.3 s of QtWebEngine over the WebKit floor.

Rendering was checked, not assumed: vimb renders en.wikipedia.org/wiki/Arch_Linux correctly - full layout, images, infobox - with no chrome at all beyond a one-line status bar. Screenshot taken and read.

Two measurement traps worth recording:
  - epiphany is a single-instance GApplication, so naive repeat runs reuse a
    live process and report a warm number as cold. First run 1789 ms, later
    runs 813 ms. Re-measured with a fresh --profile per run: 843/872/1082 ms.
  - qutebrowser measures ~1050 ms with its 203 MiB library already in page
    cache and ~1670 ms cold from disk. Both are real; which one you get
    depends on what else has run.

NOT ANSWERED HERE: whether WebKitGTK is good enough for daily use. It renders
most sites but is known to struggle with cutting-edge JavaScript where
QtWebEngine is Chrome-equivalent. That is a live-with-it question, not a
benchmark question, and it is the actual decision.

vimb, epiphany and netsurf are installed but declared nowhere, so
checks/packages.sh reports drift until they are either declared in
setup/packages/desktop.txt or removed.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A browser is chosen, or qutebrowser is deliberately kept, with the reason recorded in DECISIONS.md
- [ ] #2 Package drift is resolved: the trial browsers are declared or removed, and checks/packages.sh is no worse than before this spike
- [ ] #3 If the everyday browser changes, xdg-mime default handlers and the $mod+b binding follow it, verified by opening a link
- [ ] #4 WebKitGTK rendering has been lived with on real sites, not just benchmarked
<!-- AC:END -->
