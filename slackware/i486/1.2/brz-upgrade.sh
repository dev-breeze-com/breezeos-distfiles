#!/bin/sh
#
# GNU GENERAL PUBLIC LICENSE -- Version 3
#
# Copyright 2015 Tsert.com, All Rights Reserved
#
# Redistribution and use of this script, with or without modification, is 
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
if [ "$EUID" -gt 0 ]; then
	echo "brz-upgrade.sh: execute only as root !"
	exit 1
fi

SLACKWARE=""

if [ ! -f $(pwd)/brz-upgrade.sh ]; then
	echo "Execute script from the folder where it is stored !"
	exit 1
fi

while [ $# -gt 0 ]; do
	case $1 in
		"-slack"|"--slack")
			SLACKWARE="-S slackware"
			shift 1 ;;

		"-force"|"--force")
			FORCE="-f"
			shift 1 ;;

		*)
			echo "Invalid argument $1"
			exit 1
			shift 1 ;;
	esac
done

CACHEDIR="/var/cache/brzpkg/archives/"

mkdir -p $CACHEDIR
mkdir -p /etc/brzpkg

PACKAGES="admin/brzpkg_2.0.0_i486.tkg admin/brzctl_1.2.0_i486.tkg network/nettle_2.7.1_i486.tkg database/sqlite_3.7.17_i486.tkg libs/popt_1.16_i486.tkg libs/glib2_2.36.4_i486.tkg"

wget --no-check-certificate -O /etc/brzpkg/breezeos.asc \
	https://breeze.tsert.com/distfiles/slackware/i486/1.2/GPG_KEY

if [ ! -s /etc/brzpkg/breezeos.asc ]; then
	echo "Failed to download the Breeze:OS GnuPG key !"
	exit 1
fi

SLACK_KEYS="GPG_KEY.slackware GPG_KEY.salix GPG_KEY.slacky"

for key in $SLACK_KEYS ; do

	bkey="`echo "$key" | cut -f2 -d'.'`"

	wget --no-check-certificate -O /etc/brzpkg/${bkey}.asc \
		https://breeze.tsert.com/distfiles/slackware/$key

	if [ ! -s /etc/brzpkg/${bkey}.asc ]; then
		echo "Failed to download the '$bkey' GnuPG key !"
		exit 1
	fi
done

GPG_KEYS="breezeos.asc slackware.asc salix.asc slacky.asc"

for key in $GPG_KEYS ; do
	if ! gpg --import /etc/brzpkg/$key ; then
		echo "Failed to import the '$key' GnuPG key"
		exit 1
	fi
done

wget --no-check-certificate -O $CACHEDIR/brz-upgrade.sh.asc \
	https://breeze.tsert.com/distfiles/slackware/i486/1.2/brz-upgrade.sh.asc

if [ ! -s $CACHEDIR/brz-upgrade.sh.asc ]; then
	echo "Failed to download the GnuPG signature of the upgrade script !"
	exit 1
fi

gpg --verify $CACHEDIR/brz-upgrade.sh.asc $(pwd)/brz-upgrade.sh

if [ "$?" != 0 ]; then
	echo "Failed to verify upgrade script !"
	exit 1
fi

cd /

for pkgentry in $PACKAGES; do

	section="`dirname $pkgentry`"
	pkg="`basename $pkgentry`"

	echo "Attempting to retrieve package $pkg ..."

	wget -O $CACHEDIR/$pkg \
		http://breeze.tsert.com/archives/slackware/i486/1.2/$section/$pkg

	if [ "$?" != 0 ]; then
		echo "Failed to download package $pkg !"
		exit 1
	fi

	wget -O $CACHEDIR/${pkg}.asc \
		http://breeze.tsert.com/archives/slackware/i486/1.2/$section/${pkg}.asc

	if [ "$?" != 0 ]; then
		echo "Failed to download package signature for $pkg !"
		exit 1
	fi

	gpg --quiet --verify $CACHEDIR/${pkg}.asc $CACHEDIR/$pkg

	if [ "$?" != 0 ]; then
		echo "Failed to verify package $pkg !"
		exit 1
	fi

	unzip -qq -x -c $CACHEDIR/$pkg archive.txz | tar -C / --xz -xf -

	if [ "$?" = 0 ]; then
		if [ -f /install/doinst.sh ]; then
			/bin/sh /install/doinst.sh
			unlink /install/doinst.sh
		fi
	else
		echo "Failed to unpack package $pkg !"
		exit 1
	fi
done

if [ -x /sbin/brzpkg ]; then
	/sbin/ldconfig
	/sbin/brzpkg $FORCE -u 1.2 $SLACKWARE
fi

exit 0
