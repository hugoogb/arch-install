#!/bin/bash

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'

BOLD='\033[1m'
ITALIC='\033[3m'
NORMAL="\033[0m"

color_print() {
  if [ -t 1 ]; then
    echo -e "$@$NORMAL"
  else
    echo "$@" | sed "s/\\\033\[[0-9;]*m//g"
  fi
}

stderr_print() {
  color_print "$@" >&2
}

warn() {
  stderr_print "$YELLOW$1"
}

error() {
  stderr_print "$RED$1"
  exit 1
}

info() {
  color_print "$CYAN$1"
}

ok() {
  color_print "$GREEN$1"
}

program_exists() {
  command -v $1 &> /dev/null
}

ACTUAL_DIR=`pwd`
ARCH_INSTALL_DIR=$HOME/arch-install
TEMP_DIR=$HOME/temp
CONFIG_DIR=$HOME/.config
LOCAL_BIN_DIR=$HOME/.local/bin

if [ ! -d $TEMP_DIR ]; then
  mkdir $TEMP_DIR
fi

if [ ! -d $CONFIG_DIR ]; then
  mkdir $CONFIG_DIR
fi

if [ ! -d $LOCAL_BIN_DIR ]; then
  mkdir -p $LOCAL_BIN_DIR
fi

ok "Welcome to @hugoogb dotfiles!!!"
info "Starting bootstrap process..."

sleep 1

if ! program_exists "git"; then
  error "ERROR: git is not installed"
fi

# check if running in laptop or desktop
laptop_or_desktop() {
  info "Checking if you are in laptop or desktop..."

  POWER_DIR=/sys/class/power_supply

  if [ "$(ls -A $POWER_DIR)" ]; then
    ok "Running in LAPTOP"
  else
    ok "Running in DESKTOP"
  fi
}

# Dotfiles update
update_dotfiles() {
  cd $ARCH_INSTALL_DIR
  info "Updating dotfiles..."
  git config --global pull.rebase false
  git pull origin master
  cd $ACTUAL_DIR
}

clone_dotfiles() {
  if [ -d $ARCH_INSTALL_DIR ]; then
    warn "WARNING: dotfiles directory already exists"
    update_dotfiles
  else
    info "Cloning dotfiles..."
    git clone https://github.com/hugoogb/arch-install.git $ARCH_INSTALL_DIR
    update_dotfiles
  fi

  ok "Dotfiles cloned and updated"
}

clone_update_repo() {
  laptop_or_desktop
  clone_dotfiles
}

# Installing
arch_pkg_install() {
  info "Installing pkg(s)..."

  # Install all pkgs of the list
  sudo pacman -S --needed --noconfirm - < $HOME/arch-install/pkglist/pacman-pkglist.txt

  info "Setting up pkg(s)..."

  # lightdm
  sudo systemctl enable lightdm

  # Notifications
  sudo cp -fv $HOME/arch-install/services/notifications/org.freedesktop.Notifications.service /usr/share/dbus-1/services/

  # Bluetooth
  sudo systemctl enable bluetooth.service
  sudo cp -fv $HOME/arch-install/services/bluetooth/main.conf /etc/bluetooth/

  # SSH
  sudo systemctl enable sshd
}

# AUR helper (yay) install
aur_helper() {
  info "Installing AUR helper (yay)..."

  if ! program_exists "yay"; then
    git clone https://aur.archlinux.org/yay-git.git $TEMP_DIR/yay
    cd $TEMP_DIR/yay
    makepkg -si
    cd $ACTUAL_DIR
  else
    warn "WARNING: yay already installed"
  fi

  if ! program_exists "yay"; then
    error "ERROR: yay is not installed, rerun script or install yay manually, then execute the script again"
  fi
}

