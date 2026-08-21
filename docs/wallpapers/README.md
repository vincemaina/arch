# Wallpapers

Wallpapers are **generated on the machine** from the selected theme's own
colours, by `~/.local/bin/wallpaper`. Nothing image-shaped is tracked in this
repository, and adding a theme adds no binary files at all.

```bash
wallpaper                 # pick a style from the launcher
wallpaper aurora          # set the style for the current theme
wallpaper --list          # what is available, and which is current
wallpaper --regenerate    # render it again
wallpaper ~/pics/foo.png  # use a file of your own instead
```

## Why generated, and why on the machine

Two separate reasons that happen to point the same way.

**Generated**, because the wallpaper belongs to the theme. The bar, the borders
and the glow were tuned to sit against the background, so a palette swap that
left the old picture behind would clash with itself, and a hand-picked image per
theme is one more thing to keep in step.

**On the machine**, because committing them does not scale. Three themes at one
image each was already 7.8M of tracked PNG. Eight themes at four styles is
around 90M, and it would grow by roughly ten megabytes every time a theme was
added - which is exactly backwards, because the point of the theme system is
that adding one should be free. Generated and cached, a theme costs nothing but
a table of colours.

The cache lives in `~/.local/share/wallpapers/`, named `<theme>-<style>.png`.
Deleting it costs a second or two per image and nothing else.

## The styles

| Style | What it is |
| --- | --- |
| `mesh` | Soft overlapping colour fields, domain-warped. The default |
| `aurora` | Vertical curtains of light, brightest low down |
| `contour` | Topographic lines over a quiet ground |
| `grid` | A horizon with a perspective grid receding to it |

Two of them are smooth and two carry lines, and that distinction is the only
interesting thing about the implementation. Smooth styles are evaluated on a
320x180 grid and bilinearly upscaled, because a gradient has no detail to lose.
Line styles upscale a *field* the same way and then compute the lines from it at
full resolution - drawing them small and scaling up was tried first and looks
exactly like what it is.

The composition is fixed across themes: only the colours change, so eight themes
read as one desktop wearing eight palettes rather than eight unrelated pictures.

## Your own images

`wallpaper /path/to/image.png` records that path instead of a style name, and
sway is pointed straight at it. The theme's colours will not follow it, which is
your business rather than a bug - the mechanism exists so that wanting one
photograph does not mean needing a second mechanism.

## Note

The bar has a solid dark background, so it reads as a dark strip across the top
of whichever image is showing rather than blending into it. Every style's
vignette exists partly for that: a bright top edge behind a near-black bar makes
the bar look stuck on.

## History

An earlier set of hand-generated candidates lived here, untracked, and the
generator that made them was never committed - so when a second wallpaper was
wanted, it had to be written again from nothing. That is why the generator is
now tracked, has no dependencies beyond the standard library, and is the only
thing that produces these images.
