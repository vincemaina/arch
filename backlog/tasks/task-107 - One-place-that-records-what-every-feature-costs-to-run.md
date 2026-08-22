---
id: TASK-107
title: One place that records what every feature costs to run
status: To Do
assignee: []
created_date: '2026-08-22 11:59'
updated_date: '2026-08-22 12:00'
labels: []
dependencies:
  - TASK-27
priority: low
ordinal: 115000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
docs/software/ measures what declared PACKAGES cost - disk, resident memory, CPU over a long run - and that has already settled arguments, most sharply earlyoom at 1.0 MiB and 0.004% of a core. What it does not cover is FEATURES. A feature is not a package: the focus timer is two scripts and a waybar module, the wallpaper library is a helper plus a cache directory, the visualiser is cava inside a terminal whose redraw costs more than cava does. Asking "what does this cost" of a feature currently means measuring it again from scratch, and most of the time nobody does.

The setup targets a small idle footprint on a 3.9 GiB machine, so cost is a real constraint rather than trivia, and a figure that exists only in a closed ticket is a figure nobody will find. There should be one place that answers, for anything the desktop offers: what it costs in CPU, in memory, and on disk - measured on this machine, with the method recorded so it can be re-run rather than trusted.

Two things learned while measuring the visualiser for TASK-103, both of which this record needs to avoid repeating:

Measure the whole feature, not the process you happen to be thinking of. cava alone is 1.27% of a core; the foot window drawing it is another 2.00%, and on a software-rendered desktop the compositor pays again on top. Quoting only cava would understate it by more than half.

Measure it doing its job. A first attempt with no audio playing reported the terminal at 0.00%, because with silence the bars do not change and nothing redraws. The number was real and completely misleading. The fix was to drive cava from a synthetic PCM stream so the bars moved every frame, which also avoided taking over the machine audio.

Low priority. Nothing is blocked on it; it is worth doing once and then keeping current.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 One document answers what any feature of this desktop costs in CPU, memory and disk
- [ ] #2 Every figure is measured on this machine, dated, and records the machine it came from
- [ ] #3 The method for each measurement is written down well enough to be re-run and get a comparable number
- [ ] #4 A feature is measured as a whole rather than as its most obvious process, and while it is doing its job rather than idle
- [ ] #5 A new feature has an obvious place and format to add its figures to
<!-- AC:END -->
