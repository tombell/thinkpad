#!/usr/bin/env bash
set -euo pipefail

sudo sed -i 's/^#Color/Color/' /etc/pacman.conf

sudo pacman -Syu --noconfirm --needed

sudo sed -i '/^OPTIONS=(/s/\(^.*\s\)\(debug\)\(\s.*$\)/\1!debug\3/' /etc/makepkg.conf

sudo pacman -S --noconfirm --needed base-devel git

if ! command -v yay &>/dev/null; then
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm --rmdeps
  cd ..
  rm -fr yay
fi

sudo pacman -S --noconfirm --needed - <<EOF
bluetui
brightnessctl
btop
fastfetch
fd
ffmpeg
fzf
ghostty
gnome-themes-extra
greetd
hypridle
hyprland
hyprlock
hyprpaper
hyprshot
imagemagick
impala
imv
less
libyaml
mako
man-db
mise
neovim
openssh
polkit-gnome
qt6ct
ripgrep
rofi
sbctl
swayosd
unzip
usage
uwsm
waybar
wireless-regdb
wiremix
xdg-desktop-portal-gtk
xdg-desktop-portal-hyprland
xdg-user-dirs
zsh
zsh-autosuggestions
zsh-completions
EOF

if [ ! -d "$HOME/.dotfiles" ]; then
  git clone https://github.com/tombell/dotfiles.git "$HOME/.dotfiles"
fi

yay -S --noconfirm --needed --removemake rcm
"$HOME/.dotfiles/scripts/linux.sh"

if command -v mise &>/dev/null; then
  mise install
fi

if [ ! -f "/etc/default/limine" ]; then
  PARTUUID=$(blkid | grep 'TYPE="crypto_LUKS"' | sed -n 's/.*PARTUUID="\([^-"]*\(-[^"]*\)\{3\}\)".*/\1/p')

  sudo tee /etc/default/limine <<EOF >/dev/null
KERNEL_CMDLINE[default]+="cryptdevice=PARTUUID=$PARTUUID:root"
KERNEL_CMDLINE[default]+="root=/dev/mapper/root rootflags=subvol=@ rw rootfstype=btrfs zswap.enabled=0"
KERNEL_CMDLINE[default]+="quiet loglevel=0 systemd.show_status=auto udev.log_level=0 vt.global_cursor_default=0 modprobe.blacklist=sp5100_tco"

ENABLE_UKI=yes

ENABLE_LIMINE_FALLBACK=yes

FIND_BOOTLOADERS=no

BOOT_ORDER="*, *fallback, Snapshots"

MAX_SNAPSHOT_ENTRIES=5
SNAPSHOT_FORMAT_CHOICE=5
EOF
fi

if [ ! -f "/boot/limine.conf" ]; then
  sudo tee /boot/limine.conf <<EOF >/dev/null
default_entry: 2
interface_branding: Arch Linux Bootloader
interface_branding_color: 2
hash_mismatch_panic: no

backdrop: 1a1b26

term_palette: 15161e;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;a9b1d6
term_palette_bright: 414868;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;c0caf5

term_foreground: c0caf5
term_background: 1a1b26
term_foreground_bright: c0caf5
term_background_bright: 24283b

EOF
fi

yay -S --noconfirm --needed --removemake zulu-21-bin
yay -S --noconfirm --needed --removemake limine-mkinitcpio-hook limine-snapper-sync snap-pac

if ! sudo snapper list-configs 2>/dev/null | grep -q "root"; then
  sudo snapper -c root create-config /
fi

if ! sudo snapper list-configs 2>/dev/null | grep -q "home"; then
  sudo snapper -c home create-config /home
fi

sudo sed -i 's/^TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' /etc/snapper/configs/{root,home}
sudo sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="5"/' /etc/snapper/configs/{root,home}
sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT="10"/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/{root,home}

sudo systemctl enable --now limine-snapper-sync.service

if ! efibootmgr | grep -qi "Arch Linux UKI"; then
  sudo efibootmgr --create \
    --disk "$(findmnt -n -o SOURCE /boot | sed 's/p\?[0-9]*$//')" \
    --part "$(findmnt -n -o SOURCE /boot | grep -o 'p\?[0-9]*$' | sed 's/^p//')" \
    --label "Arch Linux UKI" \
    --loader "\\EFI\\Linux\\$(cat /etc/machine-id)_linux.efi"
fi

yay -S --noconfirm --needed --removemake apple-fonts noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-iosevkaterm-nerd

if [ ! -f "$HOME/.local/share/fonts/IosevkaCustom.ttc" ]; then
  mkdir -p "$HOME/.local/share/fonts"
  curl -Os https://tombell-homebrew-assets.s3.us-east-1.amazonaws.com/IosevkaCustom-33.3.0.zip
  unzip IosevkaCustom-*.zip
  mv IosevkaCustom.ttc "$HOME/.local/share/fonts/"
  rm IosevkaCustom-*.zip
fi

if ! grep -qi "hyprland" "/etc/greetd/config.toml"; then
  sudo tee /etc/greetd/config.toml <<EOF >/dev/null
[terminal]
vt = 1

[default_session]
command = "agreety --cmd /usr/bin/zsh"
user = "greeter"

[initial_session]
command = "uwsm start -- hyprland.desktop"
user = "tombell"
EOF
fi

sudo systemctl enable greetd.service

yay -S --noconfirm --needed --removemake - <<EOF
1password
1password-cli
discord
google-chrome
telegram-desktop
EOF

if [ $SHELL != "/usr/bin/zsh" ]; then
  chsh -s /usr/bin/zsh
fi

gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
