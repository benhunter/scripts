#!/bin/bash

# Setup Kali from installation
# Tested 2020-05-25 with Kali 2020.2 installer, x64, in VirtualBox.

# $ git clone https://github.com/benhunter/scripts
# $ chmod +x ./scripts/setup-kali.sh; ./scripts/setup-kali.sh

# Update repo in place
# https://stackoverflow.com/questions/1125968/how-do-i-force-git-pull-to-overwrite-local-files
# git reset --hard HEAD; git pull

# Pause for debugging if needed:
# read -p "Press Enter key to continue."  # TODO remove


# Prompt for sudo if not root.
if [[ $EUID != 0 ]]; then
	echo $?
	sudo "$0" "$@"
	exit $?
fi

echo "Running as root."

CWD=$(pwd)  # store working directory to cleanly return to it later
echo '$SUDO_USER' $SUDO_USER
HOME_DIR=$(eval echo ~`logname`)  # Home directory of the user running the script.
echo '$HOME_DIR' $HOME_DIR

# Get path to script that is running.
# https://stackoverflow.com/questions/59895/how-to-get-the-source-directory-of-a-bash-script-from-within-the-script-itself
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
echo '$SCRIPT_DIR' $SCRIPT_DIR
# echo '~' ~

# update-apt.sh must be in the same directory
if [[ -e $SCRIPT_DIR/update-apt.sh ]]; then
    echo "Running update-apt.sh"
    chmod +x $SCRIPT_DIR/update-apt.sh
    $SCRIPT_DIR/update-apt.sh
else
    echo "Could not find update-apt.sh. Exiting."
    exit 
fi

# Install more apt packages
echo "Installing apt packages..."
# VirtualBox guest additions are auto-installed?
apt -y install kali-linux-everything  # https://tools.kali.org/kali-metapackages

# More packages.
# Htop, tree, gobuster
# Python pip3, pip for virtual environments
# ssss - Shamir's secret sharing scheme
# ExifTool https://github.com/exiftool/exiftool
# Hex editor for GNOME https://wiki.gnome.org/Apps/Ghex
apt -y install htop tree gobuster python3-venv python-pip ssss libimage-exiftool-perl ghex jq powerline fonts-powerline joplin

# Install special software

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
echo 'export PATH=$PATH:/snap/bin' >> $HOME_DIR/.bash_profile
chown $SUDO_USER:$SUDO_USER $HOME_DIR/.bash_profile
# fi

# Visual Studio Code / VSCode
# TODO check out VSCodium https://vscodium.com/
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

# Ghidra
cd $HOME_DIR/Downloads
# curl -s https://api.github.com/repos/NationalSecurityAgency/ghidra/tags | grep -m1 zip | cut -d '"' -f 4 | wget -qi -
# GHIDRA_GITHUB=`curl -s https://api.github.com/repos/NationalSecurityAgency/ghidra/tags`
# GHIDRA_ZIP=`echo $GHIDRA_GITHUB | jq '.[0].name'`
# GHIDRA_ZIP_URL=`echo $GHIDRA_GITHUB | jq '.[0].zipball_url'`
# wget $GHIDRA_ZIP_URL

GHIDRA_VERSION=9.1.2
GHIDRA_ZIP=ghidra_9.1.2_PUBLIC_20200212.zip
wget "https://ghidra-sre.org/$GHIDRA_ZIP"
chown $SUDO_USER:$SUDO_USER $GHIDRA_ZIP
unzip $GHIDRA_ZIP
chown -R $SUDO_USER:$SUDO_USER ghidra_"$GHIDRA_VERSION"_PUBLIC
mv ghidra_"$GHIDRA_VERSION"_PUBLIC /opt/
cd $HOME_DIR

# Download git repos

# RSA CTF Tool
mkdir $HOME_DIR/GitHub
cd $HOME_DIR/GitHub
git clone https://github.com/Ganapati/RsaCtfTool
if [[ -d ./RsaCtfTool ]]; then
    cd ./RsaCtfTool
    python3 -m venv --system-site-packages venv
    source ./venv/bin/activate
    sudo apt -y install libmpc-dev  # and libmpfr-dev ?
    pip install -r requirements.txt 
    # SageMath package was removed from kali apt...
    deactivate  # exit virtual environment

    chown -R $SUDO_USER:$SUDO_USER $HOME_DIR/GitHub

    cd $HOME_DIR
else
    echo "FAILED: git clone https://github.com/Ganapati/RsaCtfTool"
    exit
fi

# Install Python Packages
pip3 install pwntools
# Output:
#   WARNING: The scripts asm, checksec, common, constgrep, cyclic, debug, disablenx, disasm, elfdiff, elfpa
# tch, errno, hex, main, phd, pwn, pwnstrip, scramble, shellcraft, template, unhex and update are installed
#  in '/home/kali/.local/bin' which is not on PATH.                                                        
#   Consider adding this directory to PATH or, if you prefer to suppress this warning, use --no-warn-script
# -location.

# config anything else
echo 'alias ll="ls -lahF"' >> $HOME_DIR/.bash_aliases
echo 'alias tt="tree -lahfs"' >> $HOME_DIR/.bash_aliases
chown $SUDO_USER:$SUDO_USER $HOME_DIR/.bash_aliases

# Unpack RockYou.txt wordlist
gunzip /usr/share/wordlists/rockyou.txt.gz
# TODO check owner of rockyou

# Firefox Addons

# sshd

# Powerline for Bash
echo >> $HOME_DIR/.bashrc
echo '# Powerline' >> $HOME_DIR/.bashrc
echo '# config goes in ~/.confg/powerline/config.json' >> $HOME_DIR/.bashrc
echo 'if [ -f `which powerline-daemon` ]; then' >> $HOME_DIR/.bashrc
echo '  powerline-daemon -q' >> $HOME_DIR/.bashrc
echo '  POWERLINE_BASH_CONTINUATION=1' >> $HOME_DIR/.bashrc
echo '  POWERLINE_BASH_SELECT=1' >> $HOME_DIR/.bashrc
echo '  . /usr/share/powerline/bindings/bash/powerline.sh' >> $HOME_DIR/.bashrc
echo 'fi' >> $HOME_DIR/.bashrc
echo >> $HOME_DIR/.bashrc

# Powerline for tmux
echo 'source "/usr/share/powerline/bindings/tmux/powerline.conf"' >> $HOME_DIR/.tmux.conf
echo >> $HOME_DIR/.tmux.conf
chown $SUDO_USER:$SUDO_USER $HOME_DIR/.tmux.conf
echo >> $HOME_DIR/.bash_profile
echo '. ~/.bashrc' >> $HOME_DIR/.bash_profile
echo >> $HOME_DIR/.bash_profile

# Cleanup
cd $CWD  # Go back to the directory where the script started.
echo "Please reboot (snapshot if needed)..."
