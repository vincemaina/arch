```
Arch ISO
   ↓
git clone arch-system
   ↓
./install/01-disk.sh
   ↓
./install/02-base.sh
   ↓
./install/03-system.sh
   ↓
reboot
   ↓
./install/04-desktop.sh
   ↓
chezmoi apply
   ↓
your Sway environment
```
And eventually, once we're confident in it, several of those stages can collapse into one bootstrap command.
