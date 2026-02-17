#! /bin/fish

## Instalation part
set base_packages "base" "base-devel" "booster" "neovim" "iwd" "efibootmgr"  \
    "gvfs" "gvfs-mtp" "xdg-user-dirs" "linux" "linux-firmware" "dhcpcd" "limine" \
    "btrfs-progs" "openssh" "git" "reflector" "amd-ucode" "fish"


function install_arch -a mnt
    reflector --verbose --country UA --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
    pacman -Sy

    pacstrap $mnt $base_packages
    genfstab -U $mnt >> $mnt/etc/fstab

    mount --bind ./ $mnt/opt/install_scripts
    echo "source /opt/install_scripts/install_scripts.fish && setup_arch" |
        arch-chroot $mnt fish -
    umount $mnt/opt/install_scripts
end

## Setting part
set packages "zed" "fish" "zen-browser" "zellij" "alacritty" "btop" "bat" "ripgrep" \
    "thunar" "keepassxc" "vesktop" "steam" "bun" "uv" "rustup" "go" "httpie" "flyctl" \
    "godot" "typst" "cava" "easyeffects" "gimp" "vlc" "just" "xxd" "pipewire" \
    "blueman" "nvidia-dkms" "tree" "zip" "wl-clipboard" "ripgrep" "rar" "qemu" \
    "playerctl" "grip" "slurp" "dust" "docker" "starship" "git" \
    "spicetify-cli" "spicetify-marketplace-bin" \
    'caelestia-cli' 'caelestia-shell' \
    'hyprland' 'xdg-desktop-portal-hyprland' 'xdg-desktop-portal-gtk' 'hyprpicker' \
    'cliphist' 'inotify-tools' 'app2unit' 'wireplumber' 'trash-cli' \
    'eza' 'fastfetch' 'jq' 'adw-gtk-theme' "noto-fonts-emoji" \
    'papirus-icon-theme' 'qt5ct-kde' 'qt6ct-kde' 'ttf-jetbrains-mono-nerd' \
    "uwsm" "zoxide" "ttf-font-awesome" "pipewire-pulse" "pipewire-alsa" \
    "ttf-fira-code" "snapper" "btrfs-assistant" "nvidia-dkms" "ufw" "fail2ban" "chezmoi"
    # "hyprpolkitagent"


function setup_service
    echo "archlinux" > /etc/hostname
    echo "127.0.1.1       archlinux" >> /etc/hosts

    sed -i "s/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
    sed -i "s/^#uk_UA.UTF-8 UTF-8/uk_UA.UTF-8 UTF-8/" /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    timedatectl set-timezone Europe/Kyiv
    timedatectl set-ntt true

    systemctl enable fstrim.timer
    systemctl enable --now systemd-resolved.service
    rm -rf /etc/resolv.conf
    ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

    ufw enable
    systemctl enable ufw.service

    systemctl enable fail2ban.service
end

function setup_kernel
   echo "Only booster setting here"
   echo "modules: nvidia
   compression: zstd
   extra_files: nvim
   vconsole: true
   universal: false
   " >> /etc/booster.yaml
end

function setup_pacman
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB

    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

    sed -i "s/^#Color/Color/" /etc/pacman.conf
    sed -i "s/^#ParallelDownloads = /ParallelDownloads" /etc/pacman.conf
    sed -i "/^Color/a ILoveCandy" /etc/pacman.conf
    sed -i '/\[core-testing\]/,/Include/ s/^#//' /mnt/etc/pacman.conf
    sed -i '/\[extra-testing\]/,/Include/ s/^#//' /mnt/etc/pacman.conf
    sed -i '/\[multilib\]/,/Include/ s/^#//' /mnt/etc/pacman.conf
    sed -i '/\[multilib-testing\]/,/Include/ s/^#//' /mnt/etc/pacman.conf
    printf "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" >> /mnt/etc/pacman.conf

    pacman -S paru --noconfirm`
end

function setup_user -a username
    useradd -m -G wheel,power,audio,video,optical,storage,network -s /bin/fish $username
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

    echo "Set password"
    passwd $username

    su $username -c "paru -Syu --noconfirm $packages"


    # replace with chezmoi
    set target /home/$username/.local/share
    if not test -d $target; mkdir -p $target; end

    set src (realpath ./files/home)
    # Ensure destination exists
    if not test -d $target/configs; mkdir -p $target/configs; end

    # Copy all contents (including dotfiles) from source into destination
    cp -a $src/. $target/configs

    # Make sure the default user owns the files and has full access
    chown -R $username:$username $target/configs
    chmod -R u+rwX $target/configs

    set config /home/$username/.config
    for entry in (ls $target/configs)
        echo Creating $entry
        ln -s (realpath $entry) $config/$entry
    end
end


function setup_arch
    setup_service
    setup_kernel
    setup_pacman
    setup_user nicourrrn
end
