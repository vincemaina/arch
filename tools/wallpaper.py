#!/usr/bin/env python3
"""Render a theme's wallpaper from that theme's own colours.

This is repository tooling. It runs on a machine where the repository is being
worked on, writes a PNG into setup/dotfiles/, and that PNG reaches the built
machine like any other dotfile. Nothing here is installed on the target system,
and it deliberately has no dependencies beyond the standard library - an earlier
version of this generator needed numpy and Pillow, was never committed, and was
gone by the time a second wallpaper was wanted.

    tools/wallpaper.py --theme ember
    tools/wallpaper.py --all
    tools/wallpaper.py --theme slate --out /tmp/preview.png

WHY THE WALLPAPER IS GENERATED RATHER THAN CHOSEN

Because it belongs to the theme. The bar and the window borders are tuned to sit
against the background, so a palette that arrived with someone else's photograph
would clash with itself. Deriving the image from the same colours the rest of the
desktop reads means a new theme gets a matching background for free, and means
there is no separate thing to keep in step.

HOW THE IMAGE IS BUILT

Soft overlapping colour fields - each a gaussian blob in one of the theme's
colours over its darkest background - with the coordinates warped by smooth
noise before the fields are evaluated, so the shapes are organic rather than
obviously circular.

The composition is identical for every theme: the same blobs in the same places,
only the colours differ. That is intentional. Three unrelated pictures would look
like three different desktops rather than one desktop wearing three palettes.

Rendered small and upscaled, because there is no detail to lose in a gradient,
with a little noise added at full size. The noise is not decoration: smooth
gradients band visibly across a wide screen, and a per-pixel dither is what
hides it.

One level of dither, chosen by measuring rather than by eye. Counting how often
the value changes down the centre column of the frame: undithered, it changes
149 times in 1080 rows - bands about seven pixels deep, which is exactly what
banding looks like. At +/-1 it changes 664 times and the bands are gone. At
+/-2 it changes 828 times, which is no better to look at and costs another
megabyte, because noise is the one thing PNG cannot compress. The tracked
images are around 2.8M each; undithered they would be 368K, and visibly striped.
"""

import argparse
import math
import pathlib
import random
import struct
import sys
import tomllib
import zlib

REPO = pathlib.Path(__file__).resolve().parent.parent
THEMES = REPO / "setup" / "dotfiles" / ".chezmoidata" / "themes.toml"
WALLPAPERS = REPO / "setup" / "dotfiles" / "dot_local" / "share" / "wallpapers"

WIDTH, HEIGHT = 1920, 1080
SMALL_W, SMALL_H = 320, 180          # the field is evaluated here, then scaled
NOISE_AMPLITUDE = 1                  # levels of dither, applied at full size

# The composition, in fractions of the frame so it is resolution independent.
# Each entry is a colour role from the palette, a centre, a radius and how
# strongly it shows. Kept dim on purpose: the bar sits on top of this and the
# windows sit in front of it, so the wallpaper is a backdrop and not a subject.
#
#   role, cx, cy, radius, strength
FIELDS = [
    ("tertiary",  0.30, 0.66, 0.40, 0.78),   # the main mass, low and left
    ("secondary", 0.56, 0.94, 0.30, 0.62),   # a glow along the bottom edge
    ("accent",    0.90, 0.14, 0.26, 0.20),   # a cool corner, top right
    ("tertiary",  0.74, 0.46, 0.24, 0.26),   # ties the two halves together
]

# The corners go back to the base colour, which is what stops the image reading
# as one flat wash. It also matters at the top: the bar is nearly black, and a
# bright top edge behind it makes the bar look like a bandage rather than part
# of the screen.
#
# A first draft did this with another colour field, in `bg` - which is *lighter*
# than the `bg_dim` the image is built on, so it brightened the corner it was
# meant to darken. Visible only once rendered, which is the failure mode this
# repository keeps meeting.
VIGNETTE_START = 0.30     # fraction of the half-diagonal where it begins
VIGNETTE_STRENGTH = 0.95  # how far the corners return to the base colour

WARP_STRENGTH = 0.16    # how far the domain warp displaces, in frame fractions
WARP_CELLS = 3          # coarse: large slow bends rather than visible wobble
SEED = 20260821         # fixed, so regenerating a theme reproduces its image


