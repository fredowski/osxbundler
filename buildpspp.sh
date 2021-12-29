#!/bin/bash -xve

# Build pspp from git or from macports

# Copyright (C) 2020 Free Software Foundation, Inc.
# Released under GNU General Public License, either version 3
# or any later option

# This is the installation directory which will be used as macports prefix
# and as pspp configure prefix.
bundleinstall=`brew --prefix`
export PATH=$bundleinstall/bin:$bundleinstall/opt/texinfo/bin:$bundleinstall/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin

# bundleversion if the pspp release did not change but the build environment
bundleversion=1

# Test that the macports install directory exists
if ! test -d $bundleinstall; then
    echo "Homebrew install directory $bundleinstall is missing - exiting"
    exit 1
fi

# Check if we are on MacOS
if ! test `uname` = "Darwin"; then
    echo "This only works on MacOS"
    exit 1
fi

# Check if XCode is installed - Assume clang indicates xcode.
if ! test -f /usr/bin/clang; then
    echo "/usr/bin/clang not found - please install XCode CLT"
    exit 1
fi

# Check the required configuration files
if ! test -f ./pspp.bundle; then
    echo "pspp.bundle is missing"
    exit 1
fi

if ! test -f ./Info-pspp.plist; then
    echo "Info-pspp.plist is missing"
    exit 1
fi

buildsource="--brew"
if test $# = 1; then
    buildsource=$1;
fi

case $buildsource in
  "--git")
    #Download gnulib
    gnulibver=0edaafc813caff4101c58405c6ab279597afc0b9
    curl -o gnulib.zip https://codeload.github.com/coreutils/gnulib/zip/$gnulibver
    unzip -q gnulib.zip
    rm gnulib.zip
    mv gnulib-$gnulibver gnulib

    #Download and install spread-sheet-widget
    sswversion=0.7
    curl -o ssw.tgz http://alpha.gnu.org/gnu/ssw/spread-sheet-widget-$sswversion.tar.gz
    tar -xzf ssw.tgz
    pushd spread-sheet-widget-$sswversion
    ./configure --prefix=$bundleinstall
    make install
    popd

    #Download pspp git repository
    git clone --depth 2 https://git.savannah.gnu.org/git/pspp.git

    pushd pspp
    make -f Smake
    popd

    # The source tree for pspp is here.
    psppsource=`pwd`/pspp
    # Retrieve and Set Version Info
    pushd $psppsource
    gitversion=`git log --pretty=format:"%h" -1`
    repoversion=`sed -n 's/AC_INIT.*\[\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' configure.ac`
    psppversion=$repoversion-g$gitversion-$bundleversion
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
    fullreleaseversion=$psppversion
    popd;;
  "--release")
    port -v selfupdate
    port upgrade outdated || true
    # Install the pspp package from macports
    echo "Installing pspp from macports package"
    port -N install pspp +reloc +doc
    # Update the version information
    psppversion=`port info pspp | sed -n 's/pspp @\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p'`
    fullreleaseversion=$psppversion-$bundleversion;;
  "--nightly")
      curl -o pspp.tgz "https://benpfaff.org/~blp/pspp-master/latest-source.tar.gz"
      tar -xzf pspp.tgz
      psppversion=`ls -d pspp-* | sed -n 's/pspp-\(.*\)/\1/p'`
      psppsource=`pwd`/pspp-$psppversion
      mkdir ./build
      pushd build
      $psppsource/configure --disable-rpath \
                            --prefix=$bundleinstall \
                         LDFLAGS=-L$bundleinstall/lib \
                         CPPFLAGS=-I$bundleinstall/include \
                         PKG_CONFIG_PATH=$bundleinstall/lib/pkgconfig \
                         --enable-relocatable
      make -j4
      make check
      make html
      make install
      make install-html
      fullreleaseversion=$psppversion-$bundleversion
      popd;;
  "--brew")
      psppversion=`brew info pspp | sed -n 's/.* stable \([0-9]\.[0-9]\.[0-9]\).*/\1/p'`
      fullreleaseversion=$psppversion-$bundleversion
      brew install --verbose --with-relocation pspp;;
  "--brew-nightly")
      echo "Build nightly brew HEAD"
      brew install --verbose --with-relocation --HEAD pspp
      psppversion=`pspp --version | sed -n 's/pspp (GNU PSPP) \(.*\)/\1/p'`
      fullreleaseversion=$psppversion-$bundleversion;;
  *)
      echo "Option $1 not valid. Exiting"
      exit;;
esac

# If pspp is build via the brew formula, then the icons end up in the Cellar
if test $buildfromsource = "brew"; then
    psppiconpath=$bundleinstall/Cellar/pspp/$psppversion
else
    psppiconpath=$bundleinstall
fi

# Create the icns file
makeicns -256 $psppiconpath/share/icons/hicolor/256x256/apps/pspp.png \
         -32  $psppiconpath/share/icons/hicolor/32x32/apps/pspp.png \
         -16  $psppiconpath/share/icons/hicolor/16x16/apps/pspp.png \
         -out pspp.icns
# Set version information
sed "s/0.10.1/$fullreleaseversion/g" Info-pspp.plist > Info-pspp-version.plist

# Fix the rpath libraries such that gtc-mac-bundler can work
# --disable-rpath does not work anymore after relocate.m4 was updated in gnulib
install_name_tool -id $bundleinstall/lib/pspp/libpspp-$psppversion.dylib $bundleinstall/lib/pspp/libpspp-$psppversion.dylib
install_name_tool -id $bundleinstall/lib/pspp/libpspp-core-$psppversion.dylib $bundleinstall/lib/pspp/libpspp-core-$psppversion.dylib
install_name_tool -change @rpath/libpspp-$psppversion.dylib $bundleinstall/lib/pspp/libpspp-$psppversion.dylib $bundleinstall/bin/psppire
install_name_tool -change @rpath/libpspp-core-$psppversion.dylib $bundleinstall/lib/pspp/libpspp-core-$psppversion.dylib $bundleinstall/bin/psppire

# produce the pspp.app bundle in Desktop
export PSPPINSTALL=$bundleinstall
if test $buildsource = "--brew-nightly"; then
    export PSPPVERSION="HEAD"
else
    export PSPPVERSION=$psppversion
fi
gtk-mac-bundler pspp.bundle

# The application will be called in Contents/MacOS/pspp
# That is a launcher script that will call
# Contents/Resources/bin/psppire
pushd pspp.app/Contents/MacOS
rm ./pspp-bin
popd

# Create the DMG for distribution
rm -rf /tmp/psppbundle
mkdir /tmp/psppbundle
mv ./pspp.app /tmp/psppbundle
rm -rf pspp-*.dmg
hdiutil create -fs HFS+ -srcfolder /tmp/psppbundle -volname pspp pspp-$fullreleaseversion.dmg
rm -rf /tmp/psppbundle
rm -rf pspp.icns

echo "Done! Your dmg file is pspp-$fullreleaseversion.dmg"
echo "You can remove the install directory: $bundleinstall"
