#!/usr/bin/env bash
# scripts/setup_arch.sh
# Native dependency installer and C11 engine builder for Arch Linux & Arch-based distros
# (Arch, CachyOS, EndeavourOS, Garuda, Manjaro)

set -euo pipefail

if ! command -v pacman >/dev/null 2>&1; then
    echo "[ERROR] pacman not found. This script is designed for Arch-based distributions."
    exit 1
fi

OFFICIAL_PKGS=(
    lua
    lua-lgi
    gtk4
    gtk4-layer-shell
    glib2
    gobject-introspection
    gdk-pixbuf2
    librsvg
    pango
    cairo
    dart-sass
    upower
    power-profiles-daemon
    networkmanager
    libnm
    gnome-bluetooth-3.0
    brightnessctl
    pkgconf
    base-devel
)

AUR_PKGS=(
    ignis-gvc
    gpu-screen-recorder
)

echo "[INFO] Installing official Arch Linux repository dependencies via pacman..."
sudo pacman -S --needed "${OFFICIAL_PKGS[@]}"

AUR_HELPER=""
if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
fi

if [ -n "$AUR_HELPER" ]; then
    echo "[INFO] Installing optional AUR packages (${AUR_PKGS[*]}) via ${AUR_HELPER}..."
    "$AUR_HELPER" -S --needed "${AUR_PKGS[@]}" || echo "[WARN] Optional AUR package installation skipped."
else
    echo "[INFO] No AUR helper (paru/yay) detected. Building ignis-gvc from source..."
    if [ ! -f "/usr/lib/ignis-gvc/Gvc-1.0.typelib" ]; then
        sudo pacman -S --needed meson ninja libpulse
        TMP_GVC=$(mktemp -d)
        git clone --depth 1 https://github.com/ignis-sh/ignis-gvc.git "$TMP_GVC/ignis-gvc"
        meson setup "$TMP_GVC/ignis-gvc/build" "$TMP_GVC/ignis-gvc" --prefix=/usr
        meson compile -C "$TMP_GVC/ignis-gvc/build"
        sudo meson install -C "$TMP_GVC/ignis-gvc/build"
        rm -rf "$TMP_GVC"
    fi
fi

echo "[INFO] Compiling IgnisLua C11 native engine (ignis/native.so and bin/ignis-bin)..."
make native

echo "[INFO] Arch Linux setup complete."
echo "  - Run directly:      ./bin/ignis-bin init -c examples/bar/config.lua"
echo "  - Install package:   makepkg -si   (or: sudo make install)"
echo "  - Enable service:    systemctl --user enable --now ignis.service"
