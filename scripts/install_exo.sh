#!/usr/bin/env bash
# Install the Exo configuration into ~/.config/ignis-lua.
#
#   ./scripts/install_exo.sh [--force]
#
# Copies the exo/ tree, keeps an existing user_settings.json, installs the
# default wallpaper (if missing) and prints how to start the shell.

set -euo pipefail

force=0
if [[ "${1:-}" == "--force" ]]; then
    force=1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname -- "$script_dir")"
source_dir="$repo_root/exo"
target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ignis-lua"

if [[ ! -d "$source_dir" ]]; then
    echo "error: $source_dir not found" >&2
    exit 1
fi

if [[ -e "$target_dir/config.lua" && "$force" -ne 1 ]]; then
    echo "warning: $target_dir already contains a config; re-run with --force to overwrite" >&2
    exit 1
fi

mkdir -p "$target_dir"
settings_backup=""
if [[ -f "$target_dir/user_settings.json" ]]; then
    settings_backup="$(mktemp)"
    cp "$target_dir/user_settings.json" "$settings_backup"
fi

cp -r "$source_dir/." "$target_dir/"
rm -f "$target_dir/README.md"

if [[ -n "$settings_backup" ]]; then
    cp "$settings_backup" "$target_dir/user_settings.json"
    rm -f "$settings_backup"
fi

# Exo's default wallpaper (used when no wallpaper is configured yet).
if [[ ! -f "$HOME/Pictures/Wallpapers/default.png" ]] && [[ -f "$repo_root/exo/default_wallpaper.png" ]]; then
    mkdir -p "$HOME/Pictures/Wallpapers"
    cp "$repo_root/exo/default_wallpaper.png" "$HOME/Pictures/Wallpapers/default.png"
fi

if ! fc-list 2>/dev/null | grep -qi "Material Symbols Outlined"; then
    echo
    echo "note: the 'Material Symbols Outlined' font is not installed."
    echo "      Exo renders its icons as ligatures, so without it you will only see text."
    echo "      Install it with:"
    echo "        mkdir -p ~/.local/share/fonts"
    echo "        curl -L -o ~/.local/share/fonts/MaterialSymbolsOutlined.ttf \\"
    echo "          'https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsOutlined%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf'"
    echo "        fc-cache -f"
fi

echo
echo "Exo installed to $target_dir"
echo "Start it with:"
echo "  ignis init -c $target_dir/config.lua"
echo "or, without installing IgnisLua system-wide:"
echo "  $repo_root/bin/ignis-bin init -c $target_dir/config.lua"
