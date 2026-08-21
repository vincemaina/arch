---
id: TASK-27
title: Document every tool the setup chooses
status: In Progress
assignee: []
created_date: '2026-08-19 19:17'
updated_date: '2026-08-21 20:37'
labels:
  - repo
  - documentation
dependencies: []
priority: medium
type: docs
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
DECISIONS.md covers the large architectural choices well - Arch, Btrfs, Sway, systemd-boot - but coverage thins out for the individual tools the system actually runs on, and newer additions are being recorded to a higher standard than older ones. The result is uneven: some tools have a full rationale, others appear only as a line in a package manifest with no record of what they do or why they were picked.

Every tool this setup installs should be documented to the same standard, so that a choice can be re-evaluated later without rediscovering the reasoning from scratch, and so that nothing sits in the system purely because it was added once and never questioned.

For each tool: the problem it solves, why it was chosen over the alternatives, what those alternatives were, how it actually works in enough detail to debug it, and what it costs in memory and CPU. Cost matters here specifically - the setup targets a small idle footprint, and a tool that is cheap on a 16 GB machine may not be on a small VM.

earlyoom is the worked example: what problem low-memory handling solves, how watching MemAvailable differs from the kernel OOM killer, why that behaves better alongside zram, what it costs to run, and how systemd-oomd and nohang compare.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Every package in setup/packages/ is either documented or explicitly noted as a dependency needing no rationale of its own
- [ ] #2 Each documented tool covers the problem it solves, why it was chosen, the alternatives rejected, and its resource cost
- [x] #3 Resource figures are measured on this system rather than quoted from elsewhere
- [x] #4 The documentation is structured so a future addition has an obvious place and format to follow
- [ ] #5 Existing DECISIONS.md entries are brought up to the same standard rather than left as a second tier
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Read setup/packages/*.txt and DECISIONS.md first and deliberately did not restate either. DECISIONS.md is 1886 lines and already carries the 'why' for most of the set; the manifests carry the rest next to the line. What genuinely did not exist anywhere was (a) a complete roll call, so nothing could be silently unaccounted for, and (b) any measured resource figure at all. Wrote docs/software/README.md to be that fourth thing rather than a fifth copy.

AC#1 (done): all 91 declared packages appear exactly once in the roll-call tables, verified by script against the manifests — 0 missing, 0 invented, 0 duplicated. Each row says where its rationale lives: a DECISIONS.md section, the manifest comments, or an entry below. Every DECISIONS.md section name referenced was checked against the actual headings.

AC#3 (done): every figure measured on this machine on 2026-08-21 and labelled with the machine it came from — a KVM guest, 4 vCPU of an i7-10700, 3.8 GiB RAM, kernel 7.1.8, software rendering. Method documented so it can be re-run: pacman -Qi for disk, systemd's MemoryCurrent/CPUUsageNSec/ActiveEnterTimestampMonotonic for per-unit memory and long-run CPU, /proc/PID/smaps_rollup for PSS. Caveats stated (cgroup totals include page cache; CPU is cumulative; smaps_rollup is root-only for the compositor and root daemons, so those rows use ps RSS and overstate).
  Headline numbers: earlyoom 1.0 MiB / 0.004% of a core — the worked example the ticket asked for, and the number that settles the argument. sway 143.8 MiB RSS / 5.2%, roughly as much as the rest of the session combined, and on this machine that is llvmpipe rather than the compositor. 1.13 GiB on disk over the 90 declared packages installed, of which 456 MiB (39%) is fonts and icons — which is not visible from reading the manifests and is the first place to look to shrink the install.

AC#4 (done): a five-heading entry format is specified up front (Problem / Choice / Alternatives / How it works / Cost), with the explicit instruction that 'nothing was compared, it was the obvious package' is a valid and preferable answer to inventing one after the fact.

AC#2 partially: the entries written cover all five headings. Left unchecked because for roughly a dozen packages no alternative was ever recorded and I refused to manufacture one — that is called out per entry and again in a closing 'gaps this document does not close' section. Filling those in needs the person who chose them.

AC#5 NOT done, and blocked rather than skipped: DECISIONS.md was outside this session's permitted edit surface. The concrete finding to act on there is that '## Wofi' is stale — wofi is in no manifest, rofi replaced it, and DECISIONS.md is the first place a reader would look for the launcher rationale.

Two errors caught by checking against the running system rather than assuming, both worth keeping:
  * A first draft of the cost table claimed several daemons used 17 GB on a 3.8 GB machine. Cause: 'systemctl show -p A -p B -p C --value' returns properties in systemd's order, not the order asked for, so reading them positionally transposes them. The document now says to ask for each property separately.
  * A first draft explained brightnessctl as working through udev rules granting the video group access. That is false here: pacman -Ql brightnessctl is seven lines — binary and man page only, no udev rule, no setuid, no capability — and this user is in no video group. It links libsystemd and calls logind's SetBrightness on org.freedesktop.login1.Session. Corrected, and the /sys/class/backlight/ directory on this VM is empty, so the brightness bindings do nothing here at all.

Other findings recorded in the document: network-manager-applet and xdg-user-dirs are started by XDG autostart entries their own packages ship, not by anything in this repository — so nm-applet costs 9.8 MiB resident for a tray applet on a desktop with no tray, which is the one cost here that looks worth re-opening. pacman-contrib is on the built machine for pactree, which only the repository's own checks use, which is a real exception to the setup/ boundary in CLAUDE.md and is stated as one.

The manifests changed under this work mid-session (thunar removed, dust added, gvfs re-justified); the tables were re-derived against the current files afterwards and re-verified at 91/91.

Verification: ./checks/session.sh — 75 passed, 0 failed, 0 skipped. Link check across all 13 markdown files — 0 broken.
<!-- SECTION:NOTES:END -->
