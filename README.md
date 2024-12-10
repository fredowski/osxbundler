osxbundler
=======

[![build status](https://github.com/fredowski/osxbundler/actions/workflows/main.yml/badge.svg)](https://github.com/fredowski/osxbundler/actions)

Create a [pspp](https://www.gnu.org/software/pspp) application bundle (dmg) for MacOS. Bundles are available here

https://www.hs-augsburg.de/homes/beckmanf/pspp/

Nightly dmg builds for the released and the nightly pspp versions are availble via the github CI/CD chain:

https://github.com/fredowski/osxbundler/actions

Create Bundle
=========

The pspp bundle is build via the homebrew environment and then bundled
via a
[modified gtk-mac-bundler](https://github.com/fredowski/gtk-mac-bundler/tree/homebrew)
version (branch homebrew) which has been adapted to the homebrew environment.

* Install [Homebrew](https://brew.sh)
* Clone this repository via `git clone --recurse-submodules
https://github.com/fredowski/osxbundler.git`
* Install the build environment with [install-build-env.sh](https://github.com/fredowski/osxbundler/blob/master/install-build-env.sh) 
* [buildpspp.sh](https://github.com/fredowski/osxbundler/blob/master/buildpspp.sh) - build pspp and create the MacOS application bundle

Contact: pspp-users@gnu.org
