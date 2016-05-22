#!/bin/sh -e

# Create a MacOS application bundle for pspp
# This will install all required dependencies via macports
# With option --git it will build pspp from a source tree
# The default is to install also pspp from macports
# Requires XCode Commandline Tools installed and ready for macports

# Copyright (C) 2016 Free Software Foundation, Inc.
# Released under GNU General Public License, either version 3
# or any later option

# The source tree for pspp is here. This is only required if you
# build with option --git
psppsource=`pwd`/../..

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

# Check the required configuration files
if ! test -f ./pspp.bundle; then
    echo "pspp.bundle is missing"
    exit
fi

if ! test -f ./Info-pspp.plist; then
    echo "Info-pspp.plist is missing"
    exit
fi

buildfromsource=false
if test $# = 1 && test $1 = "--git"; then
    echo "Trying to build from source"
    if test -f $psppsource/configure; then
        buildfromsource=true
    else
        echo "Could not find pspp source in: $psppsource"
        exit
    fi
fi

# This is the installation directory which will be used as macports prefix
# and as pspp configure prefix.
bundleinstall=`pwd`/install

export PATH=$bundleinstall/bin:$bundleinstall/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin

# Target macports install directory for the pspp bundle
if test -d $bundleinstall; then
    echo "Found existing macports directory $bundleinstall"
    echo "Updating macports packages"
    port uninstall pspp
    port uninstall gtk-mac-bundler
else
    echo "Creating Macports installation in $bundleinstall"
    mkdir $bundleinstall
    # Install macports
    rm -rf /tmp/macports
    mkdir /tmp/macports
    pushd /tmp/macports
    curl https://distfiles.macports.org/MacPorts/MacPorts-2.3.4.tar.gz -O
    tar xvzf Macports-2.3.4.tar.gz
    cd Macports-2.3.4
    ./configure --prefix=$bundleinstall \
                --with-applications-dir=$bundleinstall/Applications \
                --with-no-root-privileges
    make
    make install
    popd
    rm -rf /tmp/macports
    # Modify the default variants to use quartz
    echo "-x11 +no_x11 +quartz" > $bundleinstall/etc/macports/variants.conf
fi

# Install the packages for pspp
port -v selfupdate
port upgrade outdated || true
if test $buildfromsource = "true"; then
    # Install the build dependencies for pspp
    port install pkgconfig texinfo makeicns cairo fontconfig freetype \
     gettext glib2 gsl libiconv libxml2 ncurses pango readline zlib atk \
     gdk-pixbuf2 gtksourceview3 adwaita-icon-theme
# Configure and build pspp
    rm -rf ./build
    mkdir ./build
    pushd build
    $psppsource/configure --prefix=$bundleinstall \
                         LDFLAGS=-L$bundleinstalll/lib \
                         CPPFLAGS=-I$bundleinstall/include \
                         --enable-relocatable
    make
    make install
    popd
else
    # Install the pspp package from macports
    # This is a custom package for the moment as this requires the relocatable variant
    echo "Installing pspp from macports package"
    pushd ./macports-custom-packages/pspp
    port install +reloc
    popd
fi

# install the mac gtk-mac-bundler
# Custom package for the moment...
pushd ./macports-custom-packages/gtk-mac-bundler
port install
popd

# Create the icns file
makeicns -256 $bundleinstall/share/icons/hicolor/256x256/apps/pspp.png \
         -32  $bundleinstall/share/icons/hicolor/32x32/apps/pspp.png \
         -16  $bundleinstall/share/icons/hicolor/16x16/apps/pspp.png \
         -out pspp.icns

# produce the pspp.app bundle in Desktop
export PSPPINSTALL=$bundleinstall
gtk-mac-bundler pspp.bundle

# Fix the link issue for the relocatable binary in the app bundle
# MacOS/pspp - the wrapper from gtk-mac-bundler calling
# MacOS/pspp-bin - the wrapper from glibc relocatable calling pspp-bin.bin
# but that is in the Resource directory
pushd pspp.app/Contents/MacOS
ln -s ../Resources/bin/psppire.bin ./pspp-bin.bin
popd

# Create the DMG for distribution
rm -rf /tmp/psppbundle
mkdir /tmp/psppbundle
mv ./pspp.app /tmp/psppbundle
rm -rf pspp.dmg
hdiutil create -fs HFS+ -srcfolder /tmp/psppbundle -volname pspp pspp.dmg
rm -rf /tmp/psppbundle

echo "Done! Your dmg file is pspp.dmg"
echo "You can remove the install directory: $bundleinstall"
