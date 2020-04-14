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
psppsource=`pwd`/../pspp

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
    if test -d ./build; then
        pushd ./build
        make uninstall
        popd
    fi
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
fi

# Install the packages for pspp
port -v selfupdate
port upgrade outdated || true
if test $buildfromsource = "true"; then
    # Install the build dependencies for pspp
    port -N install pkgconfig texinfo makeicns cairo fontconfig freetype \
     gettext glib2 gsl libiconv libxml2 ncurses pango readline zlib atk \
     gdk-pixbuf2 gtksourceview3 adwaita-icon-theme spread-sheet-widget
    # Retrieve and Set Version Info
    pushd $psppsource
    gitversion=`git log --pretty=format:"%h" -1`
    repoversion=`sed -n 's/AC_INIT.*\[\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' configure.ac`
    psppversion=$repoversion-g$gitversion
    popd
    # Configure and build pspp
    rm -rf ./build
    mkdir ./build
    pushd build
    $psppsource/configure --disable-rpath \
                          --prefix=$bundleinstall \
                         LDFLAGS=-L$bundleinstall/lib \
                         CPPFLAGS=-I$bundleinstall/include \
                         PKG_CONFIG_PATH=$bundleinstall/lib/pkgconfig \
                         --enable-relocatable
    make VERSION=$psppversion
    make html
    make install
    make install-html
    popd
else
    # Install the pspp package from macports
    echo "Installing pspp from macports package"
    port -N install pspp +reloc +doc
    # Update the version information
    psppversion=`port info pspp | sed -n 's/pspp @\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p'`
fi

# install the mac gtk-mac-bundler
port -N install gtk-mac-bundler

# Create the icns file
makeicns -256 $bundleinstall/share/icons/hicolor/256x256/apps/pspp.png \
         -32  $bundleinstall/share/icons/hicolor/32x32/apps/pspp.png \
         -16  $bundleinstall/share/icons/hicolor/16x16/apps/pspp.png \
         -out pspp.icns
# Set version information
sed "s/0.10.1/$psppversion/g" Info-pspp.plist > Info-pspp-version.plist

# Fix the rpath libraries such that gtc-mac-bundler can work
# --disable-rpath does not work anymore after relocate.m4 was updated in gnulib
install_name_tool -id $bundleinstall/lib/pspp/libpspp-$psppversion.dylib $bundleinstall/lib/pspp/libpspp-$psppversion.dylib
install_name_tool -id $bundleinstall/lib/pspp/libpspp-core-$psppversion.dylib $bundleinstall/lib/pspp/libpspp-core-$psppversion.dylib
install_name_tool -change @rpath/libpspp-$psppversion.dylib $bundleinstall/lib/pspp/libpspp-$psppversion.dylib $bundleinstall/bin/psppire
install_name_tool -change @rpath/libpspp-core-$psppversion.dylib $bundleinstall/lib/pspp/libpspp-core-$psppversion.dylib $bundleinstall/bin/psppire

# produce the pspp.app bundle in Desktop
export PSPPINSTALL=$bundleinstall
gtk-mac-bundler pspp.bundle

# The relative path computation in the relocate code
# assumes that the path structure remains identical in the
# new install location. Therfore the binary must be in a bin
# directory. Therefore I link to the binary in the bin directory
# in the Resources directory
pushd pspp.app/Contents/MacOS
rm ./pspp-bin
rm ./pspp
ln -s ../Resources/bin/psppire ./pspp
popd

# Create the DMG for distribution
rm -rf /tmp/psppbundle
mkdir /tmp/psppbundle
mv ./pspp.app /tmp/psppbundle
rm -rf pspp-*.dmg
hdiutil create -fs HFS+ -srcfolder /tmp/psppbundle -volname pspp pspp-$psppversion.dmg
rm -rf /tmp/psppbundle
rm -rf pspp.icns

echo "Done! Your dmg file is pspp-$psppversion.dmg"
echo "You can remove the install directory: $bundleinstall"
