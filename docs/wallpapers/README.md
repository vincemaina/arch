# Wallpapers

Wallpapers are **generated from a theme's own colours** by `tools/wallpaper.py`,
not chosen. Each theme in `.chezmoidata/themes.toml` names its image, the tool
renders it, and the result is committed into `setup/dotfiles/` so it reaches the
built machine like any other dotfile.

```bash
tools/wallpaper.py --all                      # regenerate every theme
tools/wallpaper.py --theme ember              # just one
tools/wallpaper.py --theme slate --out /tmp/x.png   # preview without committing
```

Standard library only, deliberately: the first version of this generator needed
numpy and Pillow, was never committed, and was gone by the time a second
wallpaper was wanted. That is why this file describes a tool rather than a set
of candidate images.

## Why generated

The bar, the borders and the glow were all tuned to sit against the background.
A palette swap that left the old picture behind would clash with itself, and a
hand-picked image per theme is one more thing to keep in step. Deriving the
image from the colours the rest of the desktop already reads means a new theme
gets a matching background for free.

The composition is identical across themes - the same soft fields in the same
places, domain-warped so the shapes are organic rather than circular - and only
the colours change. Three unrelated pictures would look like three different
desktops rather than one desktop wearing three palettes.

## Note

The bar has a solid dark background, so it reads as a dark strip across the top
of whichever image is showing rather than blending into it. The generator's
vignette exists partly for that: a bright top edge behind a near-black bar makes
the bar look stuck on.

## History

An earlier set of hand-generated candidates lived here, untracked. The first
set was near-black and very subtle - too subtle, as it turned out, and rejected
as lifeless. The purple set that replaced it produced `06-deep-violet.png`,
which was the wallpaper until themes arrived and it became `neon.png`.
