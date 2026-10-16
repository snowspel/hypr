#!/bin/bash
# Makes GTK3/GTK4 colors (Nautilus etc.) from theme.json
j="$HOME/.config/snow/theme.json"
c() { jq -r ".$1" "$j"; }
mkdir -p "$HOME/.config/gtk-4.0" "$HOME/.config/gtk-3.0"

cat > "$HOME/.config/gtk-4.0/gtk.css" << EOT
@define-color window_bg_color $(c bg);
@define-color window_fg_color $(c text);
@define-color view_bg_color $(c surface);
@define-color view_fg_color $(c text);
@define-color headerbar_bg_color $(c bg);
@define-color headerbar_fg_color $(c text);
@define-color sidebar_bg_color $(c surface);
@define-color sidebar_fg_color $(c text);
@define-color card_bg_color $(c surfaceHi);
@define-color card_fg_color $(c text);
@define-color popover_bg_color $(c surfaceHi);
@define-color popover_fg_color $(c text);
@define-color dialog_bg_color $(c bg);
@define-color dialog_fg_color $(c text);
@define-color accent_bg_color $(c accent);
@define-color accent_color $(c accent);
@define-color accent_fg_color #ffffff;
@define-color destructive_bg_color $(c danger);
@define-color destructive_color $(c danger);
@define-color success_color $(c success);
@define-color warning_color $(c warn);
@define-color error_color $(c danger);
EOT

cat > "$HOME/.config/gtk-3.0/gtk.css" << EOT
@define-color theme_bg_color $(c bg);
@define-color theme_fg_color $(c text);
@define-color theme_base_color $(c surface);
@define-color theme_text_color $(c text);
@define-color theme_selected_bg_color $(c accent);
@define-color theme_selected_fg_color #ffffff;
@define-color theme_unfocused_bg_color $(c bg);
@define-color theme_unfocused_fg_color $(c muted);
@define-color theme_unfocused_base_color $(c surface);
@define-color theme_unfocused_text_color $(c text);
@define-color insensitive_fg_color $(c muted);
@define-color insensitive_bg_color $(c surfaceHi);
@define-color borders $(c surfaceHi);
@define-color content_view_bg $(c surface);
@define-color tooltip_bg_color $(c surfaceHi);
@define-color tooltip_fg_color $(c text);
EOT

mode=$(cat "$HOME/.config/snow/mode" 2>/dev/null); [ "$mode" = light ] || mode=dark
if [ "$mode" = light ]; then cs=prefer-light; gt=Adwaita; dk=0; ic=Papirus-Light; else cs=prefer-dark; gt=Adwaita-dark; dk=1; ic=Papirus-Dark; fi
gsettings set org.gnome.desktop.interface icon-theme "$ic" 2>/dev/null
gsettings set org.gnome.desktop.interface color-scheme "$cs" 2>/dev/null
gsettings set org.gnome.desktop.interface gtk-theme "$gt" 2>/dev/null
for v in 3.0 4.0; do
  f="$HOME/.config/gtk-$v/settings.ini"
  if [ -f "$f" ] && grep -q gtk-application-prefer-dark-theme "$f"; then
    sed -i "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=$dk/" "$f"
  else
    printf '[Settings]\ngtk-application-prefer-dark-theme=%s\n' "$dk" > "$f"
  fi
done
echo "GTK theme updated ($mode)"
