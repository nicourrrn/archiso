#! /usr/bin/fish

## Instalation part
set base_packages "base" "base-devel" "booster" "neovim" "iwd" "efibootmgr"  \
    "gvfs" "gvfs-mtp" "xdg-user-dirs" "linux" "linux-firmware" "linux-headers" "dhcpcd" "limine" \
    "btrfs-progs" "openssh" "git" "reflector" "amd-ucode" "fish" "ufw" "fail2ban"

function install_arch -d "Main installation script that call all steps" -a mnt
    reflector --verbose --country UA --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
    pacman -Sy

    pacstrap $mnt $base_packages

    printf "Generate fstab"
    genfstab -U $mnt >> $mnt/etc/fstab

    cp ./install_scripts.fish $mnt/opt/
    arch-chroot $mnt fish -c "source /opt/install_scripts.fish && setup_arch"
    rm $mnt/opt/install_scripts.fish
end

function setup_partition -d "Setup paritions"
    argparse "r/root=" "b/boot=" -- $argv
    or return

    mkfs.btrfs $_flag_r
    mount $_flag_r /mnt

    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snap
    umount /mnt

    mount -o compress=zstd,subvol=@ $_flag_r /mnt
    mkdir -p /mnt/{home,boot,snap}
    mount -o compress=zstd,subvol=@home $_flag_r /mnt/home
    mount -o compress=zstd,subvol=@snap $_flag_r /mnt/snap

    if set -ql _flag_b
        mkfs.fat -F 32 $_flag_b
        mount $_flag_b /mnt/boot
    else
        echo "Mount boot fs to mount point /mnt"
    end
end

## Setting part
set packages "zed" "fish" "zen-browser-bin" "zellij" "alacritty" "btop" "bat" "ripgrep" \
    "thunar" "keepassxc" "vesktop" "steam" "bun" "uv" "rustup" "go" "httpie" "flyctl-bin" \
    "godot" "typst" "cava" "easyeffects" "gimp" "vlc" "just" "xxd" "pipewire" \
    "blueman" "nvidia-dkms" "tree" "zip" "wl-clipboard" "ripgrep" "qemu" \
    "playerctl" "slurp" "dust" "docker" "starship" "git" \
    "spicetify-cli" "spicetify-marketplace-bin" \
    'hyprland' 'xdg-desktop-portal-hyprland' 'xdg-desktop-portal-gtk' 'hyprpicker' \
    'cliphist' 'inotify-tools'  'wireplumber' 'trash-cli' \
    'eza' 'fastfetch' 'jq' 'adw-gtk-theme' "noto-fonts-emoji" \
    'papirus-icon-theme'  'ttf-jetbrains-mono-nerd' \
    "uwsm" "zoxide" "ttf-font-awesome" "pipewire-pulse" "pipewire-alsa" \
    "ttf-fira-code" "snapper" "btrfs-assistant" "nvidia-dkms"  "chezmoi" \
    "vim" "qemu-desktop" "nvidia-utils" "gnu-free-fonts" "pipewire-jack" \
    "lib32-nvidia-utils" "qt6-multimedia-ffmpeg" "hyprpolkitagent" "quickshell" \
    "hyprlauncher" \
    #  'caelestia-cli' 'caelestia-shell' "rar" 'app2unit' 'qt5ct-kde' 'qt6ct-kde' "grip"


function setup_service
    echo "archlinux" > /etc/hostname
    echo "127.0.1.1       archlinux" >> /etc/hosts

    sed -i "s/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
    sed -i "s/^#uk_UA.UTF-8 UTF-8/uk_UA.UTF-8 UTF-8/" /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf

    timedatectl set-timezone Europe/Kyiv
    timedatectl set-ntp true

    systemctl enable fstrim.timer

    # systemctl enable systemd-resolved.service
    # rm -rf /etc/resolv.conf
    # ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

    ufw enable
    systemctl enable ufw.service

    systemctl enable fail2ban.service
end

