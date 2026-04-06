# Keybindings Reference

All custom keybindings for the dual-display workspace system.

## Workspaces (Smart Auto-Sort)

```
Laptop (eDP-1):  L1=Dev  L2=Chat  L3=Work  L4=Games  L5=System
TV (HDMI-A-1):   T1=Web  T2=Media T3=Ref   T4=Files  T5=Extra
```

| Keybinding | Action |
|------------|--------|
| `Super + 1-5` | Switch workspace (context-dependent on focused monitor) |
| `Super + Shift + 1-5` | Move window to workspace |
| `Super + Tab` | Next workspace |
| `Super + Shift + Tab` | Previous workspace |
| `Super + Ctrl + Tab` | Last visited workspace |
| `Super + Shift + F1` | Reorganize all windows to correct workspaces |

## Windows

| Keybinding | Action |
|------------|--------|
| `Super + Arrows` | Move focus |
| `Super + Shift + Arrows` | Swap window positions |
| `Super + J` | Toggle split direction |
| `Super + T` | Toggle floating |
| `Super + F` | Fullscreen |
| `Super + W` | Close window |
| `Super + O` | Pop out (float + pin on top) |
| `Super + -` / `Super + =` | Resize window |
| `Alt + Tab` | Cycle windows |

## Scratchpads (Pyprland)

| Keybinding | Action |
|------------|--------|
| `Super + A` | Dropdown terminal (Quake-style) |
| `Super + Ctrl + B` | System monitor (btop) |
| `Super + Ctrl + E` | File explorer (floating) |
| `Super + Ctrl + M` | Music player (Spotify) |
| `Super + Ctrl + N` | Quick notes (Obsidian) |

## Focus and Zen

| Keybinding | Action |
|------------|--------|
| `Super + F2` | Focus mode (fullscreen + disable 2nd monitor) |
| `Super + F3` | Zen mode (zero-chrome fullscreen + blank other) |
| `Super + Z` | Toggle 2x zoom (magnify) |
| `Super + Shift + Z` | Zoom in more (+0.5x) |

## Tools

| Keybinding | Action |
|------------|--------|
| `Super + V` | Clipboard history (rofi) |
| `Print` | Screenshot (omarchy default) |
| `Shift + Print` | Screenshot + annotate (grim + slurp + swappy) |
| `Super + Ctrl + S` | Swap monitors (shift workspaces) |
| `Super + F1` | Keybinding cheat sheet (floating terminal) |

## Launch

| Keybinding | Action |
|------------|--------|
| `Super + Enter` | Terminal |
| `Super + Shift + Enter` | Browser |
| `Super + Shift + F` | File manager |
| `Super + Shift + N` | Editor |
| `Super + Shift + O` | Obsidian |
| `Super + Shift + /` | Passwords |

## Waybar Interactions

| Click Target | Action |
|-------------|--------|
| Pomodoro timer | Start/stop 25-minute timer |
| AI Usage | Open usage TUI |
| Sync Status | Open sync dashboard |
| Now Playing | Play/pause, right-click: next |
| CPU | Open btop |
