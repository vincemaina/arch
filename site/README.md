# site/

The Swaystone landing page, published to GitHub Pages by
[`.github/workflows/pages.yml`](../.github/workflows/pages.yml) on every push to
`main` that touches this directory.

**Like `docs/`, `checks/` and `backlog/`, this is repository tooling.** Nothing in
here reaches the built machine, and nothing it needs may be added to
`setup/packages/`.

## What is here

| File | What it is |
| --- | --- |
| `index.html` | The whole page. One long scroll, no framework. |
| `style.css` | One stylesheet. Colours come only from the custom properties at the top. |
| `theme.js` | Builds the palette picker and repaints `:root` when one is chosen. |
| `themes.js` | **Generated.** The eleven palettes, from the desktop's own `themes.toml`. |
| `assets/` | Two screenshots and the favicon. |

There is no build step. Open `index.html` in a browser and that is exactly what
Pages serves.

## Changing it

Edit `index.html` and `style.css` directly.

**Do not edit `themes.js`.** It is generated from
`setup/dotfiles/.chezmoidata/themes.toml`, which is the same file the desktop
templates its own colours out of. After adding or changing a theme:

```bash
./tools/site-themes.py
```

That is the whole point of the arrangement: the page wears the real palettes, so
a colour changed for the desktop cannot quietly leave the website showing the old
one.

## Screenshots

`assets/hero.webp` and `assets/launcher.webp` were captured on a throwaway
headless output rather than off a real screen — see the `desktop-verification`
skill for the recipe — so they show a staged, uncluttered session rather than
whatever happened to be open. Re-capture the same way when the desktop's
appearance changes:

```bash
swaymsg create_output                       # HEADLESS-n
swaymsg output HEADLESS-1 resolution 1920x1200
swaymsg output HEADLESS-1 dpms on           # not optional; grim cannot read a powered-off output
# ... launch windows on it, then:
grim -o HEADLESS-1 shot.png
swaymsg 'focus output eDP-1'                # give the screen back first
swaymsg 'output HEADLESS-1 unplug'
```

`grim` writes PNG. The page carries WebP because the two PNGs came to 1.4 MB
between them, which is a silly thing to serve from a page arguing for being
light:

```bash
ffmpeg -i shot.png -c:v libwebp -quality 84 -compression_level 6 assets/hero.webp
```

## The numbers on the page

Every figure is checkable, and should be re-checked rather than trusted when the
system changes:

| Claim | Where it comes from |
| --- | --- |
| 550–650 MiB idle | `DECISIONS.md` → Goals, and `README.md` |
| ~0% idle CPU | same |
| 4.5 s userspace to a desktop | `systemd-analyze` on the reference machine |
| 116 packages | `grep -Ev '^[[:space:]]*(#\|$)' setup/packages/*.txt \| wc -l` |
| 76 keyboard bindings | `./checks/sway-bindings.sh`, which prints the total it found |
| 39 helper scripts | `ls setup/dotfiles/dot_local/bin/ \| wc -l` |
| 11 themes | `grep -c '^\[themes\.[a-z]*\]$' setup/dotfiles/.chezmoidata/themes.toml` |
| 6 check scripts | `ls checks/*.sh \| wc -l` |

Nothing fails when one of these drifts — there is no `checks/site.sh`. If that
starts to matter, write one; it is exactly the failure mode this repository keeps
finding.

One of them has already been got wrong once. A first draft said "70 shortcuts",
from `grep -c '^bindsym'` — which counts only bindings at the start of a line and
so misses the six inside the resize mode block. `checks/sway-bindings.sh` reports
76, and a reader who runs the repository's own check should not find the page
disagreeing with it. Take the number from the check, not from a grep written to
produce it.
