#!/bin/bash
# Icon font (Google Material Symbols Rounded). The font file travels with snow (files/snow/fonts), so nothing is downloaded.
# Copies it to ~/.local/share/fonts/snow and refreshes the font cache. Safe to run many times.
src="$HOME/.config/snow/fonts"
dst="$HOME/.local/share/fonts/snow"
[ -f "$src/MaterialSymbolsRounded.ttf" ] || { echo "icon font not found in $src"; exit 1; }
mkdir -p "$dst"
cp -f "$src"/MaterialSymbolsRounded.ttf "$dst"/
command -v fc-cache >/dev/null && fc-cache -f "$dst" >/dev/null 2>&1
fc-list 2>/dev/null | grep -qi "Material Symbols Rounded" && echo "icon font OK" || { echo "icon font not visible to fontconfig"; exit 1; }
