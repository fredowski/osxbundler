#!/bin/bash -xve

# Prepare the environment on travis

# Copyright (C) 2020 Free Software Foundation, Inc.
# Released under GNU General Public License, either version 3
# or any later option

# Uninstall Homebrew
#brew --version
#/usr/bin/sudo /usr/bin/find /usr/local -mindepth 2 -delete && hash -r

ourhosts="alpha.gnu.org git.savannah.gnu.org www.hs-augsburg.de distfiles.macports.org \
  dl.bintray.com github.com packages.macports.org \
  packages-private.macports.org rsync-origin.macports.org"

# Guard against intermittent Travis CI DNS outages
for host in $ourhosts ; do
    dig +short "$host" | sed -n '$s/$/ '"$host/p" | sudo tee -a /etc/hosts >/dev/null
done
