osxbundler
=======

[![Build Status](https://travis-ci.org/fredowski/osxbundler.svg?branch=master)](https://travis-ci.org/fredowski/osxbundler)
[ ![Download](https://api.bintray.com/packages/fredowski/pspp/pspp-macos-install-bundle/images/download.svg?version=nightly) ](https://bintray.com/fredowski/pspp/pspp-macos-install-bundle/nightly/link)

Create a [pspp](https://www.gnu.org/software/pspp) application bundle (dmg) for MacOS. Bundles are available here

https://www.hs-augsburg.de/homes/beckmanf/pspp/

Create Bundle
=========

The macports build environment is frozen in

https://github.com/fredowski/macports-ports

in the branch "pspp". Building the complete macports environment takes a couple of hours from scratch. The resulting environment is available as a tgz file. This file is untared in /opt/macports and creates /opt/macports/install

* Create directory /opt/macports and make it writable to the build user
* Optional: Create the macports build environment with [installmacports.sh](https://github.com/fredowski/osxbundler/blob/master/installmacports.sh)
* Alternative: [install-build-env.sh](https://github.com/fredowski/osxbundler/blob/master/install-build-env.sh) - Download and install the ready-made macports build environment (for MacOS 10.13.6)
* [buildpspp.sh](https://github.com/fredowski/osxbundler/blob/master/buildpspp.sh) - build pspp and create the MacOS application bundle

Contact: pspp-users@gnu.org
