
post_install() {
    # Install packages
    sudo pacman --noconfirm -S $(cat $PEARL_PKGDIR/packages | xargs)

    # Systemd services
    sudo systemctl start udisks2.service
    sudo systemctl enable udisks2.service
    sudo systemctl start dbus.service
    sudo systemctl start bluetooth.service
    sudo systemctl enable bluetooth.service

    # Apply custom configurations
    mkdir -p $PEARL_PKGVARDIR/configs/
    ask "Do you want to follow procedure for input configuration (i.e. mouse, keyboard, etc)?" "N" && \
        _configure_input

    # Apply default configuration files
    apply "source $PEARL_PKGDIR/xinitrc" "$HOME/.xinitrc"
    # The following makes sure to place Awesome WM at the end
    apply "exec awesome" "$HOME/.xinitrc" false

    # Information and manual changes
    info "Following steps requires manual changes"
    info "  Setup bluetooth auto power-on:"
    info "    https://wiki.archlinux.org/index.php/bluetooth#Auto_power-on_after_boot"
    info "  Setup bluetooth audio:"
    info "    https://wiki.archlinux.org/index.php/bluetooth#Audio"

    return 0
}

_configure_input() {
    local xinitrc_input_file="$PEARL_PKGVARDIR/configs/xinitrc-input"

    info "More info about Keyboard config:"
    info "    https://wiki.archlinux.org/index.php/Keyboard_configuration_in_Xorg#Setting_keyboard_layout"
    info "For full list of keyboard models take a look at: /usr/share/X11/xkb/rules/base.lst"
    local kblayout=$(input "Provide the language Keyboard layout" "us")
    echo "setxkbmap -layout $kblayout" >> "$xinitrc_input_file"

    info "More info about how to config mouse acceleration:"
    info "    https://wiki.archlinux.org/index.php/Mouse_acceleration"
    echo "" > "$xinitrc_input_file"
    while ask "Do you want to configure additional input?" "N"
    do
        xinput list
        local input_name=$(input "Provide one of the input hardware string name (Enter to skip)" "")
        [[ -z $input_name ]] && continue
        xinput --list-props "$input_name"
        local prop_name=$(input "Provide the property string to configure (Enter to skip)" "")
        [[ -z $prop_name ]] && continue
        local value=$(input "Provide the property value (Enter to skip)" "")
        [[ -z $value ]] && continue
        info "Setting the property..."
        xinput --set-prop "$input_name" "$prop_name" "$value"
        ask "Try out the new property now and type 'Y' to save it." "N" && { \
            info "Saving the property configuration..."
            echo "xinput --set-prop '$input_name' '$prop_name' '$value'" >> "$xinitrc_input_file"
        }
    done

    apply "source $xinitrc_input_file" "$HOME/.xinitrc"

    return 0
}

post_update() {
    post_install
}

pre_remove() {
    unapply "exec awesome" "$HOME/.xinitrc"
    local xinitrc_input_file="$PEARL_PKGVARDIR/configs/xinitrc-input"
    unapply "source $xinitrc_input_file" "$HOME/.xinitrc"
    unapply "source $PEARL_PKGDIR/xinitrc" "$HOME/.xinitrc"

    sudo systemctl stop udisks2.service
    sudo systemctl disable udisks2.service
    sudo systemctl stop dbus.service
    sudo systemctl stop bluetooth.service
    sudo systemctl disable bluetooth.service

    sudo pacman --noconfirm -Rsn $(cat $PEARL_PKGDIR/packages | xargs)
    return 0
}
