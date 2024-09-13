IBIS_SETUP_PACKAGES=${IBIS_SETUP_PACKAGES:-true}

post_install() {
    if $IBIS_SETUP_PACKAGES
    then
        # This ensures to have the most up to date keys before installing any
        # other packages
        sudo pacman --noconfirm -Sy archlinux-keyring
        sudo pacman-key --populate archlinux
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
    fi

    _root_configs

    if ask "Do you want to perform initial setup for Arch Linux?" "N"
    then
        _arch_linux_setup
    fi

    mkdir -p $HOME/.local/bin

    _configure_home_directory
    _configure_dns install
    _configure_fonts install
    _configure_rofi install
    _configure_dunst install
    _configure_polybar install
    _configure_bspwm install
    _configure_sxhkd install
    _configure_ncmpcpp install
    _configure_gpg install
    _configure_mpd install
    _configure_xinitrc install
    _configure_custom

    _other_systemd_services install

    # Information and manual changes
    info "Following steps requires manual changes"
    info "  Setup bluetooth audio:"
    info "    https://wiki.archlinux.org/index.php/bluetooth#Audio"

    return 0
}

post_update() {
    post_install
}

pre_remove() {
    if ask "Do you want to shutdown the services and remove all the packages from Ibis?" "N"
    then
        _other_systemd_services remove

        sudo pacman --noconfirm -Rsn $(cat $PEARL_PKGDIR/packages | xargs)
        sudo pacman --noconfirm -Rsn $(cat $PEARL_PKGDIR/aur-packages | xargs)
    fi

    _configure_dns remove
    _configure_fonts remove
    _configure_rofi remove
    _configure_dunst remove
    _configure_polybar remove
    _configure_bspwm remove
    _configure_sxhkd remove
    _configure_ncmpcpp remove
    _configure_gpg remove
    _configure_mpd remove
    _configure_xinitrc remove
    _configure_custom remove

    return 0
}

_configure_dns() {
    if [[ $1 == "install" ]]
    then
        # The systemd resolve picks up the first available server and stick with it for any DNS requests.
        # There is no correct fallback mechanism to allow checking on secondary DNS servers.
        # https://wiki.archlinux.org/index.php/Systemd-resolved
        info "Systemd-resolved setup..."
        # The DHCP and VPN clients use the resolvconf program to set name servers and search domains
        # the additional package systemd-resolvconf is needed to provide the /usr/bin/resolvconf symlink.
        sudo mkdir -p /etc/systemd/resolved.conf.d
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

        sudo systemctl daemon-reload
        sudo systemctl enable systemd-resolved.service
        sudo systemctl start systemd-resolved.service

        # An alternative DNS solution is resolvconf. Disabling for now.
        #info "Setting up resolvconf..."
        ## https://wiki.archlinux.org/title/Openresolv
        #sudo resolvconf -u

    elif [[ $1 == "remove" ]]
    then
        sudo systemctl daemon-reload
        sudo systemctl disable systemd-resolved.service
        sudo systemctl stop systemd-resolved.service

        sudo rm -rf /etc/resolv.conf
    fi

}

