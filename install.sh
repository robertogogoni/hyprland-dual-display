#!/usr/bin/env bash
# Hyprland Dual Display — Modular Installer
# Backs up existing files, lets you pick which layers to install.
#
# Usage: ./install.sh              Interactive mode
#        ./install.sh --all        Install everything (still prompts for sudo)
#        ./install.sh --scripts    Install only scripts
#        ./install.sh --help       Show help

set -euo pipefail

# ── Catppuccin Mocha palette ─────────────────────────────────────────────────
RED='\033[38;2;243;139;168m'     # Red
GREEN='\033[38;2;166;227;161m'   # Green
YELLOW='\033[38;2;249;226;175m'  # Yellow
BLUE='\033[38;2;137;180;250m'    # Blue
MAUVE='\033[38;2;203;166;247m'   # Mauve
PEACH='\033[38;2;250;179;135m'   # Peach
TEXT='\033[38;2;205;214;244m'    # Text
DIM='\033[38;2;108;112;134m'    # Overlay0
BOLD='\033[1m'
NC='\033[0m'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SUFFIX=".bak.$(date +%s)"

# ── Helpers ──────────────────────────────────────────────────────────────────

header() {
    echo ""
    echo -e "  ${MAUVE}${BOLD}$1${NC}"
    echo -e "  ${DIM}$(printf '%.0s─' $(seq 1 50))${NC}"
}

ok()   { echo -e "  ${GREEN}$1${NC}"; }
info() { echo -e "  ${BLUE}$1${NC}"; }
warn() { echo -e "  ${YELLOW}$1${NC}"; }
err()  { echo -e "  ${RED}$1${NC}"; }

backup_and_copy() {
    local src="$1" dst="$2"
    if [ -f "$dst" ]; then
        cp "$dst" "${dst}${BACKUP_SUFFIX}"
        info "  Backed up $(basename "$dst")"
    fi
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    ok "  Installed $(basename "$dst")"
}

backup_and_copy_sudo() {
    local src="$1" dst="$2"
    if sudo test -f "$dst"; then
        sudo cp "$dst" "${dst}${BACKUP_SUFFIX}"
        info "  Backed up $(basename "$dst")"
    fi
    sudo mkdir -p "$(dirname "$dst")"
    sudo cp "$src" "$dst"
    ok "  Installed $(basename "$dst")"
}

# ── Preflight ────────────────────────────────────────────────────────────────

