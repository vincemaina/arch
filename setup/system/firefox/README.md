# Firefox, turned down

`policies.json` in this directory is installed to `/etc/firefox/policies/policies.json`
by `setup/system/apply-config.sh`, so it reaches a fresh install and a running
machine by the same route as every other machine-wide file here.

JSON takes no comments, so the reasons live in this file. **Every key in
`policies.json` should have a line below.** A policy nobody can explain is the
same dead configuration this repository keeps finding elsewhere; if you add one,
add its reason here.

## Why `/etc/firefox/policies/`, and not the profile

Firefox has two places it will read an enterprise policy from on Linux, and it
prefers the first:

1. `/etc/firefox/policies/policies.json` — only when the build sets
   `MOZ_SYSTEM_POLICIES`.
2. `<install dir>/distribution/policies.json`, i.e. `/usr/lib/firefox/distribution/`.

Arch's build sets it. Read out of the browser rather than assumed:

```bash
mkdir -p /tmp/omni && unzip -qq -o /usr/lib/firefox/omni.ja -d /tmp/omni
grep -o 'MOZ_SYSTEM_POLICIES[^,;}]*' /tmp/omni/modules/AppConstants.sys.mjs
# MOZ_SYSTEM_POLICIES: true
sed -n '/_getLocalConfigurationFile/,/^  }/p' /tmp/omni/modules/EnterprisePoliciesParent.sys.mjs
```

`/etc` wins over `/usr/lib/firefox/distribution/` for a reason that has nothing
to do with precedence: pacman owns that directory, this repository does not, and
a file dropped into a package-owned directory is a file waiting to be surprised
by an upgrade. `/etc/firefox/` is ours, and `install -Dm644` creates it.

`about:policies` in a running Firefox shows what Firefox actually **applied**,
including errors. That is the thing to look at, not this file — a policy can be
present here, valid against the schema, and still absent from that page, which
is how `DisablePocket` was caught. It can be captured without a session:

```bash
firefox --headless --new-instance --no-remote --profile /tmp/p \
        --window-size 1400,2400 --screenshot /tmp/policies.png about:policies
```

To test a change to this file **without root**, set
`toolkit.policies.perUserDir` to true in the test profile's `user.js` and put
`policies.json` in `/run/user/$UID/firefox/`. Firefox reads it through the same
`JSONPoliciesProvider`, so it exercises the file rather than the path.

## What is turned off, and why

### The promotions

| Policy | Why |
| --- | --- |
| `UserMessaging.MoreFromMozilla: false` | Removes the "More from Mozilla" section in preferences, which is where the **VPN promotion** lives. This is the policy that actually deletes it; the `browser.vpn_promo.*` prefs below only stop the other surfaces. |
| `browser.vpn_promo.enabled: false` | The VPN promotion elsewhere in the interface. |
| `browser.contentblocking.report.vpn.enabled: false`, `...hide_vpn_banner: true` | The protections dashboard advertises the VPN in two separate places; this is both of them. |
| `browser.contentblocking.report.show_mobile_app: false` | The same dashboard advertising Firefox for mobile. |
| `UserMessaging.WhatsNew: false` | The "What's New" toolbar item after an update. |
| `UserMessaging.FeatureRecommendations: false` | In-product nudges toward features. |
| `UserMessaging.ExtensionRecommendations: false` | "You should install this extension" on certain pages. |
| `UserMessaging.UrlbarInterventions: false` | The address bar offering to do something other than search. |
| `UserMessaging.SkipOnboarding: true`, `browser.aboutwelcome.enabled: false` | The multi-screen first-run tour. A rebuilt machine should land on a browser, not a wizard. |
| `browser.promo.focus.enabled: false` | The promotion for Firefox Focus, the mobile browser. |
| `OverrideFirstRunPage: ""`, `OverridePostUpdatePage: ""` | The "what's new in this version" tab on first launch and after every update. |
| `UserMessaging.Locked: true`, `FirefoxHome.Locked: true` | The two sections above are locked so the settings do not reappear as togglable and drift per machine. |

### Pocket

| Policy | Why |
| --- | --- |
| `FirefoxHome.Pocket: false`, `FirefoxHome.SponsoredPocket: false` | The Pocket tiles on the new tab page. |
| `FirefoxHome.Stories: false`, `FirefoxHome.SponsoredStories: false` | The same feed after Mozilla renamed it; both spellings are set so this does not silently come back on a version bump. |

**`DisablePocket` is deliberately absent, and it is the interesting one.** It is
the policy every guide names, it is still in `policies-schema.json`, and it
validates — and Firefox 154 lists it under `deprecated_policies` in
`aboutPolicies.js` with no implementation behind it. Mozilla shut Pocket down;
the policy stayed in the schema as a shell.

So it passed a schema check and did nothing, which is this repository's exact
failure mode wearing a badge of correctness. **What caught it was
`about:policies`**, which lists what Firefox actually applied: every other
policy in this file appeared under *Active* and that one did not. Validate
against the schema by all means, but the screenshot is the proof.

### Sponsored content on the new tab page

