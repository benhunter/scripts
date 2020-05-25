#!/bin/bash

# Setup Kali from installation
# Tested 2020-05-25 with Kali 2020.2 installer, x64, in VirtualBox.

# $ git clone https://github.com/benhunter/scripts
# $ chmod +x ./scripts/setup-kali.sh; ./scripts/setup-kali.sh

# Update repo in place
# https://stackoverflow.com/questions/1125968/how-do-i-force-git-pull-to-overwrite-local-files
# git reset --hard HEAD; git pull


# Prompt for sudo if not root.
if [[ $EUID != 0 ]]; then
	echo $?
	sudo "$0" "$@"
	exit $?
fi

echo "Running as root."

CWD=$(pwd)  # store working directory to cleanly return to it later

# Get path to script that is running.
# https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# update-apt.sh must be in the same directory
if [[ -e $DIR/update-apt.sh ]]; then
    echo "Running update-apt.sh"
    echo $DIR
    chmod +x $DIR/update-apt.sh
    $DIR/update-apt.sh
else
    echo "Could not find update-apt.sh. Exiting."
    exit 
fi

# Install more apt packages
read -p "Press Enter key to continue."
echo "Installing apt packages..."
# VirtualBox guest additions are auto-installed?
apt -y install kali-linux-everything  # https://tools.kali.org/kali-metapackages

# Python pip3, pip for virtual environments
apt -y install python3-venv
apt -y install python-pip

apt -y install htop
apt -y install ssss  # ssss - Shamir's secret sharing scheme
apt -y install libimage-exiftool-perl  # ExifTool https://github.com/exiftool/exiftool
apt -y install ghex  # Hex editor for GNOME https://wiki.gnome.org/Apps/Ghex

# Install special software
read -p "Press Enter key to continue."  # TODO remove

# Snap (for VSCode)
echo "Installing and enabling snap..."
apt -y install snapd  # Install snapcraft.io store
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
# if [[ -e ~/.bash_profile ]]; then
echo "Updating ~/.bash_profile..."
echo 'export PATH=$PATH:/snap/bin' >> ~/.bash_profile
# fi

read -p "Press Enter key to continue."  # TODO remove

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

read -p "Press Enter key to continue."  # TODO remove

# Ghidra

# Download git repos

# pwntools
# Impacket

# RSA CTF Tool
mkdir ~/GitHub
cd ~/GitHub
git clone https://github.com/Ganapati/RsaCtfTool
cd ~/GitHub/RsaCtfTool
python3 -m venv --system-site-packages venv
source ./venv/bin/activate
sudo apt install libmpfr-dev
pip install -r requirements.txt 
# SageMath package was removed from kali apt...
deactivate  # exit virtual environment
cd ~

read -p "Press Enter key to continue."  # TODO remove

# config anything else
echo 'alias ll="ls -lahF"' >> ~/.bash_aliases
echo 'alias tt="tree -lahfs"' >> ~/.bash_aliases

read -p "Press Enter key to continue."  # TODO remove

# Unpack RockYou.txt wordlist
gunzip /usr/share/wordlists/rockyou.txt.gz

# Firefox Addons

# sshd

# Powerline for Bash, tmux

read -p "Press Enter key to continue."  # TODO remove

# Cleanup
cd $CWD
echo "Please reboot (snapshot if needed)..."
