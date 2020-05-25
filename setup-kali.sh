#!/bin/bash

# Setup Kali from installation
# Tested 2020-05-25 with Kali 2020.2 installer, x64, in VirtualBox.

# Prompt for sudo if not root.
if [[ $EUID != 0 ]]; then
	echo $?
	sudo "$0" "$@"
	exit $?
fi

echo "Running as root."

cwd=$(pwd)  # store working directory to cleanly return to it later

# update-apt.sh must be in the same directory
if [[ -e ./update-apt.sh ]]; then
    echo "Running update-apt.sh"
    chmod +x ./update-apt.sh
    update-apt.sh  # ./ ???????
else
    echo "Could not find update-apt.sh. Exiting."
    exit 
fi

# Install more apt packages
read -p "Press any key to continue."
echo "Installing apt packages..."
# VirtualBox guest additions are auto-installed?
apt install kali-linux-everything  # https://tools.kali.org/kali-metapackages

# Python pip3, pip for virtual environments
apt install python3-venv
apt install python-pip

apt install htop
apt install ssss  # ssss - Shamir's secret sharing scheme
apt install libimage-exiftool-perl  # ExifTool https://github.com/exiftool/exiftool
apt install ghex  # Hex editor for GNOME https://wiki.gnome.org/Apps/Ghex

# Install special software
read -p "Press any key to continue."  # TODO remove

# Snap (for VSCode)
echo "Installing and enabling snap..."
apt install snapd  # Install snapcraft.io store
# Additionally, enable and start both the snapd and the snapd.apparmor services with the following command:
systemctl enable --now snapd apparmor
# To test your system, install the hello-world snap and make sure it runs correctly:
# $ snap install hello-world
# $ hello-world 6.3 from Canonical✓ installed
# $ hello-world
# Hello World!
# Install Snap Store App
# $ sudo snap install snap-store

# Add snap to path and update .bash_profile
# https://github.com/thoughtbot/til/blob/master/bash/bash_profile_vs_bashrc.md
if [[ -e ~/.bash_profile ]]; then
    echo "Updating .bash_profile..."
    echo 'export PATH=$PATH:/snap/bin' >> ~/.bash_profile
fi

read -p "Press any key to continue."  # TODO remove

# Visual Studio Code / VSCode
# https://snapcraft.io/docs/installing-snap-on-kali
echo "Installing VSCode..."
snap install --classic code
# To execute:
#   snap run code
#   code  # if '/snap/bin' is in $PATH

# TODO How to add a shortcut to the start menu?

# Install Zsteg
# https://0xrick.github.io/lists/stego/
# sudo gem install zsteg

# sudo 
# sudo 

read -p "Press any key to continue."  # TODO remove

# Download git repos

# RSA CTF Tool
mkdir ~/GitHub
git clone https://github.com/Ganapati/RsaCtfTool
cd ~/GitHub/RsaCtfTool
python3 -m venv --system-site-packages venv
source ./venv/bin/activate
sudo apt install libmpfr-dev
pip install -r requirements.txt 
# SageMath package was removed from kali apt...
deactivate  # exit virtual environment

read -p "Press any key to continue."  # TODO remove

# config anything else
echo 'alias ll="ls -lahF"' >> ~/.bash_aliases
echo 'alias tt="tree -lahfs"' >> ~/.bash_aliases

read -p "Press any key to continue."  # TODO remove

# Unpack RockYou.txt wordlist
gunzip /usr/share/wordlists/rockyou.txt.gz

# Firefox Addons

# sshd

# Powerline for Bash, tmux

read -p "Press any key to continue."  # TODO remove

# Cleanup
cd $cwd
echo "Please reboot (snapshot if needed)..."
