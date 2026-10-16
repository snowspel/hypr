#!/usr/bin/env python3
# Makes the dark or light version of a theme (same hue and same accent color).
#   use: theme-variant.py <theme.json> dark|light     prints a theme JSON
import sys, json, colorsys

src = json.load(open(sys.argv[1]))
mode = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] in ("dark", "light") else "dark"

def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

def hexc(r, g, b):
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))

def hls(h, l, s):
    return hexc(*colorsys.hls_to_rgb(h % 1.0, max(0, min(1, l)), max(0, min(1, s))))

bh, bl, bs = colorsys.rgb_to_hls(*rgb(src["bg"]))
ah, al, as_ = colorsys.rgb_to_hls(*rgb(src["accent"]))
bs = min(max(bs, 0.08), 0.30)          # keep the tint of the background, but not too colorful

if mode == "dark":
    p = {"bg": hls(bh, 0.10, bs), "surface": hls(bh, 0.145, bs), "surfaceHi": hls(bh, 0.19, bs),
         "text": hls(bh, 0.96, 0.20), "muted": hls(bh, 0.64, 0.14), "accent": hls(ah, max(al, 0.58), as_),
         "warn": "#fbbf24", "danger": "#ef4444", "success": "#4ade80", "tint": "#ffffff"}
else:
    p = {"bg": hls(bh, 0.96, bs), "surface": "#ffffff", "surfaceHi": hls(bh, 0.91, bs),
         "text": hls(bh, 0.12, 0.30), "muted": hls(bh, 0.40, 0.12), "accent": hls(ah, min(al, 0.50), as_),
         "warn": "#d97706", "danger": "#dc2626", "success": "#16a34a", "tint": "#000000"}
print(json.dumps(p, indent=2))
