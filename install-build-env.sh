#!/bin/sh -xve

# Copyright (C) 2020,2021 Free Software Foundation, Inc.
# Released under GNU General Public License, either version 3
# or any later option

# Install the gtk-mac-bundler tool
cd gtk-mac-bundler
make bindir=/usr/local/bin install

# makeicns tool for creating the apple icon file
brew install makeicns
# Add pspp to the brew environment
brew tap fredowski/pspp