function setup_kernel
    set -l root_partiton (df /     --output=source | tail -1)
    set -l boot_partiton (df /boot --output=source | tail -1)

    set -l root_uuid (blkid -s UUID -o value $root_partiton)
    set -l boot_uuid (blkid -s UUID -o value $boot_partiton)

    set -l part (echo $boot_partiton | sed -E 's/.*[^0-9]([0-9]+)$/\1/')
    set -l disk (echo $boot_partiton | sed -E 's/(p?[0-9]+)$//')

    if not test -e /boot/EFI/limine/BOOTX64.EFI
        mkdir -p /boot/EFI/limine
        cp /usr/share/limine/BOOTX64.EFI /boot/EFI/limine
        efibootmgr --create --disk $disk --part $part --label "Limine" \
            --loader '\EFI\limine\BOOTX64.EFI' --unicode
    end

    if not test -e /boot/limine/limine.conf
        mkdir /boot/limine
        printf "timeout 5\n" > /boot/limine/limine.conf
    end

    echo "modules: nvidia
compression: zstd
extra_files: nvim
vconsole: true
universal: false" > /etc/booster.yaml

    set -l arch_limine_start "#arch_limine_start"
    set -l arch_limine_end "#arch_limine_end"

    sed -i "/$arch_limine_start/,/$arch_limine_end/d" /boot/limine/limine.conf

    set -l kernels /usr/lib/modules/*

    echo $arch_limine_start >> /boot/limine/limine.conf
    echo "/Arch linux" >> /boot/limine/limine.conf
    for kernel in $kernels
        if not test -d "$kernel"; or test basename ("$kernel") = "modules"
            continue
        end

        if not pacman -Qqo "$kernel/pkgbase" > /dev/null 2>&1
            continue
        end

        set -l pkgbase (cat "$kernel/pkgbase")
        set -l kernel_version (string replace "/usr/lib/modules/" "" "$kernel")
        booster build --force --kernel-version $kernel_version "/boot/booster-$pkgbase.img" &
        install -Dm644 "$kernel/vmlinuz" "/boot/vmlinuz-$pkgbase"

        echo "  // $kernel_version
    protocol: linux
    path: boot():/vmlinuz-$pkgbase
    cmdline: root=UUID=$root_uuid rootflags=subvol=@ rw
    module_path: boot():/booster-$pkgbase.img" >> /boot/limine/limine.conf

    end

    wait
    echo $arch_limine_end >> /boot/limine/limine.conf
end

function setup_pacman
    # pacman.conf
    sed -i "s/^#ParallelDownloads/ParallelDownloads/" /etc/pacman.conf
    sed -i "s/^#Color/Color/" /etc/pacman.conf
    sed -i "/^Color/a ILoveCandy" /etc/pacman.conf
    # Mirrost and repo setup
    for repo in "core-testing" "extra-testing" "multilib" "multilib-testing"
        sed -i "/\[$repo\]/,/Include/ s/^#//" /etc/pacman.conf
    end
    reflector --verbose --country UA --latest 5 --sort rate --save /etc/pacman.d/mirrorlist

    # Chaotic AUI
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    sed -i "/\[chaotic-aur\]/,/Include/d" /etc/pacman.conf
    printf "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" >> /etc/pacman.conf

    #AUR helper
    pacman -Sy --noconfirm paru
end

function setup_user -a username
    useradd -m -G wheel,power,audio,video,optical,storage,network -s /bin/fish $username
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

    passwd $username

    sudo -u $username  paru -Syu --noconfirm $packages
    sudo -u $username  chezmoi init --apply $username
end

function setup_arch -d "Main setup at chroot command"
    setup_service
    setup_kernel
    setup_pacman
    setup_user nicourrrn

    echo "Run reboot and continue setup in system enviroment"
end

# Util scripts

function update_script
    curl -o install_scripts.fish https://raw.githubusercontent.com/nicourrrn/archiso/refs/heads/main/archiso/airootfs/root/install_scripts.fish
    source ./install_scripts.fish
end


argparse "h/help" -- $argv
if set -lq _flag_h
    echo "Run install_arch -r /mnt for install arch"
    echo "Run setup_partition -r /dev/sda2 [-b /dev/sda1] for make btrfs root and fat32 boot"
    echo "Run setup_arch use in arch-chroot envoroment"
else
    echo "Run install_arch -r /mnt"
    echo "Run setup_partition -r /dev/sda2 [-b /dev/sda1] for make btrfs root and fat32 boot"
end
