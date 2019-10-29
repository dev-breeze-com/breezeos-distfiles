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

ARCH="i486"
VERSION="1.1"
SLACKWARE=false

if [ ! -f $(pwd)/brz-upgrade.sh ]; then
	echo "Execute script from the folder where it is stored !"
	exit 1
fi

while [ $# -gt 0 ]; do
	case $1 in
		"-v"|"--version")
			shift 1
			VERSION="$VERSION"
			shift 1 ;;

		"-slack"|"--slack")
			SLACKWARE=true
			shift 1 ;;

		"-i486"|"--i486")
			ARCH="i486"
			shift 1 ;;

		"-amd64"|"--amd64")
			ARCH="amd64"
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

PACKAGES="admin/brzpkg_1.1.0_i486.tkg libs/libmxml_2.8.0_i486.tkg libs/libdbi_0.9.0_i486.tkg libs/libdbi-drivers_0.9.0_i486.tkg database/sqlite_3.7.17_i486.tkg libs/popt_1.16_i486.tkg"

mkdir -p /etc/packager/
mkdir -p /var/cache/packages/archives/

wget -O /etc/packager/breezeos.asc http://www.breezeos.com/distfiles/GPG_KEY

if [ ! -s /etc/packager/breezeos.asc ]; then
	echo "Failed to download the Breeze:OS GnuPG key !"
	exit 1
fi

wget -O /var/cache/packages/archives/brz-upgrade.sh.asc \
	http://www.breezeos.com/distfiles/slackware/i486/1.1/brz-upgrade.sh.asc

if [ ! -s /var/cache/packages/archives/brz-upgrade.sh.asc ]; then
	echo "Failed to download the GnuPG signature of the upgrade script !"
	exit 1
fi

gpg --import /etc/packager/breezeos.asc

if [ "$?" != 0 ]; then
	echo "Failed to import the Breeze:OS GnuPG key"
	exit 1
fi

gpg --verify \
	/var/cache/packages/archives/brz-upgrade.sh.asc \
	$(pwd)/brz-upgrade.sh

if [ "$?" != 0 ]; then
	echo "Failed to verify upgrade script !"
	exit 1
fi

for pkg in $PACKAGES; do

	section="`dirname $pkg`"
	pkg="`basename $pkg`"

	echo "Attempting to retrieve package $pkg ..."

	wget -O /var/cache/packages/archives/$pkg \
		http://www.breezeos.com/archives/slackware/i486/1.1/$section/$pkg

	if [ "$?" != 0 ]; then
		echo "Failed to download package $pkg !"
		exit 1
	fi

	wget -O /var/cache/packages/archives/${pkg}.asc\
		http://www.breezeos.com/archives/slackware/i486/1.1/$section/${pkg}.asc

	if [ "$?" != 0 ]; then
		echo "Failed to download package signature for $pkg !"
		exit 1
	fi

	gpg --quiet --verify /var/cache/packages/archives/${pkg}.asc \
		/var/cache/packages/archives/$pkg

	if [ "$?" != 0 ]; then
		echo "Failed to verify package $pkg !"
		exit 1
	fi

	unzip -qq -x -c /var/cache/packages/archives/$pkg \
		archive.txz | tar -C / --xz -xf -

	if [ "$?" != 0 ]; then
		echo "Failed to unpack package $pkg !"
		exit 1
	fi
done

if [ "$?" = 0 -a -x /sbin/brzpkg ]; then
	if [ "$SLACKWARE" = true ]; then
		/sbin/brzpkg $FORCE -u 1.1 -S slackware
	else
		/sbin/brzpkg $FORCE -u 1.1
	fi
fi

exit 0
