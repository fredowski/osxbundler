#!/bin/sh -e

# Install macports and all dependencies for pspp 

# Copyright (C) 2020 Free Software Foundation, Inc.
# Released under GNU General Public License, either version 3
# or any later option

# Check if we are on MacOS
if ! test `uname` = "Darwin"; then
    echo "This only works on MacOS"
    exit
fi

# Check if XCode is installed - Assume clang indicates xcode.
if ! test -f /usr/bin/clang; then
    echo "/usr/bin/clang not found - please install XCode CLT"
    exit
fi

topdir=/opt/macports

# This is the installation directory which will be used as macports prefix
# and as pspp configure prefix.
bundleinstall=$topdir/install

export PATH=$bundleinstall/bin:$bundleinstall/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin

# Target macports install directory for the pspp bundle
if test -d $bundleinstall; then
    echo "Found existing macports directory $bundleinstall - continue"
else
    echo "Creating Macports installation in $bundleinstall"
    mkdir $bundleinstall
    # Install macports
    rm -rf /tmp/macports
    mkdir /tmp/macports
    pushd /tmp/macports
    macportsversion=2.6.2
    curl https://distfiles.macports.org/MacPorts/MacPorts-$macportsversion.tar.gz -O
    tar xvzf Macports-$macportsversion.tar.gz
    cd Macports-$macportsversion
    ./configure --prefix=$bundleinstall \
                --with-applications-dir=$bundleinstall/Applications \
                --with-no-root-privileges
    make
    make install
    popd
    rm -rf /tmp/macports
    # Modify the default variants to use quartz
    echo "-x11 +no_x11 +quartz" > $bundleinstall/etc/macports/variants.conf
    # Make the build be compatible with OSX Versions starting with 10.10
    # echo "macosx_deployment_target 10.10" >> $bundleinstall/etc/macports/macports.conf
    # dbus tries to install startup items which are under superuser account
    echo "startupitem_install no"  >> $bundleinstall/etc/macports/macports.conf
    echo "buildfromsource always" >> $bundleinstall/etc/macports/macports.conf
    # Activate step failed due to bsdtar problem 
    echo "hfscompression no"  >> $bundleinstall/etc/macports/macports.conf
    # Use the portfiles from fritz
    echo "file:///$topdir/macports-ports" > $bundleinstall/etc/macports/sources.conf
    echo "rsync://rsync.macports.org/macports/release/tarballs/ports.tar [default]" >> $bundleinstall/etc/macports/sources.conf
fi

# Get the macports port configuration
pushd $topdir
if test -d "./macports-ports"; then
    cd macports-ports
    git pull
else
    git clone --depth 5 --no-single-branch git@github.com:fredowski/macports-ports.git
    cd macports-ports
    git checkout pspp
fi
portindex
popd

# Install the packages for pspp
port -v selfupdate
port upgrade outdated || true
# Install the build dependencies for pspp
port -N install pkgconfig texinfo makeicns cairo fontconfig freetype \
  gettext glib2 gsl libiconv libxml2 ncurses pango readline zlib atk \
  gdk-pixbuf2 gtksourceview3 adwaita-icon-theme spread-sheet-widget

# install gimp and autotools
port -N install gimp
# install the mac gtk-mac-bundler
port -N install gtk-mac-bundler

# Remove install files
port clean --all installed

# Create a tar file of the install directory
pushd $topdir
tar -cvzf macports-pspp.tgz ./install
popd

echo "Done! Installed macports in $bundleinstall"