| Policy | Why |
| --- | --- |
| `FirefoxHome.SponsoredTopSites: false` | The paid tiles among the shortcuts. |
| `browser.urlbar.suggest.quicksuggest.sponsored: false` | Sponsored suggestions in the address bar, which is the same idea one surface over. |
| `FirefoxHome.Highlights: false`, `FirefoxHome.Snippets: false` | Recent-activity tiles and Mozilla's own messages on the new tab page. `Search` and `TopSites` stay **on**: those are the two things a new tab is for. |

### Telemetry and studies

| Policy | Why |
| --- | --- |
| `DisableTelemetry: true` | No usage data collection. |
| `DisableFirefoxStudies: true` | No Normandy/Shield studies — Mozilla changing this browser's behaviour remotely, which is the part that matters more than the data. |
| `DisableFeedbackCommands: true` | The "Submit Feedback" and "Report Deceptive Site" menu items that go with it. |

### Firefox View — NOT turned off, because it cannot be

**There is no policy and no preference for this in Firefox 154.** It is the one
thing on TASK-183's list that this file does not deliver, and it is written down
here rather than left to look handled.

The tempting answer is `browser.tabs.firefox-view: false`, which is what most
search results still say. **That pref does not exist.** It was real in the
versions those pages were written for, and the trap is that setting a
nonexistent pref through the `Preferences` policy is silent — Firefox writes it
and nothing reads it, so the file looks configured and the button is still
there. Checked before believing it:

```bash
# ROOTS = the two unpacked omni.ja archives plus /usr/lib/firefox/*/defaults
grep -rhaoE 'browser\.tabs\.firefox-view[^a-zA-Z0-9._-]' $ROOTS   # no matches
grep -rhaoE 'browser\.tabs\.firefox-view[a-zA-Z0-9._-]*' $ROOTS   # 9 LONGER prefs
```

The second command is why a careless check passes: `browser.tabs.firefox-view`
matches as a *prefix* of `browser.tabs.firefox-view.logLevel` and eight others.
Match on a trailing non-name character, or the grep confirms whatever you
already believed. Two prefs in the first draft of this file were dead this way.

Firefox View is a CustomizableUI widget (`firefox-view-button`), and
`policies-schema.json` has nothing covering it — no `FirefoxView` key, and the
nearest ones (`FirefoxHome`, `NewTabPage`, `DisplayBookmarksToolbar`,
`ShowHomeButton`) are all about other surfaces.

**So the manual step, once per profile:** right-click the Firefox View button at
the left of the tab strip and choose *Remove from Toolbar*. It is stored in the
profile, so a profile reset brings it back and a rebuilt machine starts with it.

The `userChrome.css` route would work and is rejected for the reason the whole
file exists: the stylesheet has to go in `~/.mozilla/firefox/<random>/chrome/`,
which is the unaddressable path problem again, and it would need
`toolkit.legacyUserProfileCustomizations.stylesheets` on as well. Two mechanisms
and a random directory, to hide one button.

### Things that are not promotions, turned off because of what this machine is

| Policy | Why |
| --- | --- |
| `DisableAppUpdate: true` | Firefox is a pacman package. Its own updater cannot write to `/usr/lib/firefox`, so leaving it on produces a browser that nags about an update it is structurally unable to apply. `sync.sh` updates it. |
| `DontCheckDefaultBrowser: true` | The default browser is decided by `run_onchange_after_set-default-applications.sh` and lives in `mimeapps.list`. Firefox asking on every start would be asking about something the repository has already answered. |
| `DisableSetDesktopBackground: true` | The wallpaper is generated from the theme by `~/.local/bin/wallpaper`. A right-click that overwrites it would be an untracked change to a tracked thing. |
| `DisableProfileImport: true` | There is no other browser profile to import from on a fresh machine, and the prompt is first-run noise. |
| `NoDefaultBookmarks: true` | The shipped bookmark folder is Mozilla marketing links. Only takes effect for a profile created after this policy is in place. |

## Vimium

`ExtensionSettings` force-installs Vimium, because an extension installed by hand
on one machine is exactly the untracked state this repository exists to avoid.
`installation_mode: normal_installed` installs it and leaves the user free to
disable or remove it; `force_installed` would take that away for no gain.

The key is the add-on's GUID, not its slug, and it was read from AMO rather than
remembered:

```bash
curl -s https://addons.mozilla.org/api/v5/addons/addon/vimium-ff/ | python3 -c \
  'import json,sys; print(json.load(sys.stdin)["guid"])'
# {d7742d87-e61d-4b78-b8a1-b469842139fa}
```

**This needs the network at first launch.** Firefox fetches the XPI itself, so a
machine built offline gets a Firefox without Vimium and installs it on the first
launch that has a connection. There is no way around that with this mechanism
short of vendoring the XPI, which would put a binary blob in a repository that
does not track so much as a wallpaper.

## What this deliberately does not do

- **No `user.js`.** It would have to be written into
  `~/.mozilla/firefox/<random>.default-release/`, and chezmoi has no way to name a
  path it cannot know. See `DECISIONS.md` → "Firefox is configured by enterprise
  policy, not by a profile file".
- **Nothing about privacy hardening.** No resist-fingerprinting, no changed
  cookie policy, no disabled WebRTC. This file removes what Mozilla adds; it does
  not try to be a different browser. `librewolf` was already rejected on those
  grounds in `setup/packages/desktop.txt`.
