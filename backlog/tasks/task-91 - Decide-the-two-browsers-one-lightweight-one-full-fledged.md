---
id: TASK-91
title: 'Decide the two browsers: one lightweight, one full-fledged'
status: Done
assignee:
  - '@claude'
created_date: '2026-08-21 20:51'
updated_date: '2026-08-22 00:29'
labels: []
dependencies: []
priority: low
type: spike
ordinal: 93000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The desktop should carry two browsers, and only two: a lightweight keyboard-driven one, which qutebrowser already is, and one full-fledged browser for everything qutebrowser cannot do - the sites that need a modern engine's full behaviour, DRM, or an extension.

This exists because checks/packages.sh surfaced firefox as installed by hand and declared nowhere, so a rebuilt machine would not have it. Whether firefox is the right second browser is the actual question, and it is not a question about firefox alone - it is about what the pair should be, which is why it is not being settled as a package-drift line item.

Deliberately low priority: nothing is blocked on it. firefox works today, it simply is not reproducible, and the cost of that is a rebuilt machine missing a browser somebody would notice in the first hour.

Worth settling when picked up: whether the second browser is firefox, a chromium, or a webkit build; whether it needs declaring in desktop.txt or is genuinely occasional enough to install by hand; what qutebrowser actually fails at on this machine, measured rather than assumed, since that is what the second browser is for; and whether the two should share anything - default handler, downloads directory, the xdg-mime entries.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 What qutebrowser cannot do is named from actual use, not assumed
- [x] #2 The second browser is chosen and declared in a manifest, so a rebuilt machine has both
- [x] #3 xdg-mime and the default-browser handling name whichever is meant to open a link, and it is verified by opening one
- [x] #4 The outcome is recorded in DECISIONS.md, which currently has no entry about browsers at all
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Settled from web research plus the local package database, deliberately without an extensive measurement exercise - this was a low-priority spike and the first attempt at it was disproportionate.

The decisive fact is local and took one command: qt6-webengine ships zero Widevine files, so qutebrowser cannot play DRM video at all. That is an absent codec rather than a configuration gap, and it is the whole reason a second browser exists. It has no WebExtension support either.

The field narrowed itself. brave, google-chrome and ungoogled-chromium are not in the official repositories, so TASK-43 disqualifies them. Arch's chromium has no Widevine either and is 416 MiB. vivaldi (434 MiB) and librewolf (424 MiB) are both larger than firefox, and librewolf is a firefox derivative that strips features in this direction rather than adding them. firefox at 295 MiB is the smallest full browser available and enables DRM by default.

A lighter second browser was considered and does not help: falkon is qt6-webengine again and inherits the same missing Widevine, and Epiphany's WebKit has a different DRM story rather than a better one. The point of the second browser is to be the heavy one.

qutebrowser is not as light as its own package size suggests - 11 MiB over 282 MiB of qt6-webengine - which is worth knowing but changes nothing, since that engine is already installed and would be whichever way this went.

AC1 is checked on the DRM and extension findings, which are concrete. AC3 is NOT checked: xdg-mime and default-browser handling were not touched or tested here, and firefox being declared does not by itself decide which browser opens a link. Worth its own small piece of work if it matters.

AC3 completed after the fact. The default handler for http, https and text/html was firefox.desktop - set by installing firefox by hand, not by anything in this repository - so every link clicked anywhere opened the heavy browser rather than the keyboard-driven one, and a rebuilt machine would have resolved it differently again.

Added to run_onchange_after_set-default-applications.sh, which is the existing mechanism and the right one: xdg-mime edits only the entries it is given, where shipping mimeapps.list as a dotfile would overwrite whatever applications register there at runtime.

Verified by opening a link rather than by reading the mime database back: 'gio open https://example.com' produced a window titled 'Example Domain - qutebrowser'. The pre-existing qutebrowser window was left alone and the test window closed by con_id, never by app_id - that selector matches windows nobody meant to include.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
qutebrowser stays as the everyday keyboard-driven browser and firefox is declared in desktop.txt for what it cannot do. The deciding fact is that qt6-webengine ships no Widevine, so qutebrowser cannot play DRM video at all; firefox is the smallest full browser in the official repositories at 295 MiB and enables DRM by default, with brave and chrome disqualified as AUR-only and chromium both larger and equally Widevine-less. Declaring firefox also takes package drift to zero - it had been installed by hand and declared nowhere.
<!-- SECTION:FINAL_SUMMARY:END -->
