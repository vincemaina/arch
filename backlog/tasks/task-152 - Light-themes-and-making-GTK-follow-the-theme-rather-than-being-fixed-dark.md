---
id: TASK-152
title: 'Light themes, and making GTK follow the theme rather than being fixed dark'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-23 15:45'
updated_date: '2026-08-23 16:10'
labels: []
dependencies: []
ordinal: 159000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The user asked for light themes, including one that reads like e-ink - mostly black and white.

Every theme in .chezmoidata/themes.toml is currently required to be dark, and that rule is written down in three places (CLAUDE.md, DECISIONS.md 'Switchable themes', themes.toml's own header). The stated reason is that GTK applications read GTK_THEME=Adwaita:dark once at session start, so a light desktop would leave every GTK dialog dark and looking like a different computer. DECISIONS.md records 'let a theme carry GTK too' as an alternative rejected for now, on the grounds that environment.d is only read when the user manager starts, so GTK would catch up only after a re-login.

That reasoning was checked against the running system and is incomplete. GTK_THEME is not the only lever: gtk-3.0/settings.ini is read by each GTK process at startup. Launching pavucontrol with GTK_THEME unset and a settings.ini naming Adwaita rendered it fully light immediately, with no re-login. So the boundary is not 'needs a re-login', it is the same boundary foot already has and this repository already documents: new processes follow, ones already running do not.

The GTK surface is also much smaller than the rule implies. Of the declared packages that pull in GTK, waybar and greetd-regreet are styled by this repository's own templates and never read Adwaita, which leaves three real surfaces: the polkit authentication dialog, pavucontrol, and the xdg-desktop-portal-gtk file chooser. Two of those three are drawn by long-running user units (polkit-agent.service, xdg-desktop-portal-gtk.service) which can simply be restarted by the existing theme-reload script, the way waybar already is. pavucontrol is launched fresh each time and needs nothing.

So a theme can declare whether it is light or dark, GTK can follow it, and the rule can be replaced rather than merely broken.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Every theme in themes.toml declares whether it is light or dark, and the existing eight are unchanged in appearance
- [x] #2 At least two light themes exist, one of which reads as e-ink: near-black on near-white, no hue in the chrome, colour reserved for the semantic four
- [x] #3 Every light theme meets the same contrast floors checks/session.sh already enforces, which are ratio-based and need no relaxing
- [x] #4 GTK applications follow the selected theme's mode: gtk-3.0 and gtk-4.0 settings.ini are templated, and GTK_THEME no longer pins Adwaita:dark in environment.d
- [x] #5 Switching to a light theme changes the polkit dialog and the file chooser without a re-login, because the theme-reload script restarts polkit-agent.service and xdg-desktop-portal-gtk.service
- [x] #6 neovim's background is 'light' under a light theme rather than hardcoded 'dark', and foot's initial-color-theme matches the mode
- [x] #7 The wallpaper generator produces a light wallpaper for a light theme without a special case
- [x] #8 checks/session.sh passes, and gains a check that a theme's declared mode agrees with its actual background luminance
- [x] #9 The dark-only rule is replaced, not silently contradicted, in CLAUDE.md, DECISIONS.md, themes.toml's header and docs/manual
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Give every theme a `mode` key ('dark' or 'light'). The eight existing themes get mode = "dark" and no other change, so nothing about them moves.

2. Add three light themes, mirroring the range the dark set already has (mono / cobalt / ember):
   - paper: the e-ink one the user asked for. Near-black on near-white, no hue anywhere in the chrome, colour reserved strictly for ok/warning/urgent/info. The greyscale counterpart to mono.
   - daylight: a conventional light theme, indigo accent on white.
   - sepia: warm, cream rather than white, for a light theme that is not glaring.

3. Make GTK follow the mode instead of being pinned dark:
   - Template dot_config/gtk-3.0/settings.ini and gtk-4.0/settings.ini on the mode, switching gtk-theme-name between Adwaita-dark and Adwaita, the icon theme between Papirus-Dark and Papirus, and gtk-application-prefer-dark-theme between 1 and 0.
   - Remove GTK_THEME=Adwaita:dark from environment.d/10-appearance.conf. It is the one thing that would override settings.ini and freeze the choice at session start; verified by launching pavucontrol with it unset and a light settings.ini, which rendered light immediately.

4. Make the switch take effect without a re-login, in run_onchange_after_reload-theme.sh.tmpl. Of the three GTK surfaces, pavucontrol is launched fresh and needs nothing; the polkit dialog and the file chooser are drawn by long-running user units, so restart polkit-agent.service and xdg-desktop-portal-gtk.service alongside the waybar restart that is already there. Guard both on is-active, and warn rather than fail, matching the existing style.

5. The remaining places that hardcode darkness:
   - nvim colors/arch.lua.tmpl sets vim.o.background = 'dark' literally; template it.
   - foot.ini.tmpl writes [colors-dark] with initial-color-theme=dark; render the section and the setting from the mode so foot's own idea of light/dark agrees with the palette in it.
   - waybar style.css.tmpl has one literal rgba(0, 0, 0, 0.9) drop shadow; make it palette-relative so it does not sit as a hard black blob on a light desktop.

6. checks/session.sh gains one rule: a theme's declared mode must agree with the measured luminance of its bg, so a light palette labelled dark (or the reverse) fails before it is selected. The existing contrast floors need no change - they sort the two luminances, so they are direction-agnostic already.

7. Replace the dark-only rule rather than contradict it, in CLAUDE.md, DECISIONS.md (the 'Switchable themes' decision and its rejected alternative, which is the specific text now shown to be wrong), themes.toml's header, and docs/manual chapters 5 and 8.

8. Verify: render every theme to a scratch destination with --exclude=scripts to prove the templates resolve, apply paper on the live machine and screenshot the desktop and a GTK dialog, then run checks/session.sh and checks/packages.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
IMPLEMENTED

themes.toml gains `mode` on every theme. The eight existing ones declare "dark" and nothing else about them changed - proved by rendering the whole tree from HEAD and from the working copy and diffing with comments stripped: across all eight, the only effective difference is GTK_THEME=Adwaita:dark disappearing from environment.d, which is the intended mechanism change. They still resolve to Adwaita-dark, now through settings.ini.

Three light themes added: paper (e-ink, greyscale chrome, colour only for the semantic four), daylight (indigo on white) and sepia (rust on cream). All three were designed against the contrast floors numerically rather than by eye; the tightest value in the set is sepia's warning at 4.82:1.

GTK now follows the mode. gtk-3.0 and gtk-4.0 settings.ini are templates switching Adwaita/Adwaita-dark, Papirus/Papirus-Dark and gtk-application-prefer-dark-theme. GTK_THEME is removed from environment.d and the comment there explains why it must stay removed.

The reload script restarts polkit-agent.service and xdg-desktop-portal-gtk.service, which are the only long-running GTK processes here that draw anything; everything else GTK draws is launched fresh and reads settings.ini as it starts.

Also templated: neovim's vim.o.background, foot's initial-color-theme and its [colors-dark]/[colors-light] section name, and waybar's one literal rgba(0,0,0,0.9) drop shadow, which becomes 0.25 on a light theme.

TWO THINGS FOUND WHILE VERIFYING, BOTH WORTH KEEPING

1. The original rejection in DECISIONS.md was wrong on the mechanism, not just the conclusion. It said environment.d is read when the user manager starts, so GTK could only catch up after a re-login. Measured with a throwaway variable declared in environment.d and then removed: 'systemctl --user daemon-reload' updates the manager's environment in BOTH directions, removal included. No re-login is involved. GTK_THEME also cannot be cleared with 'systemctl --user unset-environment' while its declaration is still live - the generator re-supplies it - which is why the removal has to come from the file.

2. sync.sh's hint for a changed environment.d said it 'needs a fresh login'. That is the advice the user would follow immediately after this change removes GTK_THEME, and it does not work: the user manager starts at first login and survives logging out of sway, which .claude/skills/scripting-traps already records. Corrected to name daemon-reload.

A NOTE ON THE VERIFICATION HARNESS

The first run of the deliberate-break test reported that the mode check did not work. It did; the harness did not. It backed themes.toml up to themes.toml.bak beside the original, inside .chezmoidata/, and chezmoi rejects the whole directory on an unknown extension - so 'chezmoi data' exited 1, the themes section bailed out before reaching any check, and the probe read the resulting unrelated failure as the check being broken. Backups moved outside the repository and the probe now requires its pattern to appear on a FAIL line rather than anywhere in the output.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Light themes now exist because the rule forbidding them turned out to rest on a wrong premise, which was checked rather than argued with.

The repository stated in four places that every theme must be dark, because GTK reads GTK_THEME once at session start. GTK_THEME is only the loudest lever: gtk-3.0/settings.ini is read by each GTK process as it starts, and with the variable unset it decides. Verified on the running machine by launching pavucontrol with GTK_THEME unset and a settings.ini naming Adwaita - it came up fully light with no re-login.

WHAT SHIPPED

Every theme declares mode. The eight existing ones declare dark and are unchanged: rendering the whole tree from HEAD and from the working copy and diffing with comments stripped shows exactly one effective difference across all eight, GTK_THEME leaving environment.d, which is the mechanism change itself.

Three light themes: paper (near-black on paper white, no hue in the chrome, colour reserved for ok/warning/urgent/info - the e-ink one that was asked for), daylight (indigo on white) and sepia (rust on warm cream). Designed against the contrast floors numerically; the tightest value in the whole set is sepia's warning at 4.82:1.

GTK follows the mode through templated gtk-3.0 and gtk-4.0 settings.ini, and the reload script restarts polkit-agent.service and xdg-desktop-portal-gtk.service so the two long-running GTK processes do not hold the old mode for a session. neovim's background, foot's initial-color-theme and colours section, and waybar's one literal black drop shadow all follow the mode too.

HOW IT WAS VERIFIED

All 11 themes render (chezmoi apply to a scratch destination, --exclude=scripts). foot accepts the light configs with --check-config. Screenshots on a throwaway headless output, so the user's screen was never touched: the paper, sepia and daylight desktops with the real rendered waybar stylesheet and foot config; a GTK dialog light under paper and dark under neon through the same templated path; and the polkit authentication dialog itself coming up light under paper with GTK_THEME unset. Both units restart cleanly and return to active. The file chooser was not opened directly - it is the same mechanism, a GTK process restarted so it re-reads settings.ini.

checks/session.sh, packages.sh, manual.sh and sway-commands.sh all pass. session.sh gains four checks - a theme's declared mode against the measured luminance of its bg, GTK_THEME staying unset, the gtk settings following the mode, and the reload script restarting the two units - and each was deliberately broken and watched go red before being trusted.

TWO THINGS FOUND ON THE WAY

sync.sh told the user a changed environment.d 'needs a fresh login'. Measured with a throwaway variable declared and then removed: systemctl --user daemon-reload updates the manager environment in both directions, and logging out of sway does not restart the user manager at all - so the advice did not work, and it is the advice this change makes people follow. Corrected to name daemon-reload.

The first deliberate-break run reported the mode check as broken when it was not. The harness had written its backup as themes.toml.bak inside .chezmoidata/, and chezmoi rejects that whole directory on an unknown extension, so the themes section bailed out before reaching any check. A harness fault reads exactly like the fault it was built to detect.
<!-- SECTION:FINAL_SUMMARY:END -->
