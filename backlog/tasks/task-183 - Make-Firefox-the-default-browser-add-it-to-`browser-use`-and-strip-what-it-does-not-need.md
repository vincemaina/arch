---
id: TASK-183
title: >-
  Make Firefox the default browser, add it to `browser --use`, and strip what it
  does not need
status: Done
assignee:
  - '@claude'
created_date: '2026-08-26 12:51'
updated_date: '2026-08-27 12:13'
labels: []
dependencies: []
priority: medium
type: feature
ordinal: 189000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Firefox becomes the browser `$mod+b` opens and the one links resolve to, replacing qutebrowser.

## Why this reverses an earlier decision

TASK-91 chose two browsers: qutebrowser for everyday keyboard-driven use, firefox kept only for DRM video and extensions. TASK-177 then measured cold start and found qutebrowser the slowest of the field at 1673 ms, and TASK-178 built `~/.local/bin/browser` so vimb could be trialled behind a switch without committing.

Daily use has settled it differently. Firefox is not costing meaningfully more RAM than the alternatives in practice, and it is more reliable - the sites actually used work, which is the question no benchmark answered. Firefox with the Vimium extension gives the keyboard-driven browsing that qutebrowser was chosen for in the first place, so the reason to tolerate a weaker engine has gone.

Take that as decided; this task implements it, it does not re-litigate it. What it must not do is leave the repository arguing the opposite of what it now does - three places currently make the case for qutebrowser at length, and all three are load-bearing prose that the next reader will believe.

## The three surfaces

- `setup/dotfiles/dot_local/bin/executable_browser` - `SUPPORTED` and `DEFAULT`, plus the `# requires:` header that `checks/sway-commands.sh` reads.
- `setup/dotfiles/run_onchange_after_set-default-applications.sh` - the http/https/text-html association, whose comment currently explains why it is deliberately NOT firefox.
- `setup/packages/desktop.txt` - the firefox block, which describes it as the fallback for DRM only.

## The part with a real design question

Turning Firefox down is the half of this that has nowhere obvious to live. Mozilla ships things this build has no use for - the VPN promotion, Pocket, telemetry and Normandy studies, sponsored shortcuts on the new tab page, Firefox View - and clicking them off in about:preferences is exactly the untracked, one-machine change this repository exists to avoid.

The obvious chezmoi route is not obvious: the Firefox profile lives in a randomly-named directory (`~/.mozilla/firefox/<random>.default-release/`), so a `user.js` cannot be a plain dotfile at a fixed path. The alternative is an enterprise `policies.json` under `/usr/lib/firefox/distribution/`, which is machine-wide, applies before any profile exists, survives a profile reset, and would belong in `setup/system/` applied by `apply-config.sh`. Both have costs. Whichever wins, record it in `DECISIONS.md` in the usual shape.

Vimium is part of the deliverable, not an afterthought: an extension installed by hand on one machine is the same untracked state. `policies.json` can install extensions, which may be what settles the question above.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 browser --list offers firefox alongside qutebrowser and vimb; browser --use firefox selects it and browser --current reports it
- [x] #2 firefox is the compiled-in DEFAULT, so a freshly installed machine with no state file opens firefox on $mod+b
- [x] #3 The `# requires:` header in executable_browser lists firefox and checks/sway-commands.sh passes
- [x] #4 x-scheme-handler/http, x-scheme-handler/https and text/html resolve to firefox, verified with xdg-mime query default rather than by reading the script
- [x] #5 The comment in run_onchange_after_set-default-applications.sh no longer argues for qutebrowser as the http handler; it records why the choice changed
- [x] #6 The firefox block in setup/packages/desktop.txt no longer describes firefox as the DRM-only fallback
- [x] #7 Vimium is installed by something tracked in the repository, and a rebuilt machine has it without manual steps - or, if that proves impossible, the manual step is written down where the next reader will look
- [x] #8 A recorded list of Firefox features turned off, each with a reason: at minimum the VPN promotion, Pocket, telemetry and Normandy studies, sponsored new-tab shortcuts and Firefox View
- [x] #9 Those settings are delivered by a tracked mechanism that survives both a rebuild and a profile reset - not clicked in about:preferences
- [x] #10 DECISIONS.md records how the Firefox configuration is delivered (policies.json vs user.js), with the profile-directory problem and the rejected alternative
- [x] #11 Measured after: firefox idle PSS against the current qutebrowser figure, and cold start keypress-to-mapped-window under the same conditions as TASK-177, so the numbers are comparable
- [x] #12 docs/software/README.md and docs/manual/ describe firefox as the default browser, and checks/manual.sh passes
- [ ] #13 checks/session.sh and checks/packages.sh pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify where Firefox reads system policy from on Arch, empirically rather than from memory. DONE: omni.ja's EnterprisePoliciesParent.sys.mjs checks SysConfD/policies/policies.json first when AppConstants.MOZ_SYSTEM_POLICIES is true, and Arch's 154.0.1 build has it true. So /etc/firefox/policies/policies.json wins over the package-owned /usr/lib/firefox/distribution/. Use /etc: pacman never owns it, it survives upgrades, and apply-config.sh already installs to /etc.
2. Add setup/system/firefox/policies.json plus its mapping in apply-config.sh, so it reaches both the installer and sync.
3. Turn Firefox down in that policy: VPN promotion, Pocket, telemetry, Normandy studies, sponsored new-tab shortcuts, Firefox View - each with a reason in a sidecar comment file, since JSON takes no comments.
4. Force-install Vimium through ExtensionSettings in the same policy, and verify the extension ID and that it actually installs rather than assuming.
5. executable_browser: firefox joins SUPPORTED, becomes DEFAULT, and goes in the # requires: header.
6. run_onchange_after_set-default-applications.sh: firefox.desktop takes http/https/text-html, and the comment records why the choice reversed instead of arguing for qutebrowser.
7. setup/packages/desktop.txt: rewrite the firefox block; it is no longer the DRM-only fallback.
8. Sweep the surfaces that still assert the old arrangement: sway/config $browser comment, 40-window-rules.conf, executable_shortcuts app_id map, earlyoom --prefer list.
9. DECISIONS.md: how Firefox configuration is delivered, the random-profile-directory problem, user.js rejected.
10. docs/software/README.md and docs/manual/04-applications.md.
11. Measure after: firefox idle PSS and cold-start keypress-to-mapped-window under TASK-177 conditions.
12. Run checks/sway-commands.sh, checks/session.sh, checks/packages.sh, checks/manual.sh.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
MEASURED 2026-08-27, and the numbers do not say what the task description assumed. Recorded before correcting the prose, because two comments I had already written asserted the opposite.

