# Custom EDID for LG 24TL520S-PS TV

## The Problem

The TV's factory EDID has four defects that cause Linux display stacks to select 1360x768 instead of 1920x1080:

### Smoking Gun 1: Wrong preferred mode
DTD 1 (the "preferred" timing per EDID spec) is `1360x768@60Hz` (85.5 MHz), not `1920x1080@60Hz`. Linux DRM/KMS honors DTD 1 as the preferred mode, so every compositor starts at 768p.

### Smoking Gun 2: Wrong native flag
VIC 19 (`1280x720@50Hz`) is marked as native in the CTA-861 Video Data Block. VIC 16 (`1920x1080@60Hz`) exists but without the native bit. Some display stacks use the native VIC as a tiebreaker.

### Smoking Gun 3: 1080p buried in last DTD position
The 1080p timing exists as DTD 6 (the very last detailed timing). Mode-switch from DTD 1 to DTD 6 requires the compositor to resize framebuffers, which triggers bugs in aquamarine's atomic test-commit path.

### Smoking Gun 4: Marginal TMDS headroom
HDMI VSDB reports TMDS max of 150 MHz. 1080p@60Hz needs 148.5 MHz (only 1.0% headroom). Some drivers add safety margins and reject modes too close to the max.

## Community Comparison

We compared against 815 GSM0001 entries in the [linuxhw/EDID](https://github.com/linuxhw/EDID) community database:

| Field | This TV (2017) | Typical LG TV (2022) | Older LG TV (2010) |
|-------|---------------|---------------------|-------------------|
| DTD 1 (preferred) | 1360x768@60Hz | 1920x1080@60Hz | 1920x1080@60Hz |
| Max TMDS | 150 MHz | not specified | 225 MHz |
| 1360x768 present? | YES (preferred!) | NO | NO |

This TV is an outlier. 542 of 815 entries have the same 1360x768 problem, suggesting a firmware bug across an entire product line.

## What We Modified

| # | Change | Before | After |
|---|--------|--------|-------|
| 1 | DTD 1 | 1360x768@60Hz | 1920x1080@60Hz |
| 2 | DTD 6 | 1920x1080@60Hz | 1360x768@60Hz |
| 3 | Physical size (all DTDs) | 1600x900mm | 530x300mm |
| 4 | TMDS max clock | 150 MHz (0x1E) | 165 MHz (0x21) |
| 5 | VIC 16 native flag | off | on |
| 6 | VIC 19 native flag | on | off |
| 7 | Block checksums | recalculated | recalculated |

## The Binary

`lg-tv-1080p.bin` is a 256-byte EDID binary (2 blocks: base + CTA-861 extension).

```
SHA-256: c5c0b4184279990e6694366f22be0d5d3852d8ed57ccb8daa5bd9f94faf0a569
```

Validate with:
```bash
edid-decode lg-tv-1080p.bin
```

Expected output should show:
- DTD 1: `1920x1080 60.000000 Hz 16:9 67.500 kHz 148.500000 MHz (530 mm x 300 mm)`
- VIC 16 marked as `(native)`
- Maximum TMDS clock: `165 MHz`

## Deployment

### 1. Copy the EDID firmware
```bash
sudo mkdir -p /usr/lib/firmware/edid
sudo cp lg-tv-1080p.bin /usr/lib/firmware/edid/
```

### 2. Add to initramfs
Edit `/etc/mkinitcpio.conf`:
```
FILES=(/usr/lib/firmware/edid/lg-tv-1080p.bin)
```

### 3. Add kernel parameter
For systemd-boot, edit your loader entry:
```
options ... drm.edid_firmware=HDMI-A-1:edid/lg-tv-1080p.bin
```

For GRUB, edit `/etc/default/grub`:
```
GRUB_CMDLINE_LINUX_DEFAULT="... drm.edid_firmware=HDMI-A-1:edid/lg-tv-1080p.bin"
```

### 4. Rebuild and reboot
```bash
sudo mkinitcpio -P
sudo reboot
```

### 5. Verify
```bash
edid-decode /sys/class/drm/card*-HDMI-A-1/edid | grep "DTD 1"
# Should show 1920x1080
```

## Recovery

**Zero bricking risk.** The TV's EEPROM is never modified. This override only affects what the kernel sees.

To revert:
1. Remove `drm.edid_firmware=...` from kernel parameters
2. Remove the `FILES=` entry from mkinitcpio.conf
3. `sudo mkinitcpio -P && sudo reboot`

The TV will revert to its factory EDID (1360x768 preferred).

## CEA-861 1080p DTD Reference

The standard 1920x1080@60Hz DTD bytes per CEA-861:
```
02 3a 80 18 71 38 2d 40 58 2c 45 00
```

Breakdown:
- Pixel clock: 148.5 MHz (0x3A02 x 10kHz, little-endian)
- H active: 1920, H blanking: 280
- V active: 1080, V blanking: 45
- H front porch: 88, H sync: 44
- V front porch: 4, V sync: 5
