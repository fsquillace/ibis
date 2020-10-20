#!/bin/bash

# https://www.reddit.com/r/bspwm/comments/d08bzz/dunst_pywal/
#        -lf/nf/cf color
#            Defines the foreground color for low, normal and critical notifications respectively.
# 
#        -lb/nb/cb color
#            Defines the background color for low, normal and critical notifications respectively.
# 
#        -lfr/nfr/cfr color
#            Defines the frame color for low, normal and critical notifications respectively.

[[ -f "$HOME/.cache/wal/colors.sh" ]] && source "$HOME/.cache/wal/colors.sh"

pidof dunst && killall dunst

dunst -lf  "${color2:-#ffffff}" \
      -nf  "${color3:-#cccccc}" \
      -cf  "${color1:-#999999}" \
      -lb  "${color0:-#eeeeee}" \
      -nb  "${color0:-#bbbbbb}" \
      -cb  "${color0:-#888888}" \
      -lfr "${color1:-#dddddd}" \
      -nfr "${color1:-#aaaaaa}" \
      -cfr "${color1:-#777777}" > /dev/null 2>&1 &

