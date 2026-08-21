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

## Resize target = border width

The border is not only decoration. It is the area the pointer has to hit to
resize a window, and sway has **no separate threshold setting** for it.
`tiling_drag_threshold` concerns dragging a container by its titlebar and is
explicitly inert when `floating_mod` is set, which it is here.

Widening `default_border` is the only lever. `$mod` + right-drag resizes from
anywhere inside a window and needs no aiming at all.

## Where the effects actually live

**SwayFX** has the shadows, blur and rounded corners, and is AUR-only — so it
depends on TASK-43. **niri** has a first-class overview but per-monitor
workspaces, so it does not solve spanning. **COSMIC** is the only option found
that offers spanning workspaces natively.

All three are compositor changes, which means TASK-31 — a ticket that is now
load-bearing for several others.

A request for blur, shadows, rounding, an overview or spanning workspaces is a
TASK-31 conversation, not a configuration change.
