# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [1.0.0] - 2026-04-06

### Layer 1: Dual Display Setup
- Dual-output waybar config (26px laptop, 38px TV) with shared modules
- Per-output CSS targeting via `window#waybar.tv *` selector
- DPI-based scaling: integer scales + DPI overrides for GTK and Qt
- Blur disabled, direct scanout enabled, fast animations (1-3ms)
- nwg-dock-hyprland auto-hide dock on laptop bottom edge
- Catppuccin-themed workspace buttons with per-position colors

### Layer 2: Smart Workspace System
- `hypr-smart-workspace`: Auto-categorize windows across 10 workspaces (306 lines)
- `hypr-monitor-handler`: Migrate windows on HDMI connect/disconnect (158 lines)
- `hypr-activity-pulse`: Flash waybar workspace buttons on background activity (158 lines)
- `hypr-workspace-icons`: Dynamic Nerd Font icons per workspace (191 lines)
- `hypr-zen-mode`: Zero-chrome distraction-free mode
- `hypr-focus-mode`: Fullscreen + disable secondary monitor
- `hypr-cheatsheet`: Color-coded keybinding reference
- `hypr-pomodoro`: 25-minute waybar timer with notification
- `hypr-reorganize`: Batch re-sort all windows (149 lines)
- `hypr-test-resolution`: Safe resolution test with auto-revert
- `split-monitor-workspaces` plugin config (5 per monitor)

### Layer 3: Display Forensics
- Custom EDID binary (256 bytes, 7 modifications) for LG 24TL520S-PS
- EDID deployment via kernel firmware override (initramfs + cmdline)
- Aquamarine UAF crash fix documentation (PR #244)
- GPU min frequency pinning at 600 MHz via tmpfiles.d
- zram-optimized VM tunables (swappiness=150, page-cluster=0)
- journald memory limits to prevent crash cascades
- NVIDIA blacklist for unused Kepler GPU
- BFQ I/O scheduler for spinning disks

### Layer 4: TV Jailbreak
- webOS 3.9.3 jailbreak guide with Luna API reference
- Hidden pcMode discovery and per-port configuration
- Full post-processing disable (TruMotion, dynamicContrast, edgeEnhancer, etc.)
- HDMI port confusion diagnosis and fix

### Documentation
- Full debugging timeline (TIMELINE.md)
- EDID analysis with community comparison against 815 entries (edid/README.md)
- TV jailbreak and Luna API reference (TV-JAILBREAK.md)
- Complete keybinding reference (KEYBINDINGS.md)
