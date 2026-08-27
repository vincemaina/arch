# Vendored yazi plugins

Everything in this directory is **third-party code, tracked in this repository
on purpose**. It is not written here and it is not fetched here.

## Why it is vendored rather than fetched

yazi's own package manager installs a plugin with

    ya pkg add yazi-rs/plugins:mount

which clones from GitHub at the moment it runs. A fresh install of this system
runs from a live ISO through `arch-chroot`, applying dotfiles from
`/opt/arch-setup` — a copy of `setup/` and nothing else. There is no clone step
there and no guarantee of a network. A plugin fetched at install time is a
plugin that is sometimes absent, and an absent plugin fails the way everything
else in this repository has failed: silently. `M` would simply do nothing.

So the code is committed, chezmoi deploys it like any other dotfile, and the
build stays reproducible from the repository alone. `../package.toml` is
tracked for the same reason — it is `ya pkg`'s own manifest, so the versions
below are machine-readable as well as written down here.

## What is here

| Plugin | Upstream | Revision | Dated |
| --- | --- | --- | --- |
| `mount.yazi` | [yazi-rs/plugins](https://github.com/yazi-rs/plugins) | `c591a36` | 2026-08-25 |

`mount.yazi` is MIT-licensed; its `LICENSE` travels with it. It needs
`udisksctl` (udisks2, declared in `setup/packages/desktop.txt`), plus `lsblk`
and `eject` from util-linux in base.

## How to update one

Do it **in the repository**, not on the machine — `chezmoi apply` would revert
an upgrade made in place, which is the intended direction of travel.

```bash
# Fetch the new version into a scratch config, leaving your own alone.
mkdir -p /tmp/yazi-pkg
YAZI_CONFIG_HOME=/tmp/yazi-pkg ya pkg add yazi-rs/plugins:mount

# Copy the result over the vendored copy and the manifest.
cd "$(git rev-parse --show-toplevel)"
cp /tmp/yazi-pkg/plugins/mount.yazi/*.lua \
   /tmp/yazi-pkg/plugins/mount.yazi/LICENSE \
   setup/dotfiles/dot_config/yazi/plugins/mount.yazi/
cp /tmp/yazi-pkg/package.toml setup/dotfiles/dot_config/yazi/package.toml

# Update the revision in the table above, then apply and check.
./sync.sh && ./checks/session.sh
```

`YAZI_CONFIG_HOME` is what keeps this off your real `~/.config/yazi` — without
it, `ya pkg` writes straight into the directory chezmoi owns and the next
`sync.sh` reports drift you did not mean to create.

Read the upstream diff before committing it. This is someone else's code
running in your file manager, and `mount.yazi` in particular shells out to
`udisksctl` and can invoke `sudo` on the fallback path in `sudo.lua`.
