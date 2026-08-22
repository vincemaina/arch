---
id: TASK-31
title: 'Decide whether to move from sway to SwayFX, or elsewhere'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-20 12:52'
updated_date: '2026-08-22 00:59'
labels:
  - desktop
  - foundation
dependencies: []
references:
  - 'https://github.com/WillPower3309/swayfx'
priority: medium
type: spike
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Rounded window corners, blur and shadows keep coming up while shaping the look, and baseline sway supports none of them. It has no compositing effects at all by design. Two rounding attempts have already been shelved for this reason.

SwayFX is a fork of sway that adds exactly those effects and is otherwise a drop-in replacement, so the existing configuration would largely carry over. It is AUR-only, which is the real cost: this repository installs everything from official packages, and building from the AUR means either an AUR helper or manual makepkg, unreviewed PKGBUILDs, and a package that tracks upstream sway releases and can therefore lag on a rolling distribution.

Hyprland is the other direction people go for the same reasons. It is in the official repositories, has effects built in, and is actively developed - but it is a different compositor with its own configuration language, so the sway config, the keybinding scheme and the session wiring would all need rewriting rather than porting.

The decision should be made on evidence rather than screenshots. Effects cost GPU work and memory, and this setup idles at 550-650 MiB and is meant to never drop a frame. That matters more here than on a machine with a dedicated GPU, and TASK-26 has not yet established whether there is hardware acceleration at all.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Idle memory and CPU measured on the same hardware for each option considered, not quoted from elsewhere
- [ ] #2 Frame timing under normal use compared, since never dropping a frame is the stated goal
- [x] #3 The maintenance cost of each is assessed honestly, including what happens when upstream sway releases and the fork has not caught up
- [x] #4 How much of the existing configuration survives each option is established rather than assumed
- [x] #5 A decision is recorded in DECISIONS.md, including the case for staying on plain sway
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Establish what is actually on the table: confirm swayfx is absent from the official repos and niri is present, with versions and sizes, from pacman rather than from memory.
2. Establish niri's model and what it offers that sway cannot - effects, overview, scrollable tiling - and whether waybar and XWayland support exist as packaged.
3. Enumerate the sway investment in this repository by counting it, not estimating it: config lines, bindsyms, window rules, helper scripts that speak sway IPC, checks and tools that parse sway config syntax, and session units bound to wayland-session@sway.target.
4. Establish what installing niri alongside would actually cost, including whether checks/session.sh would still pass.
5. Verify the rendering premise the decision rests on against the running system rather than against DECISIONS.md.
6. Recommend, and name the specific falsifiable condition that should reopen this.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fed in from TASK-34, which decided to keep sway workspace model rather than script around it, and referred the compositor question here.

Two requirements have now been stated concretely enough to judge a compositor against, and they pull in different directions:

Workspaces that span every display, so one workspace holds a task across both screens. sway cannot do this and the difference is structural, demonstrated on two outputs rather than reasoned about.

An overview: a way to see all workspaces at once and drag or reorder them. sway has no exposé of any kind, and the community tools for it - sov, swayr - are not in the official repositories, which matters because this repository has no AUR support.

The overview requirement is the harder constraint. Spanning can be approximated with a script; an overview cannot be built at all.

How the candidates answer them. niri: per-monitor workspaces, so no spanning, but a first-class overview with keyboard and pointer navigation, window relocation and workspace reordering - the best keyboard-driven tiling of the three. COSMIC: the only one offering spanning natively, as an explicit setting, plus an overview and per-workspace tiling, at the cost of less mature tiling. Hyprland: per-monitor, overview through plugins, which is a maintenance surface.

The decision this reduces to: whether spanning workspaces or the quality of tiling and overview matters more. They cannot both be maximised. Note that with one display today, the spanning question is unfalsifiable in daily use, which argues for judging on tiling and overview now and revisiting spanning when a second screen exists.

Sources are recorded in the DECISIONS.md entry "Workspaces stay per-output, as sway does them".

Two inputs from the TASK-43 discussion, both narrowing this considerably.

swayfx is not wanted. It buys shadows, blur and rounded corners - the effects
sway genuinely cannot do - at the cost of GPU work, and the judgement was that
vanilla sway already looks right after the theming work. So the
sway-with-effects option is off the table, and with it the main reason this
repository would have needed the AUR.

niri is worth exploring, but for the workflow rather than the appearance, and
not urgently. It is in extra at 24.87 MiB, so unlike swayfx it costs no
packaging machinery at all - it could be installed alongside and tried from the
greeter's session list without disturbing the sway setup.