preflight() {
    local missing=()

    command -v hyprctl &>/dev/null || missing+=("Hyprland")
    command -v waybar &>/dev/null || missing+=("waybar")
    command -v python3 &>/dev/null || missing+=("python3")

    if [ ${#missing[@]} -gt 0 ]; then
        warn "Missing dependencies: ${missing[*]}"
        warn "Some features may not work without them."
        echo ""
    fi
}

# ── Module: Scripts ──────────────────────────────────────────────────────────

install_scripts() {
    header "Layer 2: Scripts"
    local dest="$HOME/.local/bin"
    local count=0
    mkdir -p "$dest"

    for script in "$REPO_DIR"/scripts/daemons/* "$REPO_DIR"/scripts/tools/*; do
        [ -f "$script" ] || continue
        local name=$(basename "$script")
        backup_and_copy "$script" "$dest/$name"
        chmod +x "$dest/$name"
        (( count++ ))
    done
    ok "  $count scripts installed to $dest"
}

# ── Module: Hyprland configs ────────────────────────────────────────────────

install_hyprland() {
    header "Layer 1: Hyprland Configs"
    local dest="$HOME/.config/hypr"

    for conf in "$REPO_DIR"/hyprland/*.conf; do
        [ -f "$conf" ] || continue
        backup_and_copy "$conf" "$dest/$(basename "$conf")"
    done
    ok "  Hyprland configs installed to $dest"
    warn "  Review monitors.conf and envs.conf for your hardware!"
}

# ── Module: Waybar configs ──────────────────────────────────────────────────

install_waybar() {
    header "Layer 1: Waybar Configs"
    local dest="$HOME/.config/waybar"

    for f in config.jsonc modules.jsonc style.css; do
        [ -f "$REPO_DIR/waybar/$f" ] && backup_and_copy "$REPO_DIR/waybar/$f" "$dest/$f"
    done
    ok "  Waybar configs installed to $dest"
    warn "  Edit config.jsonc output names for your monitors!"
}

# ── Module: Dock ────────────────────────────────────────────────────────────

install_dock() {
    header "Layer 1: Dock"
    local dest="$HOME/.config/nwg-dock-hyprland"

    if command -v nwg-dock-hyprland &>/dev/null; then
        for f in pinned.txt style.css; do
            [ -f "$REPO_DIR/dock/$f" ] && backup_and_copy "$REPO_DIR/dock/$f" "$dest/$f"
        done
        ok "  Dock config installed to $dest"
    else
        warn "  nwg-dock-hyprland not found, skipping"
    fi
}

# ── Module: System configs ──────────────────────────────────────────────────

install_system() {
    header "Layer 3: System Configs (requires sudo)"

    echo -e "  ${TEXT}This will install:${NC}"
    echo -e "  ${DIM}  /etc/tmpfiles.d/gpu-min-freq.conf${NC}"
    echo -e "  ${DIM}  /etc/sysctl.d/90-zram-tuning.conf${NC}"
    echo -e "  ${DIM}  /etc/systemd/journald.conf.d/resilient.conf${NC}"
    echo -e "  ${DIM}  /etc/modprobe.d/nvidia.conf${NC}"
    echo -e "  ${DIM}  /etc/udev/rules.d/60-ioschedulers.rules${NC}"
    echo ""

    read -rp "  Proceed? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warn "  Skipped system configs"
        return
    fi

    backup_and_copy_sudo "$REPO_DIR/system/tmpfiles.d/gpu-min-freq.conf" "/etc/tmpfiles.d/gpu-min-freq.conf"
    backup_and_copy_sudo "$REPO_DIR/system/sysctl.d/90-zram-tuning.conf" "/etc/sysctl.d/90-zram-tuning.conf"
    backup_and_copy_sudo "$REPO_DIR/system/systemd/resilient.conf" "/etc/systemd/journald.conf.d/resilient.conf"
    backup_and_copy_sudo "$REPO_DIR/system/modprobe.d/nvidia.conf" "/etc/modprobe.d/nvidia.conf"
    backup_and_copy_sudo "$REPO_DIR/system/udev/60-ioschedulers.rules" "/etc/udev/rules.d/60-ioschedulers.rules"

    ok "  System configs installed"
    warn "  Review nvidia.conf — only needed if you have an unused NVIDIA GPU"
    warn "  Run: sudo sysctl --system && sudo systemd-tmpfiles --create"
}

# ── Module: EDID ────────────────────────────────────────────────────────────

install_edid() {
    header "Layer 3: Custom EDID Firmware"

    echo -e "  ${TEXT}This installs a custom EDID for an LG 24TL520S-PS TV.${NC}"
    echo -e "  ${TEXT}Only useful if you have the same TV model (or similar LG with 1360x768 EDID).${NC}"
    echo ""
    echo -e "  ${PEACH}After install you need to:${NC}"
    echo -e "  ${DIM}  1. Add to /etc/mkinitcpio.conf FILES array${NC}"
    echo -e "  ${DIM}  2. Add drm.edid_firmware=HDMI-A-1:edid/lg-tv-1080p.bin to kernel cmdline${NC}"
    echo -e "  ${DIM}  3. sudo mkinitcpio -P && reboot${NC}"
    echo ""

    read -rp "  Install EDID firmware? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warn "  Skipped EDID"
        return
    fi

    sudo mkdir -p /usr/lib/firmware/edid
    backup_and_copy_sudo "$REPO_DIR/edid/lg-tv-1080p.bin" "/usr/lib/firmware/edid/lg-tv-1080p.bin"
    ok "  EDID firmware installed to /usr/lib/firmware/edid/"
    warn "  See edid/README.md for mkinitcpio and kernel cmdline setup"
}

# ── Module: Plugin ──────────────────────────────────────────────────────────

install_plugin() {
    header "Layer 2: split-monitor-workspaces Plugin"

    if command -v hyprpm &>/dev/null; then
        if hyprpm list 2>/dev/null | grep -q "split-monitor-workspaces"; then
            ok "  Plugin already installed"
        else
            info "  Installing split-monitor-workspaces via hyprpm..."
            hyprpm add https://github.com/Duckonaut/split-monitor-workspaces 2>&1 | while read -r line; do
                echo -e "  ${DIM}$line${NC}"
            done
            hyprpm enable split-monitor-workspaces 2>/dev/null
            ok "  Plugin installed and enabled"
        fi
    else
        warn "  hyprpm not found. Install the plugin manually:"
        warn "  hyprpm add https://github.com/Duckonaut/split-monitor-workspaces"
    fi
}

# ── Interactive menu ─────────────────────────────────────────────────────────

interactive_menu() {
    echo ""
    echo -e "  ${MAUVE}${BOLD}Hyprland Dual Display${NC}  ${DIM}v1.0.0${NC}"
    echo -e "  ${DIM}$(printf '%.0s─' $(seq 1 50))${NC}"
    echo ""
    echo -e "  ${TEXT}Select modules to install:${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} ${TEXT}Scripts${NC}      ${DIM}Workspace daemons + tools to ~/.local/bin/${NC}"
    echo -e "  ${GREEN}[2]${NC} ${TEXT}Hyprland${NC}     ${DIM}Dual-display configs to ~/.config/hypr/${NC}"
    echo -e "  ${GREEN}[3]${NC} ${TEXT}Waybar${NC}       ${DIM}Dual-bar config + styling to ~/.config/waybar/${NC}"
    echo -e "  ${GREEN}[4]${NC} ${TEXT}Dock${NC}         ${DIM}nwg-dock-hyprland config${NC}"
    echo -e "  ${GREEN}[5]${NC} ${TEXT}System${NC}       ${DIM}GPU/swap/journald configs to /etc/ (sudo)${NC}"
    echo -e "  ${GREEN}[6]${NC} ${TEXT}EDID${NC}         ${DIM}Custom EDID firmware (sudo + reboot)${NC}"
    echo -e "  ${GREEN}[7]${NC} ${TEXT}Plugin${NC}       ${DIM}Install split-monitor-workspaces via hyprpm${NC}"
    echo -e "  ${GREEN}[a]${NC} ${TEXT}All${NC}          ${DIM}Install everything${NC}"
    echo -e "  ${GREEN}[q]${NC} ${TEXT}Quit${NC}"
    echo ""

    read -rp "  Choose [1-7/a/q]: " choice

    case "$choice" in
        1) install_scripts ;;
        2) install_hyprland ;;
        3) install_waybar ;;
        4) install_dock ;;
        5) install_system ;;
        6) install_edid ;;
        7) install_plugin ;;
        a|A)
            install_scripts
            install_hyprland
            install_waybar
            install_dock
            install_plugin
            install_system
            install_edid
            ;;
        q|Q)
            echo -e "  ${DIM}Bye!${NC}"
            exit 0
            ;;
        *)
            warn "  Invalid choice. Try again."
            interactive_menu
            return
            ;;
    esac

    echo ""
    read -rp "  Install more? [y/N] " again
    [[ "$again" =~ ^[Yy]$ ]] && interactive_menu
}

# ── CLI interface ────────────────────────────────────────────────────────────

main() {
    preflight

    case "${1:-}" in
        --all)
            install_scripts
            install_hyprland
            install_waybar
            install_dock
            install_plugin
            install_system
            install_edid
            ;;
        --scripts)  install_scripts ;;
        --hyprland) install_hyprland ;;
        --waybar)   install_waybar ;;
        --dock)     install_dock ;;
        --system)   install_system ;;
        --edid)     install_edid ;;
        --plugin)   install_plugin ;;
        --help|-h)
            echo "Hyprland Dual Display Installer"
            echo ""
            echo "Usage: ./install.sh [option]"
            echo ""
            echo "Options:"
            echo "  (none)      Interactive menu"
            echo "  --all       Install everything"
            echo "  --scripts   Install workspace scripts only"
            echo "  --hyprland  Install Hyprland configs only"
            echo "  --waybar    Install Waybar configs only"
            echo "  --dock      Install dock config only"
            echo "  --system    Install system configs only (sudo)"
            echo "  --edid      Install EDID firmware only (sudo)"
            echo "  --plugin    Install hyprpm plugin only"
            echo "  --help      Show this help"
            exit 0
            ;;
        "")
            interactive_menu
            ;;
        *)
            err "Unknown option: $1"
            echo "Use --help for usage"
            exit 1
            ;;
    esac

    echo ""
    ok "  Done! Restart Hyprland to apply changes."
    echo ""
}

main "$@"
