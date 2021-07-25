#!/bin/bash
# Update systems using apt package manager. Ubuntu, Kali.

# Prompt for sudo if not root.
if [ $EUID != 0 ]; then
	echo $?
	sudo "$0" "$@"
	exit $?
fi

echo "Updating..."
apt-get update
apt-get -y upgrade
apt-get dist-upgrade
apt-get clean
apt-get -y autoremove