That reframes this ticket: it is no longer "sway, SwayFX or elsewhere" but
"stay with sway, or try niri's scrollable-tiling workflow at some point".

## Spike outcome (2026-08-22): stay on sway. Do not migrate, and do not install niri yet.

### What is actually on the table

`pacman -Si swayfx` -> "package 'swayfx' was not found". Confirmed AUR-only, and TASK-43 ruled out the AUR. The user has separately said they are not fussed about swayfx: vanilla sway looks right after the theming work. So the sway-with-effects branch of this ticket is closed on two independent grounds.

`pacman -Si niri` -> extra, 26.04-1, 6.37 MiB download / 24.87 MiB installed, packaged by an Arch maintainer (Caleb Maclennan), built 2026-04-25. Depends only on things already installed here. `xwayland-satellite` 0.8.2 is also in extra, and the installed waybar 0.15.0 already carries `niri/workspaces`, `niri/window`, `niri/language` (checked with `strings /usr/bin/waybar`). So niri costs no packaging machinery at all - that part of the ticket's framing is confirmed.

### Correction: the effects are no longer AUR-only, they are just not in sway

The sway-capability-limits skill says SwayFX is where the effects live and it is AUR-only. That is now out of date. niri has shadows (`shadow` layout block), rounded corners (`geometry-corner-radius` window rule), background blur for windows and layer-shell surfaces, animations with custom shaders, and gradient borders - all from extra. The question is therefore no longer "effects or the AUR", it is "effects or sway".

That does not change the recommendation, because the user has said the effects are not what they want. It changes the reason the answer is no.

### Correction: this machine is no longer rendering in software

DECISIONS.md "The VM renders in software, and that is the hypervisor's doing" is stale. TASK-26's implementation notes record that 3D was enabled on the hypervisor, and the running system agrees: this boot's kernel log says `[drm] features: +virgl +edid` and `number of cap sets: 2`, and the user journal contains zero `llvmpipe`/`swrast` lines across 4986 lines. `checks/session.sh` would now take the accelerated path.

**The conclusion that entry draws still holds, for a different reason.** virgl is virtualised GL through virglrenderer, not a native GPU. It is good enough that sway is not CPU-drawn any more; it is not a fair bench for an animation-heavy compositor. No claim about how niri feels is made from this machine, and none should be.

### What a move would cost, counted rather than estimated

Compositor config: 609 lines across `dot_config/sway/config` and 9 `config.d/*.conf` files. 69 `bindsym` lines (51 keybindings, 11 media keys, 7 in modes) and 19 `for_window`/`assign` rules. None of it ports - niri uses KDL and there is no translator; upstream says so explicitly.

Helper scripts that speak sway IPC, all needing rewrite against `niri msg`: `git-ui`, `shortcuts`, `sway-idle`, `sway-toggle-bar`, `sway-toggle-floating`, `sway-toggle-window`, `sway-workspace-greeter`, `terminal`, plus `run_onchange_after_reload-theme.sh.tmpl`.

Repository tooling that parses sway's config syntax or IPC and would have to be rewritten or abandoned: `checks/sway-commands.sh` (168 lines), `checks/sway-bindings.sh` (139), `checks/session.sh` (1715, 4 swaymsg calls), `tools/shortcuts.sh` (147), `tools/performance.sh` (439, 6 swaymsg), `tools/session-inventory.sh` (625, 3 swaymsg).

The shortcuts panel is the single biggest item: 678 lines that read `~/.config/sway/config` and `config.d/*.conf` directly, parse `bindsym` lines with a regex, expand `set $var`, and subscribe to sway's window events to redraw on focus change. Every one of those four mechanisms is sway-specific.

Four things do not port at all, because niri has no equivalent:
- `autotiling` (a declared package and a systemd user unit) picks a split direction. Scrollable tiling has no splits, so the concept disappears.
- Binding modes. `51-modes.conf` and waybar's `sway/mode` module have no niri counterpart.
- The scratchpad. waybar's `sway/scratchpad` module has no niri counterpart.
- `sway-workspace-greeter` assumes numbered, static workspaces; niri's are dynamic and vertical.

Session wiring: six user units bound to `wayland-session@sway.target` via committed symlinks, plus the `sway.desktop`/`sway-uwsm.desktop` masking pair and its entry in `apply-config.sh`. All would need a niri twin.

What survives untouched: everything below or beside the compositor - keyd (evdev layer), greetd/regreet, uwsm, chezmoi, the themes.toml palette and every non-sway consumer of it (foot, rofi, mako, waybar styling, swaylock, starship, nvim), zsh, the installer stages, the package manifests.

