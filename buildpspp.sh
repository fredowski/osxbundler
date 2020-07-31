#!/bin/sh -xve

# Build pspp from git

# Copyright (C) 2020 Free Software Foundation, Inc.
# Released under GNU General Public License, either version 3
# or any later option

# This is the installation directory which will be used as macports prefix
# and as pspp configure prefix.


bundleinstall=/opt/macports/install

# Test that the macports install directory exists
if ! test -d $bundleinstall; then
    echo "Macports install directory $bundleinstall is missing - exiting"
    exit
fi

export PATH=$bundleinstall/bin:$bundleinstall/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin

#Download gnulib
git clone https://git.savannah.gnu.org/git/gnulib.git
pushd gnulib
git checkout 1e972a8a37c153ddc15e604592f84f939eb3c2ad
popd

#Download and install spread-sheet-widget
sswversion=0.6
curl -o ssw.tgz http://alpha.gnu.org/gnu/ssw/spread-sheet-widget-$sswversion.tar.gz
tar -xzf ssw.tgz
pushd spread-sheet-widget-$sswversion
./configure --prefix=$bundleinstall
make install

#Download pspp git repository
git clone --depth 2 https://git.savannah.gnu.org/git/pspp.git

pushd pspp
make -f Smake
popd

# The source tree for pspp is here.
psppsource=`pwd`/pspp

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
    make check
    make html
    make install
    make install-html
    popd

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
