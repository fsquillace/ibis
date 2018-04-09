#!/bin/sh

############### SERVICES #############
# D-Bus
if which dbus-launch >/dev/null && test -z "$DBUS_SESSION_BUS_ADDRESS"; then
    eval "$(dbus-launch --sh-syntax --exit-with-session)"
fi

# Active pulseaudio
start-pulseaudio-x11

# https://github.com/coldfix/udiskie/wiki/Usage
udiskie &

# Disable trackpad while typing for xf86-input-synaptics. It might be annoying.
# syndaemon -t -k -i 2 -d &

# Launches urxvtd daemon
urxvtd -q -f -o

blueman-applet &

############# OTHER SETTINGS ###########
# None

############# STARTUP APPLICATIONS #########
# Example: startup app after 10 secs from startx
#sleep 10 & goldendict &> /dev/null &
