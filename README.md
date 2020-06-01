# Ibis

The Arch Linux based distro for Desktop Environments tailored to minimalists.

**Table of Contents**
- [Description](#description)
- [Installation](#installation)
  - [Dependencies](#dependencies)
  - [Ibis Installation](#ibis-installation)
- [List of major applications](#list-of-major-applications)
- [Troubleshooting](#troubleshooting)

## Description
Ibis is an Arch Linux based distro with Awesome Window manager and few minimal
packages for basic functionalities such as ssh, auto mounting, image viewer,
text editor, audio/video player, etc. No other additional overhead is added into Ibis.

The system has been designed with the following principles in mind:

- Identify the basic functionalities required;
- Pick up the packages which deliver a minimal but complete solution for them;
- Configure the packages to make them working out of the box;
- Get an environment entirely reproducible via [Pearl](https://github.com/pearl-core/pearl) system.

If you think the package list does not suit your need, feel free to either
suggest changes or fork the project and create your own distro style.

The name Ibis come from the notorious
[Australian white ibis](https://en.wikipedia.org/wiki/Australian_white_ibis)
bird which populates Sydney city.

## Installation

### Dependencies

Ibis requires to have an Arch Linux system with the `base` package group
installed. The Arch Linux installation guide is
[here](https://wiki.archlinux.org/index.php/Installation_guide).

It is also required [Pearl](https://github.com/pearl-core/pearl) in order to
control and reproduce the Ibis environment.

The final dependency is `sudo` as Ibis will require to install the needed packages:

```sh
# pacman -Sy sudo
```

### Ibis installation

Update the `~/.config/pearl/pearl.conf` to include the repo and install Ibis via Pearl:

```
echo 'PEARL_REPOS+=("https://github.com/fsquillace/ibis.git")' >> ~/.config/pearl/pearl.conf
pearl install ibis
```

Ibis will start installing all the packages and will configure them for you.
You can replay the environment at any time or remove Ibis if you want:

```sh
pearl update ibis
pearl remove ibis
```

## List of major applications

Most of the applications are listed in the [Arch Linux wiki page](https://wiki.archlinux.org/index.php/list_of_applications).

For the complete list of packages installed by Ibis take a look at
[`packages`](packages) and [`aur-packages`](aur-packages) files.

### Window manager
- awesome

### PDF viewer
- zathura
- zathura-pdf-poppler

### Image viewer
- eom

### Text editor
- gvim

### Browser
- qutebrowser

### BitTorrent client
- transmission-cli

### Video and sound
- mate-media
- mpd
- ario
- pulseaudio
- smplayer

### Compression
- atool
- p7zip
- tar
- unrar
- zip/unzip

### Network tools
- iw
- net-tools
- wget
- wireless_tools
- wpa_supplicant

### Office
- libreoffice-fresh

### File manager
- ranger

### Terminal
- rxvt-unicode
- tmux
- urxvt-perls

### Screenshot capture
- scrot

### Backup/sync tools
- borg
- borgmatic
- rsync

### System/Command line tools
- bash-completion
- entr
- font-manager
- fzf
- highlight
- imagemagick
- openssh
- pass
- slock
- sudo
- trash-cli
- w3m
- yay

## Troubleshooting
This section has been left blank intentionally.
It will be filled up as soon as troubles come in!

