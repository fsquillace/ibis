post_install() {
    # Install packages
    sudo pacman --noconfirm -Syu
    sudo pacman --noconfirm -Sy $(cat $PEARL_PKGDIR/packages | xargs)

    # Systemd services
    sudo systemctl start sshd.service
    sudo systemctl enable sshd.service
    sudo systemctl start udisks2.service
    sudo systemctl enable udisks2.service
    sudo systemctl start dbus.service
    sudo systemctl start bluetooth.service
    sudo systemctl enable bluetooth.service
    sudo systemctl start ntpd.service
    sudo systemctl enable ntpd.service

    # Apply custom configurations
    mkdir -p $PEARL_PKGVARDIR/configs/

    local xinitrc_input_file="$PEARL_PKGVARDIR/configs/xinitrc-input"
    setup_configuration "$xinitrc_input_file" "_configure_input" \
        "_apply_initrc" "_unapply_initrc"

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

_apply_initrc() {
    local xinitrc_input_file="$PEARL_PKGVARDIR/configs/xinitrc-input"
    apply "source $xinitrc_input_file" "$HOME/.xinitrc"
}

_unapply_initrc() {
    local xinitrc_input_file="$PEARL_PKGVARDIR/configs/xinitrc-input"
    unapply "source $xinitrc_input_file" "$HOME/.xinitrc"
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

    if ask "Do you want to shutdown the services and remove all the packages from Ibis?" "N"
    then
        sudo systemctl stop sshd.service
        sudo systemctl disable sshd.service
        sudo systemctl stop udisks2.service
        sudo systemctl disable udisks2.service
        sudo systemctl stop dbus.service
        sudo systemctl stop bluetooth.service
        sudo systemctl disable bluetooth.service
        sudo systemctl stop ntpd.service
        sudo systemctl disable ntpd.service

        sudo pacman --noconfirm -Rsn $(cat $PEARL_PKGDIR/packages | xargs)
    fi

    return 0
}
