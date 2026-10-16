#!/bin/bash
# Cleanup: old package cache, journal logs, unused flatpak, thumbnail cache. Asks before removing orphan packages.
before=$(df --output=used -B1 / | tail -1)
echo "== 1. pacman cache (keeps only 2 old versions of each package) =="
command -v paccache >/dev/null && sudo paccache -rk2 || sudo pacman -Sc --noconfirm
command -v paccache >/dev/null && sudo paccache -ruk0
echo; echo "== 2. AUR build cache =="
[ -d "$HOME/.cache/yay" ] && { rm -rf "$HOME"/.cache/yay/*/src "$HOME"/.cache/yay/*/pkg 2>/dev/null; echo "yay src/pkg cleaned"; }
echo; echo "== 3. system journal (keeps only the last 2 weeks) =="
sudo journalctl --vacuum-time=2weeks 2>&1 | tail -n 1
if command -v flatpak >/dev/null; then echo; echo "== 4. unused flatpak runtimes =="; sudo flatpak uninstall --unused -y 2>&1 | tail -n 3; fi
echo; echo "== 5. thumbnail cache =="
rm -rf "$HOME/.cache/thumbnails"/* 2>/dev/null; echo "ok"
echo; echo "== 6. orphan packages (not needed by any package) =="
orph=$(pacman -Qdtq 2>/dev/null)
if [ -n "$orph" ]; then
  echo "$orph"; echo
  read -rp "Remove these packages? [y/N] " a
  if [ "$a" = y ] || [ "$a" = Y ]; then echo "$orph" | sudo pacman -Rns --noconfirm - ; else echo "orphans kept."; fi
else echo "no orphans"; fi
after=$(df --output=used -B1 / | tail -1)
echo; echo "Space freed: $(( (before - after) / 1048576 )) MB"
read -rp "Press Enter to close..." _
