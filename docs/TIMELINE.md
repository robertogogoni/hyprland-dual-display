# Debugging Timeline

A detailed chronological account of every diagnosis, dead end, and breakthrough.

## March 17, 2026: Initial Setup

**Problem:** Blurry, oversized UI on the 1366x768 laptop panel.

**Root cause:** Omarchy's default `monitors.conf` set `GDK_SCALE=2` (retina preset). Combined with fractional `QT_SCALE_FACTOR=0.75`, GTK apps rendered at 1.5x effective scale and Qt at 0.75x. Both fractional, both blurry.

**Fix:** Integer scales everywhere + DPI-based sizing:
```
GDK_SCALE=1, GDK_DPI_SCALE=0.85    # GTK: 85% via DPI, not buffer scaling
QT_SCALE_FACTOR=1, QT_WAYLAND_FORCE_DPI=80  # Qt: ~83% via DPI override
```

**Insight:** Fractional buffer scaling resamples at the compositor level. DPI overrides let the toolkit render at native resolution with smaller widget/font metrics. Zero blur, compact UI.

Also configured:
- VA-API hardware decode via `i965` driver
- BFQ I/O scheduler for the spinning HDD
- NVIDIA GPU blacklisted (Kepler-era 710M, weaker than the iGPU)

## March 28, 2026: System Tuning

**Problem:** System hitting 100% zram swap with only 303MB free RAM. Chrome Canary running 34 renderer processes consuming 6.4GB.

**Fixes applied:**
- zram VM tunables: `swappiness=150`, `vfs_cache_pressure=150`, `page-cluster=0`
- 4GB disk swap overflow at `/swap/swapfile` (btrfs subvolume, priority 10 vs zram priority 100)
- Removed 104.6GB of stale AUR build caches (electron25 alone: 101GB)
- Removed broken `nvidia-open-dkms` (GF117M not supported), switched mkinitcpio to `i915` only
- Regenerated initramfs

## April 4, 2026: The Crash Loop

### 2:00 AM: The crash

System found in a crash loop: 6 boots, 2 hard crashes, journald corruption. Pieced together from fragmented journal entries across multiple boot IDs.

### 10:00 AM: Diagnosis begins

**Crash 1: aquamarine UAF**

Stack trace (reconstructed from coredump):
```
#0 SDRMConnector::disconnect()
#1 CLogger::log()  ← called through dangling pointer
#2 SEGV
```

`hypridle` sent DPMS-off to the TV (HDMI-A-1). This triggered `SDRMConnector::disconnect()` in aquamarine. But the `CLogger` singleton had already been destroyed in a previous teardown. Use-after-free.

Fix: `aquamarine` PR #244 (merged upstream but not yet in a release). Rebuilt from `main` at commit `e926559`:
```bash
git clone https://github.com/hyprwm/aquamarine
cd aquamarine && git checkout e926559
cmake -B build && cmake --build build
sudo cp build/libaquamarine.so.9 /usr/lib/
```

Pinned in pacman to prevent regression: `IgnorePkg = aquamarine`

**Crash 2: journald memory cascade**

journald hit memory pressure (8GB system, Chrome eating 6.4GB). The OOM situation triggered:
1. journald watchdog timeout, SIGKILL
2. D-Bus service disrupted
3. `upower` segfault (battery monitor lost D-Bus)
4. cascading service failures

Fix: `/etc/systemd/journald.conf.d/resilient.conf` with `SystemMaxUse=256M, RuntimeMaxUse=64M`

**Crash 3: hypridle DPMS wakes**

The TV (LG via HDMI) doesn't properly wake from DPMS-off. HDMI CEC and DPMS have impedance mismatches on this TV model. `hypridle` kept trying to put the TV to sleep, TV failed to wake, triggering the UAF bug in aquamarine.

Fix: Stopped, disabled, and **masked** `hypridle`:
```bash
systemctl --user stop hypridle
systemctl --user disable hypridle
systemctl --user mask hypridle  # symlink to /dev/null
```

### 2:00 PM: The 1080p quest begins

TV is alive at 1360x768 (its EDID preferred mode). We want 1080p.

**Dead end #1: TMDS clock limitation**

Initial theory: TV's TMDS max of 150 MHz is too close to 1080p's 148.5 MHz requirement (1.5 MHz headroom). Maybe the GPU or TV is rejecting it on marginal timing.

Research showed: Haswell source max is 300 MHz, TV sink max 150 MHz, 1080p needs 148.5 MHz. Passes validation. Clock is not the problem.

**Dead end #2: Missing HDMI mode in connector**

Checked `xrandr` and `hyprctl monitors` output. 1080p@60Hz was listed as an available mode. The mode itself was fine.

**Breakthrough: kernel DRM trace**

Added DRM debug tracing:
```
[drm:intel_plane_check_clipping] [PLANE:50:primary B] 
  plane (1360x768+0+0) must cover entire CRTC (1920x1080+0+0)
```

The atomic test-commit was sending the primary plane at the OLD dimensions (1360x768) while requesting the NEW CRTC mode (1920x1080). The kernel correctly rejected it: the primary plane must cover the full CRTC area.

This is an aquamarine bug: it should resize the primary plane before (or during) the atomic test-commit.

