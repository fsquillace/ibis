
_install_pkg_from_aur(){
    local pkgname=$1
    local maindir=$(TMPDIR=/tmp mktemp -d -t ibis.XXXXXXXXXX)
    local origin_pwd="$PWD"
    builtin cd "${maindir}"
    download "https://aur.archlinux.org/cgit/aur.git/snapshot/${pkgname}.tar.gz"
    tar -xvzf ${pkgname}.tar.gz
    builtin cd "${pkgname}"
    makepkg -sfcd
    sudo pacman --noconfirm -U ${pkgname}*.pkg.tar.xz
    builtin cd "$origin_pwd"
    rm -rf "${maindir}"
}

_aur_setup() {
    while read aur_package; do
        if [[ "$aur_package" = "#"* ]]
        then
            info "Skipping package $aur_package ..."
        else
           info "Installing $aur_package from AUR..."
            _install_pkg_from_aur $aur_package
        fi
    done < $PEARL_PKGDIR/aur-packages

    return 0
}

post_install() {
    # Install packages
    sudo pacman --noconfirm -Syu
    sudo pacman --noconfirm -Sy $(cat $PEARL_PKGDIR/packages | xargs)

    if ask "Do you want to install AUR packages?" "N"
    then
        _aur_setup
    fi

    # Meson is only needed for font-manager as make dependency
    sudo pacman --noconfirm -Rsn meson

    mkdir -p $HOME/.local/bin
    _configure_qutebrowser

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
    sudo systemctl start transmission.service
    sudo systemctl enable transmission.service

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

_configure_qutebrowser() {
    # Umpv is used together with qutebrowser for watching video:
    # https://www.qutebrowser.org/doc/faq.html
    cd $HOME/.local/bin
    [[ -e umpv ]] && rm -rf umpv
    download "https://github.com/mpv-player/mpv/raw/master/TOOLS/umpv"
    chmod +x umpv
    /usr/share/qutebrowser/scripts/dictcli.py install en-US
    /usr/share/qutebrowser/scripts/dictcli.py install es-ES
    /usr/share/qutebrowser/scripts/dictcli.py install it-IT

    apply "exec(open('$PEARL_PKGDIR/qutebrowser_config.py').read())" $HOME/.config/qutebrowser/config.py
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
    [[ -e umpv ]] && rm -rf umpv
    unapply "exec(open('$PEARL_PKGDIR/qutebrowser_config.py').read())" $HOME/.config/qutebrowser/config.py

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
        sudo systemctl stop transmission.service
        sudo systemctl disable transmission.service

        sudo pacman --noconfirm -Rsn $(cat $PEARL_PKGDIR/packages | xargs)
        sudo pacman --noconfirm -Rsn $(cat $PEARL_PKGDIR/aur-packages | xargs)
    fi

    return 0
}