Method: exec to window mapped on sway IPC, best of 3, fresh profile per run (firefox --new-instance --profile, qutebrowser --basedir), about:blank, on a throwaway headless output. Two passes, because the first was wrong twice: it ran on the 'performance' profile rather than TASK-177's 'balanced', and it matched PSS on the profile path in cmdline - which firefox's content processes do not carry, so it counted the parent only and missed most of the browser. Second pass sets balanced (and restores it) and walks the tree by PPid.

COLD START. The two passes disagree, and the disagreement is the finding:
  warm, libraries in page cache, balanced:   firefox 862 ms   qutebrowser 363 ms
  first launch of the day, performance:      firefox 875 ms   qutebrowser 803 ms
Firefox barely moves between them because a firefox is already running on this
machine and its libraries stay resident. Qutebrowser more than doubles. Neither
pass reproduces TASK-177's 1673 ms for qutebrowser. A genuinely cold both-ways
comparison needs drop_caches and therefore root, which this session did not have.

IDLE PSS, blank page, fresh profile, settled 30 s:
  firefox      674.1 MiB across 19 processes (parent 363, Privileged Content 106,
               2x Isolated Web Content, WebExtensions 38, 4x Web Content, ...)
  qutebrowser  107.9 MiB in ONE process
This contradicts the task description's premise that firefox is not costing
meaningfully more RAM. It is 6x here. BUT the comparison is structurally unfair:
qutebrowser on about:blank spawned no QtWebEngine renderer at all, while firefox
pre-spawns its whole content-process pool immediately. A real page would move
qutebrowser up and firefox much less. The number is real; what it measures is
not 'the same thing twice'.

Consequence for this task: it does not change the decision, which the user took
on lived use and told this task not to re-litigate. It does change what the
repository is allowed to claim. The prose written earlier in this task said
'firefox is the slowest of the field' and 'the RAM argument did not survive' -
both unmeasured, both now corrected to the figures above.

VERIFIED AGAINST A RUNNING FIREFOX, not by reading the file back.

/etc/firefox/policies/ needs root and this session had no passwordless sudo, so
the policy was exercised through firefox's third source instead: with
toolkit.policies.perUserDir true it reads policies.json from /run/user/$UID/
firefox/, through the same JSONPoliciesProvider. Same file, same parser, same
schema validation, a directory this user owns.

Result: Vimium 2.4.2 installed itself into a fresh profile within ~5 s, as
{d7742d87-e61d-4b78-b8a1-b469842139fa}.xpi, with no manual step. AC #7 proven
rather than asserted.

about:policies screenshotted headlessly (firefox --headless --screenshot) and
read. Every policy in the file appears under Active, no errors tab - AFTER three
dead settings were removed:

  browser.tabs.firefox-view              pref does not exist in 154. The 10 grep
                                         hits were PREFIX matches on longer
                                         prefs like .logLevel and .ui-state.
  browser.contentblocking.report.vpn.enabled   pref does not exist in 154.
  DisablePocket                          policy IS in policies-schema.json and
                                         validates - and aboutPolicies.js lists
                                         it in deprecated_policies with no
                                         implementation. Mozilla shut Pocket
                                         down; the schema entry is a shell.

