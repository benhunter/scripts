#!/bin/bash
# if not root, run as root
if [ $EUID != 0 ]; then
	echo $?
	sudo "$0" "$@"
	exit $?
fi

apt-get update
apt-get -y upgrade
apt-get dist-upgrade
apt-get clean
apt-get -y autoremove