# Install all AUR packages
aur_pkg_install() {
  info "Installing AUR pkg(s)..."

  # Install all pkgs of the list
  yay -S --needed --nocleanmenu --nodiffmenu --noeditmenu --noupgrademenu - < $HOME/arch-install/pkglist/yay-pkglist.txt

  # Bluetooth autoconnect trusted devices
  sudo systemctl enable bluetooth-autoconnect
}

arch_setup(){
  info "Setting up .xprofile..."

  cp -fv $HOME/arch-install/.xprofile $HOME/

  info "Downloading material black blueberry theme and custom mouse..."

  mkdir $TEMP_DIR/themes
  cd $TEMP_DIR/themes

  THEME=/usr/share/themes/Material-Black-Blueberry
  ICON_THEME=/usr/share/icons/Material-Black-Blueberry-Suru
  CURSOR_THEME=/usr/share/icons/Breeze

  if [ ! -d $THEME ]; then
    curl https://raw.githubusercontent.com/hugoogb/themes/master/Material-Black-Blueberry_1.9.1.zip -o Material-Black-Blueberry.zip
    unzip -q Material-Black-Blueberry.zip
    sudo cp -rf $TEMP_DIR/themes/Material-Black-Blueberry /usr/share/themes/
  else
    warn "WARNING: Material Black Blueberry theme already downloaded"
  fi

  if [ ! -d $ICON_THEME ]; then
    curl https://raw.githubusercontent.com/hugoogb/themes/master/Material-Black-Blueberry-Suru_1.9.1.zip -o Material-Black-Blueberry-Suru.zip
    unzip -q Material-Black-Blueberry-Suru.zip
    sudo cp -rf $TEMP_DIR/themes/Material-Black-Blueberry-Suru /usr/share/icons/
  else
    warn "WARNING: Material Black Blueberry Suru icon theme already downloaded"
  fi

  if [ ! -d $CURSOR_THEME ]; then
    curl https://raw.githubusercontent.com/hugoogb/themes/master/165371-Breeze.tar.gz -o Breeze.tar.gz
    tar -xf Breeze.tar.gz
    sudo cp -rf $TEMP_DIR/themes/Breeze /usr/share/icons/
  else
    warn "WARNING: Breeze cursor theme already downloaded"
  fi

  cd $ACTUAL_DIR

  sudo cp -fv $HOME/arch-install/themes/index.theme /usr/share/icons/default/

  cp -fv $HOME/arch-install/gtk/.gtkrc-2.0 $HOME/
  cp -rfv $HOME/arch-install/gtk/gtk-3.0 $HOME/.config/
}

# grub themes installation, configure them with grub-customizer
grub_themes_install() {
  info "Downloading vimix grub theme..."

  GRUB_THEME_DIR=/boot/grub/themes/

  GRUB_VIMIX_THEME_DIR=/boot/grub/themes/Vimix
  VIMIX_CLONE_DIR=$TEMP_DIR/grub2-theme-vimix

  if [ ! -d $GRUB_VIMIX_THEME_DIR ]; then
    git clone https://github.com/Se7endAY/grub2-theme-vimix.git $VIMIX_CLONE_DIR
    sudo cp -rf $VIMIX_CLONE_DIR/Vimix $GRUB_THEME_DIR
  else
    warn "WARNING: Vimix grub theme already downloaded"
  fi
}

# lightdm setup
lightdm_setup() {
  info "Setting up lightdm..."

  sudo cp -fv $HOME/arch-install/lightdm/lightdm.conf /etc/lightdm/
  sudo cp -fv $HOME/arch-install/lightdm/lightdm-webkit2-greeter.conf /etc/lightdm/
}

arch_install() {
    arch_pkg_install
    aur_helper
    aur_pkg_install
    arch_setup
    grub_themes_install
    lightdm_setup
}

main() {
    clone_update_repo
    arch_install
}

main

rm -rf $TEMP_DIR

ok "Arch Linux install done!!!"
warn "WARNING: don't forget to reboot in order to get everything working properly"
