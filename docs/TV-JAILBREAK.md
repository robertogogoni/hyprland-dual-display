# LG webOS 3.9.3 TV Jailbreak: PC Mode and Picture Settings

Guide for jailbreaking an LG 24TL520S-PS (or similar webOS 3.x TV) and configuring optimal picture settings for PC use over HDMI.

## TV Details

| Field | Value |
|-------|-------|
| Model | LG 24TL520S-PS |
| Type | 24-inch TV/Monitor hybrid |
| Panel PPI | ~92 (monitor-grade) |
| Firmware | 06.10.60 |
| webOS | 3.9.3 (dreadlocks2-dudhwa) |
| Serial | (redacted) |
| Physical Size | ~530x300mm |
| EDID Reported Size | 1600x900mm (incorrect, 72" equivalent) |

## Jailbreak Method

We used [rootMyTV](https://github.com/RootMyTV/RootMyTV.github.io) (v2) to jailbreak the TV. This is a browser-based exploit that works on webOS 3.x-5.x without USB or hardware access:

1. On the TV, open the built-in web browser
2. Navigate to `rootmy.tv`
3. Follow the on-screen instructions (takes about 2 minutes)
4. The TV reboots with root access and Homebrew Channel installed

**Finding the TV's IP**: Go to TV Settings > Network > Wi-Fi Connection > Advanced Settings. Or scan your network: `nmap -sn 192.168.1.0/24` and look for `LG Electronics` in the manufacturer field.

After jailbreak:

- **Root shell**: telnet at `<TV_IP>:23` (no password)
- **Homebrew Channel**: web UI at `<TV_IP>:3000`
- **SSH**: Port 22 (needs password/key setup)

## The Problem We Solved

The TV was displaying PC content with visible lag, washed-out text, and "smeary" motion. We suspected compositor or GPU issues, but the root cause was entirely on the TV side:

1. **Picture mode was Sports** (not Game as assumed). Sports mode enables the full post-processing pipeline.
2. **`pcMode` is a hidden flag** not exposed in the TV menus on this model. Without it, even Game mode leaves sharpening filters enabled.
3. **The TV was on HDMI 2**, not HDMI 1. `pcMode` must be set per-port.

## Luna API Commands

### Query current picture settings

```bash
luna-send -n 1 'luna://com.webos.settingsservice/getSystemSettings' '{"category":"picture"}'
```

Key fields to check in the response:
- `pictureMode`: should be `"game"`
- `pcMode`: should be `{"hdmi1": true, "hdmi2": true}` (set both!)
- `dynamicColor`: should be `"off"`
- `dynamicContrast`: should be `"off"`
- `edgeEnhancer`: should be `"off"`
- `superResolution`: should be `"off"`
- `noiseReduction`: should be `"off"`
- `mpegNoiseReduction`: should be `"off"`
- `energySaving`: should be `"off"`
- `dimension.input`: tells you which HDMI port is active

### Set picture mode to Game

```bash
luna-send -n 1 'luna://com.webos.settingsservice/setSystemSettings' \
  '{"category":"picture","settings":{"pictureMode":"game"}}'
```

### Enable hidden pcMode (critical!)

```bash
# Enable on ALL HDMI ports to avoid port confusion
luna-send -n 1 'luna://com.webos.settingsservice/setSystemSettings' \
  '{"category":"picture","settings":{"pcMode":{"hdmi1":true,"hdmi2":true}}}'
```

### Disable residual post-processing

Even with Game + pcMode, explicitly disable these:

```bash
luna-send -n 1 'luna://com.webos.settingsservice/setSystemSettings' \
  '{"category":"picture","settings":{"edgeEnhancer":"off","superResolution":"off"}}'
```

### Get system info

```bash
luna-send -n 1 'luna://com.webos.service.tv.systemproperty/getSystemInfo' \
  '{"keys":["modelName","firmwareVersion","sdkVersion"]}'
```

### Check current input

```bash
luna-send -n 1 'luna://com.webos.settingsservice/getSystemSettings' \
  '{"category":"picture","keys":["dimension"]}'
```

## What Each Setting Does

| Setting | Sports Mode (Before) | Game + pcMode (After) | Impact |
|---------|---------------------|----------------------|--------|
| truMotion | ON | OFF (ignored in game) | ~30ms latency added |
| dynamicContrast | high | off | Backlight modulation, text flicker |
| dynamicColor | high | off | Color saturation boost, inaccurate |
| edgeEnhancer | on | off | Sharpening halo around text |
| superResolution | medium | off | Upscaling filter, adds blur |
| noiseReduction | on | off | Temporal noise filter, adds lag |
| Total estimated lag | ~60-80ms | ~10ms (panel response only) | |

## Persistence

All settings persist in the TV's internal settings database across reboots and power cycles. You only need to run these commands once.

The jailbreak itself (Homebrew Channel, telnet root shell) also persists across reboots on webOS 3.x.

## Port Confusion Warning

When switching between DRM modes (legacy vs atomic), the AVI InfoFrames sent over HDMI change. This can cause the TV to re-evaluate which HDMI port it thinks is active. Always set `pcMode` on ALL HDMI ports to avoid this issue.

To verify which port the TV sees:
```bash
luna-send -n 1 'luna://com.webos.settingsservice/getSystemSettings' \
  '{"category":"picture","keys":["dimension"]}'
# Look for: "input": "hdmi1" or "hdmi2"
```

## i2c Notes

The HDMI DDC bus has a mystery device at i2c address `0x3a`. This is the TV's HDMI receiver IC's vendor-specific register set (not the EDID EEPROM at 0x50). Do not write to it.