_configure_home_directory() {
    mkdir -p $HOME/{downloads,music,images/wallpapers,documents,video}
    cp ${PEARL_PKGDIR}/assets/wallpapers/* $HOME/images/wallpapers
}

_arch_linux_setup() {
    # Based on the holy Archlinux wiki:
    # https://wiki.archlinux.org/index.php/Installation_guide
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
}

_root_configs() {
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

}

_configure_custom() {
    local xinitrc_input_file="$PEARL_PKGVARDIR/configs/xinitrc-input"
    if [[ $1 == "install" ]]
    then
        # Apply custom configurations
        mkdir -p $PEARL_PKGVARDIR/configs/
        setup_configuration "$xinitrc_input_file" "_configure_input" \
            "_apply_initrc" "_unapply_initrc"
    elif [[ $1 == "remove" ]]
    then
        unapply "source $xinitrc_input_file" "$HOME/.xinitrc"
    fi
}

_other_systemd_services() {
    if [[ $1 == "install" ]]
    then
        local enablefuncname=enable
        local startfuncname=start
    elif [[ $1 == "remove" ]]
    then
        local enablefuncname=disable
        local startfuncname=stop
    fi

    # Systemd services
    sudo systemctl daemon-reload
    sudo systemctl $startfuncname sshd.service
    sudo systemctl $enablefuncname sshd.service
    sudo systemctl $startfuncname udisks2.service
    sudo systemctl $enablefuncname udisks2.service
    sudo systemctl $startfuncname dbus.service
    sudo systemctl $startfuncname bluetooth.service
    sudo systemctl $enablefuncname bluetooth.service
    sudo systemctl $startfuncname ntpd.service
    sudo systemctl $enablefuncname ntpd.service
    sudo systemctl $startfuncname transmission.service
    sudo systemctl $enablefuncname transmission.service

    # https://wiki.archlinux.org/index.php/Pacman#Cleaning_the_package_cache
    sudo systemctl $startfuncname paccache.timer
    sudo systemctl $enablefuncname paccache.timer

    sudo systemctl restart systemd-journald
}

_configure_xinitrc() {
    if [[ $1 == "install" ]]
    then
        local funcname=apply
    elif [[ $1 == "remove" ]]
    then
        local funcname=unapply
    fi
    # Apply default configuration files
    $funcname "source $PEARL_PKGDIR/configs/xinitrc" "$HOME/.xinitrc"
    # The following makes sure to place BSP WM at the end
    $funcname "exec bspwm" "$HOME/.xinitrc" false
}

_configure_fonts() {
    local fontspath=$HOME/.local/share/fonts/ibis-fonts/
    if [[ $1 == "install" ]]
    then
        rm -rf $fontspath
        mkdir -p $fontspath
        cd $fontspath
        # For new versions check:
        # https://github.com/ryanoasis/nerd-fonts/releases
        local nerdfontsversion=2.1.0
        fontname=Terminus
        download https://github.com/ryanoasis/nerd-fonts/releases/download/v${nerdfontsversion}/$fontname.zip
        unzip -o $fontname.zip
        rm $fontname.zip*
    elif [[ $1 == "remove" ]]
    then
        rm -rf $fontspath
    fi

    fc-cache -frv "$fontspath"

    # To check the list of installed font names
    #fc-list | grep "$fontspath" | cut -d: -f2 | sort -u
}

_configure_ncmpcpp() {
    mkdir -p $HOME/.config/ncmpcpp/lyrics
    local home_ncmpcpp_config=$HOME/.config/ncmpcpp/config
    local pearl_ncmpcpp_config=$PEARL_PKGDIR/configs/ncmpcpp/config
    local home_ncmpcpp_bindings=$HOME/.config/ncmpcpp/bindings
    local pearl_ncmpcpp_bindings=$PEARL_PKGDIR/configs/ncmpcpp/bindings

    if [[ $1 == "install" ]]
    then
        local funcname=link_to
    elif [[ $1 == "remove" ]]
    then
        local funcname=unlink_from
    fi
    $funcname $pearl_ncmpcpp_config $home_ncmpcpp_config
    $funcname $pearl_ncmpcpp_bindings $home_ncmpcpp_bindings
}

_configure_rofi() {
    mkdir -p $HOME/.config/rofi
    local home_rofi_config=$HOME/.config/rofi/config.rasi
    local pearl_rofi_config=$PEARL_PKGDIR/configs/rofi-config.rasi

    if [[ $1 == "install" ]]
    then
        local funcname=link_to
    elif [[ $1 == "remove" ]]
    then
        local funcname=unlink_from
    fi

    $funcname $pearl_rofi_config $home_rofi_config
}

_configure_dunst() {
    mkdir -p $HOME/.config/dunst
    local home_dunst_config=$HOME/.config/dunst/dunstrc
    local pearl_dunst_config=$PEARL_PKGDIR/configs/dunst/dunstrc
    local home_dunst_launch=$HOME/.config/dunst/launch.sh
    local pearl_dunst_launch=$PEARL_PKGDIR/configs/dunst/launch.sh

    if [[ $1 == "install" ]]
    then
        local funcname=link_to
    elif [[ $1 == "remove" ]]
    then
        local funcname=unlink_from
    fi

    $funcname $pearl_dunst_config $home_dunst_config
    $funcname $pearl_dunst_launch $home_dunst_launch
}

_configure_polybar() {
    mkdir -p $HOME/.config/polybar
    local home_polybar_config=$HOME/.config/polybar/config

    if [[ $1 == "install" ]]
    then
        local linkfuncname=link_to
        local applyfuncname=apply
        cp -R $PEARL_PKGDIR/configs/polybar/scripts $HOME/.config/polybar/
    elif [[ $1 == "remove" ]]
    then
        local linkfuncname=unlink_from
        local applyfuncname=unapply
        rm -rf $PEARL_PKGDIR/configs/polybar/scripts $HOME/.config/polybar/
    fi

    $applyfuncname "include-file = $PEARL_PKGDIR/configs/polybar/config" $home_polybar_config
    $applyfuncname "[section/base]" $home_polybar_config
    $linkfuncname $PEARL_PKGDIR/configs/polybar/launch.sh $HOME/.config/polybar/launch.sh
}

_configure_bspwm() {
    mkdir -p $HOME/.config/bspwm

    if [[ $1 == "install" ]]
    then
        local applyfuncname=apply
    elif [[ $1 == "remove" ]]
    then
        local applyfuncname=unapply
    fi
    $applyfuncname "source $PEARL_PKGDIR/configs/bspwm/bspwmrc" $HOME/.config/bspwm/bspwmrc
    $applyfuncname "#!/bin/bash" $HOME/.config/bspwm/bspwmrc
    chmod +x $HOME/.config/bspwm/bspwmrc
}


_configure_sxhkd() {
    mkdir -p $HOME/.config/sxhkd

    if [[ $1 == "install" ]]
    then
        local linkfuncname=link_to
    elif [[ $1 == "remove" ]]
    then
        local linkfuncname=unlink_from
    fi

    $linkfuncname $PEARL_PKGDIR/configs/sxhkd/sxhkdrc $HOME/.config/sxhkd/sxhkdrc
    $linkfuncname $PEARL_PKGDIR/configs/sxhkd/launch.sh $HOME/.config/sxhkd/launch.sh
}

_configure_mpd() {
    if [[ $1 == "install" ]]
    then
        # https://wiki.archlinux.org/index.php/Music_Player_Daemon
        mkdir -p $HOME/.config/mpd/playlists
        link_to $PEARL_PKGDIR/configs/mpd.conf $HOME/.config/mpd/mpd.conf

        systemctl --user daemon-reload
        systemctl --user start mpd.service
        systemctl --user enable mpd.service
    elif [[ $1 == "remove" ]]
    then
        unlink_from $PEARL_PKGDIR/configs/mpd.conf $HOME/.config/mpd/mpd.conf
    fi

}

_configure_gpg() {
    if [[ $1 == "install" ]]
    then
        mkdir -p $HOME/.gnupg
        link_to $PEARL_PKGDIR/configs/gpg-agent.conf $HOME/.gnupg/gpg-agent.conf
    elif [[ $1 == "remove" ]]
    then
        unlink_from $PEARL_PKGDIR/configs/gpg-agent.conf $HOME/.gnupg/gpg-agent.conf
    fi
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
