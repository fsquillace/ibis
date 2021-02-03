
alias pacman="pacman --color auto"
alias top="bpytop"

# https://wiki.archlinux.org/index.php/Fzf
function fish_user_key_bindings
    fzf_key_bindings
end

add_to_path $HOME/.local/bin

set -x MPD_HOST localhost

neofetch
