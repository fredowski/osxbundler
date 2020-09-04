#!/bin/bash -xve

# Install macports and all dependencies for pspp 

# Copyright (C) 2020 Free Software Foundation, Inc.
# Released under GNU General Public License, either version 3
# or any later option

echo `date`

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
    macportsversion=2.6.3
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
    # Make the build compatible with previous OSX Versions
    # echo "macosx_deployment_target 10.7" >> $bundleinstall/etc/macports/macports.conf
    # dbus tries to install startup items which are under superuser account
    echo "startupitem_install no"  >> $bundleinstall/etc/macports/macports.conf
    echo "buildfromsource always" >> $bundleinstall/etc/macports/macports.conf
    # Activate step failed due to bsdtar problem 
    echo "hfscompression no"  >> $bundleinstall/etc/macports/macports.conf
    # Use the portfiles from fritz
    echo "file://$topdir/macports-ports" > $bundleinstall/etc/macports/sources.conf
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
echo `date`
# Install the packages for pspp
port -v selfupdate
port upgrade outdated || true
# Install the build dependencies for pspp
# libgcc10 requires to deactivate unwind-header - so build first
# otherwise the build stops and libunwind-headers has to be
# deactivated
port -N install cctools
port -N deactivate libunwind-headers
port -N install libgcc10
port -N unsetrequested cctools libgcc10

buildports="pkgconfig texinfo makeicns cairo fontconfig freetype \
  gettext glib2 gsl libiconv libxml2 ncurses readline zlib atk \
  gtksourceview3 gtk3 adwaita-icon-theme spread-sheet-widget \
  automake autoconf gperf m4 \
  gimp gtk-mac-bundler"

port -N install $buildports

# This are the core ports which need to be compiled with
# MACOSX_DEPLOYMENT_TARGET. Derived with findports.py
# The ports provide the libraries for psppire
coreports="atk brotli bzip2 cairo expat fontconfig freetype fribidi \
  gdk-pixbuf2 gettext-runtime glib2 graphite2 gsl gtk3 gtksourceview3 \
  harfbuzz icu libepoxy libffi libiconv libpixman libpng libxml2 ncurses \
  ossp-uuid pango pcre readline spread-sheet-widget xz zlib"

# python38 does not build with deploymenttarget 10.7.
# Not rebuilding python38 results in build failure with a different deployment
# target for atk due to gobject-introspection
echo "macosx_deployment_target 10.5" >> $bundleinstall/etc/macports/macports.conf
port -N uninstall python38
port -N install python38
sed -i -e s/10.5/10.7/g $bundleinstall/etc/macports/macports.conf
# Now build for 10.7
for p in $coreports ; do
    port -N uninstall -f $p
    port -N install $p
done

### Cleanup and remove build dependencies which are not required for building pspp
# like rust...
port -N setrequested $buildports

for i in {1..10}; do
    l=`port echo leaves`
    if ! test -z "$l" ; then
        port -N uninstall leaves
    fi
done

# Remove install files
port clean --all installed

# Create a tar file of the install directory
pushd $topdir
tar -cvzf macports-pspp.tgz ./install
popd

echo `date`
echo "Done! Installed macports in $bundleinstall"
