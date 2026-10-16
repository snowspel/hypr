#!/usr/bin/env python3
# Picks colors from the wallpaper and prints a theme JSON.   use: wallpaper-colors.py dark|light
import sys, os, glob, subprocess, colorsys, json, math

mode = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] in ("dark", "light") else "dark"
d = os.path.expanduser("~/.config/hypr/wallpaper")
files = []
for e in ("jpg", "jpeg", "png", "webp", "JPG", "JPEG", "PNG", "WEBP"):
    files += glob.glob(os.path.join(d, "*." + e))
files.sort(key=os.path.getmtime, reverse=True)

def hexc(r, g, b):
    return "#%02x%02x%02x" % (round(r * 255), round(g * 255), round(b * 255))

def hls(h, l, s):
    return hexc(*colorsys.hls_to_rgb(h % 1.0, max(0, min(1, l)), max(0, min(1, s))))

def lum(rgb):
    def f(c): return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = rgb
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

hue, sat = 0.66, 0.15   # fallback: blue, low saturation
found = False
if files:
    try:
        raw = subprocess.run(["convert", files[0] + "[0]", "-resize", "96x96!", "-depth", "8", "rgb:-"],
                             capture_output=True, timeout=30).stdout
        bins = [0.0] * 36
        sx = [0.0] * 36; sy = [0.0] * 36; ss = [0.0] * 36
        tot_s = 0.0; n = 0
        for i in range(0, len(raw) - 2, 3):
            r, g, b = raw[i] / 255, raw[i + 1] / 255, raw[i + 2] / 255
            h, s, v = colorsys.rgb_to_hsv(r, g, b)
            n += 1; tot_s += s
            w = s * v if (s > 0.22 and v > 0.22) else 0.0
            if w > 0:
                k = int(h * 36) % 36
                bins[k] += w
                sx[k] += w * math.cos(2 * math.pi * h); sy[k] += w * math.sin(2 * math.pi * h)
                ss[k] += w * s
        if n and max(bins) > 0.01 * n:
            best = max(range(36), key=lambda k: bins[k] + 0.5 * (bins[(k - 1) % 36] + bins[(k + 1) % 36]))
            hue = (math.atan2(sy[best], sx[best]) / (2 * math.pi)) % 1.0
            sat = ss[best] / bins[best]
            found = True
    except Exception:
        pass

sat = max(0.0, min(1.0, sat))
bgS = 0.08 + 0.22 * sat if found else 0.10
acS = max(0.5, min(0.85, sat + 0.1)) if found else 0.80
acH = hue if found else 0.67

def accent(l):
    # keep white text readable on the accent: contrast >= 3
    while l > 0.28:
        rgb = colorsys.hls_to_rgb(acH, l, acS)
        if (1.05) / (lum(rgb) + 0.05) >= 3.0:
            break
        l -= 0.02
    return hls(acH, l, acS)

if mode == "dark":
    p = {"bg": hls(hue, 0.10, bgS), "surface": hls(hue, 0.145, bgS), "surfaceHi": hls(hue, 0.19, bgS),
         "text": hls(hue, 0.96, 0.20), "muted": hls(hue, 0.64, 0.14), "accent": accent(0.64),
         "warn": "#fbbf24", "danger": "#ef4444", "success": "#4ade80", "tint": "#ffffff"}
else:
    p = {"bg": hls(hue, 0.96, bgS), "surface": "#ffffff", "surfaceHi": hls(hue, 0.91, bgS),
         "text": hls(hue, 0.12, 0.30), "muted": hls(hue, 0.40, 0.12), "accent": accent(0.50),
         "warn": "#d97706", "danger": "#dc2626", "success": "#16a34a", "tint": "#000000"}
print(json.dumps(p, indent=2))
