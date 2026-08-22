---
name: sway-capability-limits
description: The things sway genuinely cannot do — blur, shadows, rounded corners, animations, an overview or expose, focus-based window opacity, XWayland HiDPI, and workspaces spanning displays — with the evidence that settled each. Load this before answering "can sway do X" or proposing a visual effect, so the answer is not rediscovered a fourth time.
---

# What sway cannot do

Every item here was established with evidence, not inferred from a failed
attempt. If a request touches one of them, the answer is a compositor decision
rather than a configuration change.

## Effects: blur, shadows, rounding, animations

`shadow`, `glow`, `blur`, `dim` and `corner_radius` appear **zero times** in
`sway(5)`. There are no animations either. Sway draws flat rectangles with
solid borders, deliberately — that is the wlroots philosophy rather than an
oversight, and no setting turns it on.

Blur in particular is not an application's decision. It is a compositor
capability, offered through the `ext-background-effect-v1` protocol.
`strings /usr/bin/sway` and the wlroots library contain **zero** references to
it, while a protocol sway does implement (`wlr_layer_shell`) matches — so the
control is valid and the answer is a real absence.

The consequence catches people out: foot has a `blur=yes` option and rofi
themes accept blur properties, and **both are inert here**. They are accepted
silently and do nothing, which looks exactly like a configuration mistake.
Three separate requests in one session — foot, sway borders, rofi — all hit
this same wall.

## XWayland does not do HiDPI

`sway-output(5)` states it outright: *"HiDPI isn't supported with Xwayland
clients (windows will blur)."*

Measured rather than assumed: the same GTK application launched twice onto a
headless output at scale 2, once natively and once through XWayland. The
XWayland one rendered at half resolution and was upscaled, with visibly softer
text. It also picked up **different icons**, which is a separate problem
tracked as TASK-42.

## Workspaces belong to one output

`workspace <name> output A B` is a **failover priority list**, not spanning.
`sway(5)`: *"the first available will be used."* Web sources claim it spans
displays; they are wrong, and building on that claim wastes a cycle.

A workspace lives on exactly one output. Switching to a workspace that lives
elsewhere moves **focus to that output** rather than bringing the workspace to
you. TASK-34 settled this: keep sway's model rather than scripting around it.

## There is no overview

Sway has no expose or overview of any kind. The community tools that provide
one — `sov`, `swayr` — are AUR-only, and this repository has no AUR support at
all (TASK-43).

## Colour fields that do nothing

`client.<class>` takes `border | background | text | indicator | child_border`.
With `default_border pixel N` there are no title bars, so **`border`,
`background` and `text` are inert** — they style a title bar that does not
exist. Only `child_border` (the frame you can see) and `indicator` have any
effect.

Verified by setting each field to a different colour and looking at the result:
the frame came out in the `child_border` colour and the others appeared
nowhere.

**This is conditional, not absolute.** It holds while a window has no title
bar, which is the case throughout this setup. Give any window `border normal`
and all five fields become live on it: the title bar is drawn with
`background` behind `text`, framed by `border`. So the three "dead" fields are
dead per-window, not per-config — worth knowing before concluding a colour
setting does nothing.

## Title bars have no buttons

`sway(5)` documents everything a title bar can carry — `title_format` (a
template of `%title`/`%app_id`/`%class`/etc.), `title_align`,
`titlebar_padding`, `titlebar_border_thickness`, `hide_edge_borders`, and the
`font` used to render it — and every one of them controls text: what it says,
where it sits, how much space is around it. `close_button`, `minimize`,
`maximize` and `titlebar_buttons` appear **zero times** in the man page, and
there is no per-window command (`bindsym --border`, `for_window`, etc.) that
attaches a clickable icon to the decoration. A sway title bar is a text label
in a coloured rectangle, nothing else — confirmed visually: a `foot` window
given `border normal` (sway's own server-side decoration) on a headless
output renders exactly that, no icons and no clickable region beyond
drag-to-move.

The one door left open is `border csd`, which hands decoration drawing to the
*client* instead of sway. A GTK app implementing its own header bar can put
close/minimize buttons there — but that is the application's decision, not a
sway setting, and it only ever applies to windows that opt into `csd`. This
repository's borders are `default_border pixel 3` (see `30-appearance.conf.tmpl`),
which has no title bar at all, so the question is moot here regardless of
which door is asked about. TASK-57.

## Resize target = border width

The border is not only decoration. It is the area the pointer has to hit to
resize a window, and sway has **no separate threshold setting** for it.
`tiling_drag_threshold` concerns dragging a container by its titlebar and is
explicitly inert when `floating_mod` is set, which it is here.

Widening `default_border` is the only lever. `$mod` + right-drag resizes from
anywhere inside a window and needs no aiming at all.

## Where the effects actually live

**SwayFX** has the shadows, blur and rounded corners, and is AUR-only, so it
depends on TASK-43 — which ruled the AUR out. `pacman -Si swayfx` confirms it is
not packaged. That is closed.

**niri** is the one to know about, and an earlier version of this section was
wrong about it. It is in `extra` — 24.87 MiB, with `xwayland-satellite` beside it
and waybar's `niri/*` modules already in the installed waybar — and it has
shadows, rounded corners, blur *and* animations, along with a first-class
overview and scrollable tiling. So **the effects were never AUR-only; they were
only ever absent from sway.** What niri does not solve is spanning: its
workspaces are per-monitor too.

**COSMIC** is the only option found that offers spanning workspaces natively.

All three are compositor changes, which means TASK-31 — which decided to stay on
sway and revisit niri when this runs on real hardware, because niri's
differentiator is a motion model and a VM cannot judge it. See DECISIONS.md,
"Sway stays, and niri is the thing to try when there is hardware to try it on",
which also counts what a move would cost: 609 lines of config, 69 bindings, nine
IPC helpers and six pieces of repo tooling, none of which port.

A request for blur, shadows, rounding, an overview or spanning workspaces is a
TASK-31 conversation, not a configuration change.
