#!/usr/bin/python

mpinstdir="/opt/macports/install"
pspp='/Users/fritz/pspp/install/bin/psppire'

import subprocess
import glob
import re
import os
import sys

quiet = re.match('--quiet',sys.argv[1])

def otool(s):
    o = subprocess.Popen(['/usr/bin/otool', '-L', s], stdout=subprocess.PIPE)
    for l in o.stdout:
        if l[0] == '\t':
            yield l.split(' ', 1)[0][1:]

def searchlibs(a):
    need = set([a])
    done = set()

    while need:
        needed = set(need)
        need = set()
        for f in needed:
            need.update(otool(f))
        done.update(needed)
        need.difference_update(done)

    reallibs=[]
    for f in sorted(done):
        if re.match(mpinstdir,f):
            reallibs.append(f)
    return reallibs

libs = searchlibs(pspp)


installedports=[]
content=subprocess.check_output(["port", "-q", "installed"])
sc=content.split('\n')
for p in sc:
    r =  re.match('\s*(\S*)',p)
    if r:
        port = r.group(1)
        if port:
            installedports.append(port)

coreports=set()
for p in installedports:
    if not(quiet):
        print "Searching in: " + p
    content=subprocess.check_output(["port", "content", p])
    for l in libs:
        if re.search(l, content):
            if not(quiet):
                print "Found library: " + l + " in port " + p
            coreports.add(p)

for cp in sorted(coreports):
    print cp,