### "Just install it alongside and try it from the greeter" is not free

Worth writing down because it is the obvious suggestion and it is wrong as stated. `checks/session.sh` walks every `.desktop` in the greeter's session directories and **fails** any whose `Exec` does not contain `uwsm`: "offers ... which bypasses uwsm and yields a session with no components". Installing niri drops a packaged session entry into `/usr/share/wayland-sessions/`, so the check would start failing on the next run.

Trying niri properly therefore costs, at minimum: a `Hidden=true` masking entry for the packaged one, a `niri-uwsm.desktop` written the same careful way `sway-uwsm.desktop` was (naming the binary, not the desktop ID - that mistake locked a machine out once), an entry in `apply-config.sh`, and a `wayland-session@niri.target.wants/` set for whichever session components should come up. That is a small ticket, not a `pacman -S`.

### Recommendation

Stay on sway. The one thing the user said they wanted from a compositor change - the scrollable-tiling workflow - is a workflow preference that cannot be evaluated from a config diff, and everything else niri offers is either something they have said they do not want (effects) or something that cannot be judged on this machine (feel).

### The condition that should reopen this

**Revisit when this setup runs on real hardware rather than in the VM.**

That is the X, and it is chosen because it is the first moment the question becomes answerable rather than because it is a convenient postponement. Three things change at once on real hardware and not before:

1. How a compositor feels can be judged. niri's whole differentiator is a motion model - scrolling, animations, an overview that zooms out. Judging that through virglrenderer is the exact mistake DECISIONS.md already warns against, and the warning survives the correction above.
2. niri's effects start costing something measurable, so AC#1 and AC#2 become answerable on comparable hardware instead of quotable from elsewhere.
3. `checks/session.sh` will report on real hardware whether acceleration is genuinely present, which TASK-26 deliberately left as the open half of its AC#2.

A second display is deliberately **not** the trigger. TASK-34 established that spanning workspaces is the thing sway cannot do, and niri does not offer spanning either - its workspaces are per-monitor by design. A second screen is an argument for reopening the spanning question (COSMIC), not for niri.

The effects are not the trigger either, for the reason recorded above: they are available now, from extra, and the user has said they are not what they want.

### Acceptance criteria status

AC#3 and AC#4 are checked: both were established from `pacman` output and from counting this repository, not from assumption.

AC#1 (idle memory and CPU measured per option on the same hardware) and AC#2 (frame timing compared) are left **unchecked deliberately**, the same way TASK-26 left its AC#2. They cannot be established here: measuring niri on a virgl-backed VM would produce a number that is real and means nothing, and this ticket's own framing says the decision should be made on evidence rather than screenshots. Checking them from a VM measurement would be worse than leaving them open.

AC#5 (a decision recorded in DECISIONS.md) is not done - the DECISIONS.md text was handed back rather than written, because this session was scoped to backlog only.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @claude
created: 2026-08-22 00:56
---
Recommendation is to stay on sway and not install niri yet. Left In Progress rather than Done: AC#1, AC#2 and AC#5 are genuinely not met - the first two cannot be met from this VM, and AC#5 needs a DECISIONS.md entry that this session was not allowed to write.

Two things found along the way that belong outside this ticket and need your call:
- DECISIONS.md "The VM renders in software" is factually stale; this boot reports +virgl with 2 cap sets and zero llvmpipe lines. Its conclusion still holds but its evidence block does not.
- The sway-capability-limits skill says the effects live in SwayFX and are AUR-only. niri has shadows, rounded corners, blur and animations, from extra. Worth correcting so the next session does not conclude the effects are unreachable.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Stay on sway. SwayFX is closed twice over - not packaged outside the AUR, which TASK-43 ruled out, and the effects it sells are not wanted after the theming work. niri is the real candidate and is cheap to obtain from extra, but what it is wanted for is a motion model that cannot be judged from a config diff or on this machine, so the trigger to revisit is real hardware rather than a second display. A move would cost 609 lines of config, 69 bindings, 19 window rules, nine IPC helpers and six pieces of repository tooling, with autotiling, binding modes, the scratchpad and the workspace greeter having no niri equivalent at all. Two stale claims corrected on the way: DECISIONS.md still said this VM renders in software when the kernel now reports +virgl and the journal has zero llvmpipe lines, and the capability-limits skill said the effects were AUR-only when niri has them from extra.
<!-- SECTION:FINAL_SUMMARY:END -->
