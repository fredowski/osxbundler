#!/bin/sh -xve

# Copyright (C) 2020 Free Software Foundation, Inc.
# Released under GNU General Public License, either version 3
# or any later option

# Download and install the macports build environment for pspp
pushd /opt/macports
curl -o macports.tgz https://www.hs-augsburg.de/homes/beckmanf/pspp/macports-pspp.tgz
tar -xzf macports.tgz
popd
