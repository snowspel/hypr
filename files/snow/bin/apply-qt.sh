#!/bin/bash
# Makes Qt / KDE app colors from theme.json (kdeglobals + color scheme). Qt apps read these.
j="$HOME/.config/snow/theme.json"
c() { jq -r ".$1" "$j"; }
rgb() { local h=${1#\#}; printf '%d,%d,%d' $((16#${h:0:2})) $((16#${h:2:2})) $((16#${h:4:2})); }
bg=$(rgb "$(c bg)"); sf=$(rgb "$(c surface)"); sh=$(rgb "$(c surfaceHi)"); tx=$(rgb "$(c text)"); mu=$(rgb "$(c muted)")
ac=$(rgb "$(c accent)"); wa=$(rgb "$(c warn)"); da=$(rgb "$(c danger)"); su=$(rgb "$(c success)")

grp() {  # grp <name> <background> <alternate>
cat << EOT
[Colors:$1]
BackgroundAlternate=$3
BackgroundNormal=$2
DecorationFocus=$ac
DecorationHover=$ac
ForegroundActive=$ac
ForegroundInactive=$mu
ForegroundLink=$ac
ForegroundNegative=$da
ForegroundNeutral=$wa
ForegroundNormal=$tx
ForegroundPositive=$su
ForegroundVisited=$mu

EOT
}
out=$(mktemp)
{
  echo "[General]"; echo "ColorScheme=Snow"; echo
  grp Window "$bg" "$sf"
  grp View "$sf" "$sh"
  grp Button "$sh" "$sf"
  grp Tooltip "$sh" "$sf"
  grp Complementary "$bg" "$sf"
  grp Header "$bg" "$sf"
  cat << EOT
[Colors:Selection]
BackgroundAlternate=$ac
BackgroundNormal=$ac
DecorationFocus=$ac
DecorationHover=$ac
ForegroundActive=255,255,255
ForegroundInactive=255,255,255
ForegroundLink=255,255,255
ForegroundNegative=255,255,255
ForegroundNeutral=255,255,255
ForegroundNormal=255,255,255
ForegroundPositive=255,255,255
ForegroundVisited=255,255,255
EOT
} > "$out"

mkdir -p "$HOME/.local/share/color-schemes"
[ -f "$HOME/.config/kdeglobals" ] && ! grep -q '^ColorScheme=Snow' "$HOME/.config/kdeglobals" && cp "$HOME/.config/kdeglobals" "$HOME/.config/kdeglobals.before-snow"
cp "$out" "$HOME/.config/kdeglobals"
cp "$out" "$HOME/.local/share/color-schemes/Snow.colors"
rm -f "$out"
echo "Qt/KDE colors updated"