**Workaround:** `AQ_NO_ATOMIC=1` to bypass atomic test-commit and use the legacy DRM `drmModeSetCrtc()` path. The legacy path doesn't validate plane coverage.

Also set `AQ_NO_MODIFIERS=1` to force LINEAR DRM buffers (tiled buffers caused additional issues on the legacy path).

After reboot: **TV at 1920x1080@60Hz.**

### 4:00 PM: EDID analysis

Dumped the raw EDID from `/sys/class/drm/card1-HDMI-A-1/edid`:

```
DTD 1 (preferred): 1360x768@60Hz   ← THIS IS THE PROBLEM
DTD 2: 1024x768@60Hz               ← wasted slot
...
DTD 6: 1920x1080@60Hz              ← correct but last position
```

Four smoking guns identified (see `edid/README.md` for full analysis).

Community comparison against 815 other GSM0001 entries from linuxhw/EDID confirmed this TV is an outlier. Even a 2010 LG TV reports 1080p preferred.

### 6:00 PM: Workspace ecosystem built

With dual displays working, built the complete workspace automation:
- `split-monitor-workspaces` plugin (5 per monitor)
- Smart categorization daemon
- Monitor handler daemon
- Activity pulse daemon
- Waybar dual-bar config
- 6 utility scripts

### 8:00 PM: Rendering tuning

TV text looked "washed out" and animations felt laggy despite 1080p working.

**What we tried:**
- Disabled blur globally (was eating a full-screen shader pass per frame)
- Pinned GPU min freq to 600 MHz
- Faster animation durations
- Tried `hintfull` + `rgba` subpixel font rendering: WRONG for TV panels

**What we learned:** TV panels don't have standard RGB subpixel layouts. `rgba` mode causes color fringing. Reverted to `hintslight` + grayscale.

**What we didn't know yet:** The real lag source was on the TV side, not the GPU.

## April 5, 2026: The Jailbreak

### 10:00 AM: Custom EDID deployed

Built the custom EDID binary:
1. Swapped DTD 1 (1360x768) with DTD 6 (1920x1080)
2. Fixed physical size from 1600x900mm to 530x300mm in all DTDs
3. Bumped TMDS max from 150 to 165 MHz
4. Set VIC 16 (1080p@60Hz) as native instead of VIC 19 (720p@50Hz)
5. Recalculated checksums

Deployed via kernel firmware override and baked into initramfs. After reboot: 1080p from the very first frame.

**Critical result:** With the custom EDID, aquamarine allocates a 1080p framebuffer from the start. No mode-switch needed. The atomic test-commit plane size bug is completely avoided.

Removed `AQ_NO_ATOMIC=1`. Atomic DRM modesetting now works perfectly.

### 12:00 PM: TV jailbreak

Jailbroke the TV using the webOS community exploit:
- Root shell via telnet at `<TV_IP>:23`
- Homebrew Channel on port 3000

Queried picture settings and discovered the **real** source of the lag:

**The TV was on Sports mode, not Game mode.** Sports mode had:
- `truMotion`: ON
- `dynamicContrast`: high
- `dynamicColor`: high
- `edgeEnhancer`: on
- `superResolution`: medium
- `noiseReduction`: on

Every one of these adds latency and destroys text clarity.

### 1:00 PM: Hidden pcMode

Set `pictureMode` to `game` via Luna API. Better, but not perfect.

Discovered `pcMode`: a hidden per-HDMI-port flag not exposed in the TV menus on this model. Without it, even Game mode leaves `edgeEnhancer` and `superResolution` enabled.

### 2:00 PM: The port confusion

Enabled `pcMode` on HDMI 1. User reported regression: "it was better before."

Queried `dimension.input`: the TV reported `hdmi2`. We'd been assuming HDMI 1 all along. The switch from legacy DRM (AQ_NO_ATOMIC) to atomic DRM changed the AVI InfoFrames sent to the TV, which may have caused it to re-evaluate its input/port mapping.

**Fix:** Enabled `pcMode` on both HDMI 1 and HDMI 2. Explicitly disabled `edgeEnhancer` and `superResolution`.

User confirmed: "way better."

### 3:00 PM: Final cleanup

Removed `AQ_NO_MODIFIERS=1`. Tiled GPU buffers and framebuffer compression now active.

**Final state:** Clean boot, dual display, 1080p from kernel, atomic DRM, tiled buffers, zero post-processing on TV, 10 custom workspace scripts. Everything working.

## Bugs Filed / Referenced

| Issue | Status | Description |
|-------|--------|-------------|
| aquamarine #244 | Merged | UAF fix in CLogger/SDRMConnector |
| aquamarine #59 | Open | Atomic test-commit plane size bug |
| Hyprland #6953 | Open | Mode-switch failure on HDMI |
| Hyprland #8758 | Open | Related atomic DRM issues |

## Dead Ends (for future reference)

1. **TMDS clock limitation**: Not the cause. 148.5 MHz is within the 150 MHz max.
2. **Font rendering with rgba subpixel**: Wrong for TV panels. Use grayscale.
3. **GPU min frequency as smoothness fix**: Helped marginally, but the real lag was TV-side.
4. **Blur reduction (passes=1 instead of 2)**: Still too expensive. Had to disable entirely.
5. **pcMode on HDMI 1 only**: TV was actually on HDMI 2.
