
post_install() {
    # Install packages
    sudo pacman --noconfirm -S $(cat $PEARL_PKGDIR/packages | xargs)

    # Systemd services
    sudo systemctl start udisks2.service
    sudo systemctl enable udisks2.service
    sudo systemctl start dbus.service
    sudo systemctl start bluetooth.service
    sudo systemctl enable bluetooth.service

    # Information and manual changes
    info "Following steps requires manual changes"
    info "  Setup bluetooth auto power-on:"
    info "    https://wiki.archlinux.org/index.php/bluetooth#Auto_power-on_after_boot"
    info "  Setup bluetooth audio:"
    info "    https://wiki.archlinux.org/index.php/bluetooth#Audio"

    # Apply configuration files
    apply "source $PEARL_PKGDIR/xinitrc" "$HOME/.xinitrc"
    return 0
}

post_update() {
    post_install
}

pre_remove() {
    unapply "source $PEARL_PKGDIR/xinitrc" "$HOME/.xinitrc"

    sudo systemctl stop udisks2.service
    sudo systemctl disable udisks2.service
    sudo systemctl stop dbus.service
    sudo systemctl stop bluetooth.service
    sudo systemctl disable bluetooth.service

    sudo pacman --noconfirm -Rsn $(cat $PEARL_PKGDIR/packages | xargs)
    return 0
}