def parse_hex(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def value_noise(seed, cells):
    """A smooth scalar field on [0,1]^2, built by interpolating a random grid.

    Value noise rather than anything cleverer because the result is blurred to
    nothing anyway - it is used only to bend coordinates, never seen directly.
    """
    rnd = random.Random(seed)
    grid = [[rnd.random() for _ in range(cells + 1)] for _ in range(cells + 1)]

    def sample(u, v):
        x, y = u * cells, v * cells
        x0, y0 = min(int(x), cells - 1), min(int(y), cells - 1)
        fx, fy = x - x0, y - y0
        # Smoothstep, so the grid lines do not show as creases.
        fx = fx * fx * (3 - 2 * fx)
        fy = fy * fy * (3 - 2 * fy)
        top = grid[y0][x0] * (1 - fx) + grid[y0][x0 + 1] * fx
        bottom = grid[y0 + 1][x0] * (1 - fx) + grid[y0 + 1][x0 + 1] * fx
        return top * (1 - fy) + bottom * fy

    return sample


def render_small(palette):
    """Evaluate the colour fields at low resolution, returning rows of floats."""
    warp_x = value_noise(SEED, WARP_CELLS)
    warp_y = value_noise(SEED + 1, WARP_CELLS)

    base = parse_hex(palette["bg_dim"])
    fields = [
        (parse_hex(palette[role]), cx, cy, radius, strength)
        for role, cx, cy, radius, strength in FIELDS
    ]

    rows = []
    for py in range(SMALL_H):
        v = py / (SMALL_H - 1)
        row = []
        for px in range(SMALL_W):
            u = px / (SMALL_W - 1)

            # The domain warp. Displace the sample point by the noise before
            # measuring distance to each blob, which is what turns circles into
            # shapes that look poured rather than drawn.
            wu = u + (warp_x(u, v) - 0.5) * WARP_STRENGTH
            wv = v + (warp_y(u, v) - 0.5) * WARP_STRENGTH

            r, g, b = base
            for (fr, fg, fb), cx, cy, radius, strength in fields:
                # Aspect-corrected, or every blob is an ellipse on a 16:9 frame.
                dx = (wu - cx) * (WIDTH / HEIGHT)
                dy = wv - cy
                d2 = dx * dx + dy * dy
                weight = strength * math.exp(-d2 / (2 * radius * radius))
                r += (fr - r) * weight
                g += (fg - g) * weight
                b += (fb - b) * weight

            # Vignette, measured on the unwarped coordinates so it stays an
            # even frame rather than following the blobs around.
            dx = (u - 0.5) * (WIDTH / HEIGHT)
            dy = v - 0.5
            reach = math.hypot(dx, dy) / math.hypot(0.5 * WIDTH / HEIGHT, 0.5)
            fade = max(0.0, (reach - VIGNETTE_START) / (1 - VIGNETTE_START))
            fade = min(1.0, fade * fade) * VIGNETTE_STRENGTH
            r += (base[0] - r) * fade
            g += (base[1] - g) * fade
            b += (base[2] - b) * fade

            row.append((r, g, b))
        rows.append(row)
    return rows


def upscale_with_noise(small, rnd):
    """Bilinear upscale to full size, dithered to stop the gradients banding."""
    for py in range(HEIGHT):
        sy = py * (SMALL_H - 1) / (HEIGHT - 1)
        y0 = min(int(sy), SMALL_H - 2)
        fy = sy - y0
        top_row, bottom_row = small[y0], small[y0 + 1]

        out = bytearray()
        for px in range(WIDTH):
            sx = px * (SMALL_W - 1) / (WIDTH - 1)
            x0 = min(int(sx), SMALL_W - 2)
            fx = sx - x0

            pixel = []
            for channel in range(3):
                top = top_row[x0][channel] * (1 - fx) + top_row[x0 + 1][channel] * fx
                bot = bottom_row[x0][channel] * (1 - fx) + bottom_row[x0 + 1][channel] * fx
                value = top * (1 - fy) + bot * fy
                value += rnd.uniform(-NOISE_AMPLITUDE, NOISE_AMPLITUDE)
                pixel.append(max(0, min(255, int(value + 0.5))))
            out += bytes(pixel)
        yield bytes(out)


def write_png(path, rows):
    """Minimal PNG writer: 8-bit truecolour, filter 0, one IDAT."""
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(kind, data):
        body = kind + data
        return (struct.pack(">I", len(data)) + body
                + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF))

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def build(name, palette, out):
    small = render_small(palette)
    rnd = random.Random(SEED + sum(name.encode()))
    write_png(out, upscale_with_noise(small, rnd))
    size = out.stat().st_size
    print(f"    {name:8} -> {out}  ({size / 1024 / 1024:.1f}M)")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--theme", help="theme to render")
    ap.add_argument("--all", action="store_true", help="render every theme")
    ap.add_argument("--out", type=pathlib.Path,
                    help="write here instead of into setup/dotfiles/")
    args = ap.parse_args()

    themes = tomllib.loads(THEMES.read_text())["themes"]

    if args.all:
        names = list(themes)
    elif args.theme:
        names = [args.theme]
    else:
        ap.error("pass --theme NAME or --all")

    if args.out and len(names) > 1:
        ap.error("--out takes one theme")

    for name in names:
        if name not in themes:
            sys.exit(f"No theme called {name!r}. Known: {', '.join(themes)}")
        palette = themes[name]
        # The theme names its own file, so the two cannot drift apart.
        out = args.out or (WALLPAPERS / palette["wallpaper"])
        out.parent.mkdir(parents=True, exist_ok=True)
        build(name, palette, out)


if __name__ == "__main__":
    main()
