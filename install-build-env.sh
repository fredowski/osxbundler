#!/bin/sh -xve

# Copyright (C) 2020 Free Software Foundation, Inc.
# Released under GNU General Public License, either version 3
# or any later option

macportstarfile=macports-1.5.0-1.tgz

bundleinstall=/opt/macports/install

# Download and install the macports build environment for pspp
pushd /opt/macports
curl -o $macportstarfile https://www.hs-augsburg.de/homes/beckmanf/pspp/$macportstarfile
tar -xzf $macportstarfile

cd macports-ports
# Github https repo to avoid ssh auth problems
git remote rm origin
git remote add origin https://github.com/fredowski/macports-ports
#git pull pspp-old
git fetch
git checkout pspp
git branch --set-upstream-to=origin/pspp pspp
git branch --set-upstream-to=origin/master master
git pull

# Replace username fritz
/usr/bin/sed -i '' 's/fritz/travis/g' $bundleinstall/share/macports/install/prefix.mtree
/usr/bin/sed -i '' 's/fritz/travis/g' $bundleinstall/share/macports/install/base.mtree
/usr/bin/sed -i '' 's/fritz/travis/g' $bundleinstall/libexec/macports/lib/port1.0/port_autoconf.tcl

# Use the latest macports environment (remove local repo)
# Only relevant when port selfupdate and upgrade is done
echo "rsync://rsync.macports.org/macports/release/tarballs/ports.tar [default]" > $bundleinstall/etc/macports/sources.conf

#git checkout pspp/1.3.0-1
popd
