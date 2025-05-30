#!/bin/bash -xve

# Build pspp from git or from macports

# Copyright (C) 2020, 2022, 2025 Free Software Foundation, Inc.
# Released under GNU General Public License, either version 3
# or any later option

# This is the installation directory which will be used as macports prefix
# and as pspp configure prefix.
bundleinstall=`brew --prefix`
export PATH=$bundleinstall/bin:$bundleinstall/opt/texinfo/bin:$bundleinstall/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin

# bundleversion if the pspp release did not change but the build environment
bundleversion=4

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
  "--nobuild")
      echo "Expect pspp in brew location"
      psppversion=`pspp --version | sed -n 's/pspp (GNU PSPP) \(.*\)/\1/p'`
      fullreleaseversion=$psppversion-$bundleversion;;
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

psppiconpath=$bundleinstall
# Create the icns file
makeicns -256 $psppiconpath/share/icons/hicolor/256x256/apps/org.gnu.pspp.png \
         -32  $psppiconpath/share/icons/hicolor/32x32/apps/org.gnu.pspp.png \
         -16  $psppiconpath/share/icons/hicolor/16x16/apps/org.gnu.pspp.png \
         -out pspp.icns
# Set version information
sed "s/0.10.1/$fullreleaseversion/g" Info-pspp.plist > Info-pspp-version.plist


# produce the pspp.app bundle
python3 bundle.py

# Create the DMG for distribution
tmpdir=$(mktemp -d ./tmp-XXXXXXXXXX)
mv ./pspp.app $tmpdir
rm -rf pspp-*.dmg
# Workaround resource busy bug on github on MacOS 13
# https://github.com/actions/runner-images/issues/7522
i=0
until
hdiutil create -fs HFS+ -srcfolder $tmpdir -volname pspp pspp-$fullreleaseversion-`uname -m`.dmg
do
if [ $i -eq 10 ]; then exit 1; fi
i=$((i+1))
sleep 1
done

rm -rf $tmpdir
rm -rf pspp.icns

echo "Done! Your dmg file is pspp-$fullreleaseversion-`uname -m`.dmg"
echo "You can remove the install directory: $bundleinstall"
