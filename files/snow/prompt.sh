# snow: colored bash prompt  [user@host folder]$
# It uses the terminal's own colors, so it follows the theme by itself:
#   color 4 (blue slot) = theme accent,  color 8 (bright black slot) = theme muted color.
# To change the colors, edit the numbers below:  34 = accent,  90 = muted,  32 = green,  33 = yellow,  35 = purple,  36 = cyan,  31 = red
[[ $- == *i* ]] || return 0
[ "${TERM:-dumb}" = dumb ] && return 0
_snow_acc='\[\e[1;34m\]'   # user name and $  (accent, bold)
_snow_acc2='\[\e[34m\]'    # host name        (accent)
_snow_dim='\[\e[90m\]'     # [ @ ]            (muted)
_snow_off='\[\e[0m\]'
PS1="${_snow_dim}[${_snow_off}${_snow_acc}\u${_snow_off}${_snow_dim}@${_snow_off}${_snow_acc2}\h${_snow_off} \W${_snow_dim}]${_snow_off}${_snow_acc}\\\$${_snow_off} "
unset _snow_acc _snow_acc2 _snow_dim _snow_off
