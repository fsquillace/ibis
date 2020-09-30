
post_install() {
    sudo cp ${PEARL_PKGDIR}/configs/sudoers /etc/sudoers.d/01_myarch
    sudo chown root:root /etc/sudoers.d/01_myarch
    sudo chmod 440 /etc/sudoers.d/01_myarch
    sudo groupadd -f admin
    sudo gpasswd -a $USER admin

    sudo cp ${PEARL_PKGDIR}/configs/journald.conf /etc/systemd/journald.conf
    sudo chown root:root /etc/systemd/journald.conf

    warn "Overriding file for setting up bluetooth: /etc/bluetooth/main.conf"
    sudo mkdir -p /etc/bluetooth/
    sudo cp ${PEARL_PKGDIR}/configs/bluetooth-main.conf /etc/bluetooth/main.conf

    if ask "Do you want to perform initial setup for Arch Linux?" "N"
    then
        ls /usr/share/zoneinfo/*/*
        local region=$(input "Choose one of the time zone above (i.e. Europe/Madrid)" "UTC")
        sudo ln -sf /usr/share/zoneinfo/$region /etc/localtime

        local locale=$(input "Choose locale" "en_US")
        local encode=$(input "Choose encode" "UTF-8")
        local hostname=$(input "Hostname" "myarch")

        sudo sh -c "
        $(declare -f apply)
        $(declare -f check_not_null)
        apply '${locale}.${encode} ${encode}' /etc/locale.gen false
        locale-gen
        echo 'LANG=${locale}.${encode}' > /etc/locale.conf
        echo '$hostname' > /etc/hostname
        apply '127.0.0.1    localhost' /etc/hosts false
        apply '::1          localhost' /etc/hosts false
        apply '127.0.1.1    ${hostname}.localdomain  ${hostname}' /etc/hosts false
        hwclock --systohc
        "

    fi

    # Install packages
    sudo pacman --noconfirm -Syu
    sudo pacman --noconfirm -Sy $(cat $PEARL_PKGDIR/packages | xargs)
    # base-devel is essential for building AUR packages
    sudo pacman --noconfirm -S base-devel

    info "Installing yay..."
    _install_yay

    if ask "Do you want to install AUR packages in ibis?" "Y"
    then
        _aur_setup
    fi

    mkdir -p $HOME/.local/bin

    _configure_gpg
    _configure_qutebrowser
    _configure_mpd

    # Systemd services
    sudo systemctl daemon-reload
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

    # https://wiki.archlinux.org/index.php/Pacman#Cleaning_the_package_cache
    sudo systemctl start paccache.timer
    sudo systemctl enable paccache.timer

    sudo systemctl restart systemd-journald

    systemctl --user daemon-reload
    systemctl --user start mpd.service
    systemctl --user enable mpd.service

    # Apply custom configurations
    mkdir -p $PEARL_PKGVARDIR/configs/

    local xinitrc_input_file="$PEARL_PKGVARDIR/configs/xinitrc-input"
    setup_configuration "$xinitrc_input_file" "_configure_input" \
        "_apply_initrc" "_unapply_initrc"

    # Apply default configuration files
    apply "source $PEARL_PKGDIR/configs/xinitrc" "$HOME/.xinitrc"
    # The following makes sure to place Awesome WM at the end
    apply "exec awesome" "$HOME/.xinitrc" false

    # Information and manual changes
    info "Following steps requires manual changes"
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

    apply "exec(open('$PEARL_PKGDIR/configs/qutebrowser_config.py').read())" $HOME/.config/qutebrowser/config.py
}

_configure_mpd() {
    # https://wiki.archlinux.org/index.php/Music_Player_Daemon
    mkdir -p $HOME/.config/mpd/playlists
    cp $PEARL_PKGDIR/configs/mpd.conf $HOME/.config/mpd/
}

_configure_gpg() {
    mkdir -p $HOME/.gnupg
    [[ -f $HOME/.gnupg/gpg-agent.conf ]] && backup $HOME/.gnupg/gpg-agent.conf
    cp $PEARL_PKGDIR/configs/gpg-agent.conf $HOME/.gnupg/gpg-agent.conf
}

_apply_initrc() {
    local xinitrc_input_file="$PEARL_PKGVARDIR/configs/xinitrc-input"
    apply "source $xinitrc_input_file" "$HOME/.xinitrc"
}

_unapply_initrc() {
    local xinitrc_input_file="$PEARL_PKGVARDIR/configs/xinitrc-input"
    unapply "source $xinitrc_input_file" "$HOME/.xinitrc"
}

_install_pkg_from_aur(){
    local pkgname=$1
    local maindir=$(TMPDIR=/tmp mktemp -d -t ibis.XXXXXXXXXX)
    local origin_pwd="$PWD"
    builtin cd "${maindir}"
    download "https://aur.archlinux.org/cgit/aur.git/snapshot/${pkgname}.tar.gz"
    tar -xvzf ${pkgname}.tar.gz
    builtin cd "${pkgname}"
    makepkg -sfcd
    sudo pacman --noconfirm -U ${pkgname}*.pkg.tar.*
    builtin cd "$origin_pwd"
    rm -rf "${maindir}"
}

_install_yay(){
    sudo pacman --noconfirm -S git go
    _install_pkg_from_aur yay
    sudo pacman --noconfirm -Rsn go

}

_aur_setup() {
    while read aur_package; do
        if [[ "$aur_package" = "#"* ]]
        then
            info "Skipping package $aur_package ..."
        else
           info "Installing $aur_package from AUR..."
           yay --noconfirm -S $aur_package
        fi
    done < $PEARL_PKGDIR/aur-packages

    # Meson is only needed for font-manager as make dependency
    sudo pacman --noconfirm -Rsn meson

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
    info "More info about libinput:"
    info "    https://wiki.archlinux.org/index.php/Libinput#Via_xinput"
    echo "" > "$xinitrc_input_file"
    while ask "Do you want to configure additional input?" "N"
    do
        xinput list
        local input_name=$(input "Provide one of the input hardware string name or id (Enter to skip)" "")
        [[ -z $input_name ]] && continue
        xinput --list-props "$input_name"
        local prop_name=$(input "Provide the property string or code to configure (Enter to skip)" "")
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

        systemctl --user stop mpd.service
        systemctl --user disable mpd.service

        sudo pacman --noconfirm -Rsn $(cat $PEARL_PKGDIR/packages | xargs)
        sudo pacman --noconfirm -Rsn $(cat $PEARL_PKGDIR/aur-packages | xargs)
    fi

    [[ -e $HOME/.gnupg/gpg-agent.conf ]] && rm $HOME/.gnupg/gpg-agent.conf
    [[ -e $HOME/.config/mpd/mpd.conf ]] && rm $HOME/.config/mpd/mpd.conf
    unapply "exec awesome" "$HOME/.xinitrc"
    local xinitrc_input_file="$PEARL_PKGVARDIR/configs/xinitrc-input"
    unapply "source $xinitrc_input_file" "$HOME/.xinitrc"
    unapply "source $PEARL_PKGDIR/configs/xinitrc" "$HOME/.xinitrc"
    [[ -e umpv ]] && rm -rf umpv
    unapply "exec(open('$PEARL_PKGDIR/configs/qutebrowser_config.py').read())" $HOME/.config/qutebrowser/config.py

    return 0
}