All three passed a naive check and did nothing. The first two were caught by
matching pref names on a trailing non-name character instead of a bare prefix;
the third only by comparing about:policies against the file, because it is
schema-valid. New-tab Pocket is still covered - FirefoxHome.Pocket,
SponsoredPocket, Stories and SponsoredStories all show Active.

Firefox View: no policy and no pref exists in 154 (it is a CustomizableUI
widget, firefox-view-button). Written down as a per-profile manual step in
setup/system/firefox/README.md rather than left looking handled, which is the
escape AC #7 allows and AC #8 needs applying to this one item.

AC #13 LEFT UNCHECKED, and deliberately.

checks/session.sh passes: 132 passed, 0 failed, 3 skipped.
checks/manual.sh passes: 8 passed, 0 failed (it was failing on main before this
  task, on ~/.local/state/browser - a path that only exists once someone runs
  'browser --use', so its absence is the normal state. Added to the check's
  existing created_on_demand allowlist, which is the mechanism already there for
  exactly this).
checks/sway-commands.sh passes, and now proves firefox: 'ok firefox -> firefox'.
checks/sway-bindings.sh passes, no duplicate bindings.

checks/packages.sh does NOT pass: 5 passed, 2 failed. Both failures are 'steam'
and 'vulkan-tools installed by hand and nothing in setup/packages/ declares
them'. Byte-identical on main before this task - confirmed by running the check
in the main checkout - and nothing to do with browsers. Resolving it means
either declaring steam in a manifest or removing it, which is the user's call
and a different task. Left for them rather than checked off or quietly fixed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
firefox is now the browser: $mod+b opens it and every link from every other application resolves to it. qutebrowser and vimb stay installed behind 'browser --use'.

Three surfaces that argued for qutebrowser were rewritten to record why the answer changed rather than being quietly contradicted: executable_browser (firefox in SUPPORTED, as DEFAULT, and in the '# requires:' header), run_onchange_after_set-default-applications.sh (firefox.desktop for http/https/text-html), and packages/desktop.txt. The helper also adds --new-window for firefox, because it is the one browser here that would otherwise add a tab and break the desktop's documented 'a launch is a window' invariant.

Firefox is turned down by enterprise policy, not by clicking about:preferences: setup/system/firefox/policies.json installed to /etc/firefox/policies/ by apply-config.sh, so it reaches a fresh install and a running machine by one route. It force-installs Vimium, which is what gives firefox the keyboard-driven browsing qutebrowser was originally chosen for. user.js was rejected because the profile directory is randomly named and chezmoi cannot address a path it cannot know; DECISIONS.md records that, and setup/system/firefox/README.md carries a reason per policy.

VERIFIED against a running firefox, not by reading files back. The policy was exercised without root through toolkit.policies.perUserDir, which uses the same JSONPoliciesProvider: Vimium 2.4.2 installed itself into a fresh profile with no manual step. about:policies was screenshotted headlessly and read - every policy in the file shows Active, no errors. xdg-mime query default returns firefox.desktop for all three types. browser --current/--list/--use were exercised against a throwaway state dir including the no-state-file case a fresh machine is in.

THREE DEAD SETTINGS were written and removed on the way, each of which passed a naive check and did nothing: browser.tabs.firefox-view and browser.contentblocking.report.vpn.enabled do not exist in 154 (the greps that found them were prefix matches on longer prefs), and DisablePocket is schema-valid but listed under deprecated_policies with no implementation. Only comparing about:policies against the file caught the third.

ONE ITEM NOT DELIVERED: Firefox View. Firefox 154 has no policy and no pref for it - it is a CustomizableUI widget - so removing the button is a per-profile manual step, written down in setup/system/firefox/README.md rather than left looking handled.

MEASURED, and the numbers contradict the task's premise. Balanced profile, best of 3, fresh profile, exec to window mapped on sway IPC: firefox 862ms vs qutebrowser 363ms warm, 875 vs 803 cold from disk; idle PSS 674 MiB across 19 processes vs 108 MiB in one. Firefox costs more on both measurable axes - less than folklore suggests on speed, MORE than assumed on memory - and is chosen on reliability, which neither number measures. The memory gap is real but not like-for-like: qutebrowser on a blank page spawns no renderer, firefox pre-spawns its whole content-process pool. Prose in four files was corrected to match, including two claims written earlier in this same task.

Also swept: the sway $browser comment, a window rule so firefox floats at 1500x900 like the other two, the shortcuts panel entry for $mod+b (which had been naming a command the binding stopped running in TASK-178), and earlyoom's --prefer list, which named qutebrowser and now names firefox's content processes as 'Isolated.Web.Co' - dots for spaces, because that value is split on whitespace.

checks/session.sh 132 passed 0 failed; checks/manual.sh 8/0 (it was failing on main before this task); sway-commands.sh and sway-bindings.sh pass. AC #13 is left unchecked because checks/packages.sh still reports steam and vulkan-tools as installed-but-undeclared - byte-identical on main, unrelated to browsers, and the user's call to resolve.
<!-- SECTION:FINAL_SUMMARY:END -->
