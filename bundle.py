import subprocess
import re
import os
import shutil
import glob


# libdict collects for each library the library dependencies and the rpath dependencies
libdict = {}
skeldir = ""

def homebrew_prefix ():
    res = subprocess.run(['brew', '--prefix'], stdout=subprocess.PIPE)
    return res.stdout.decode('utf-8').rstrip()

# Get the RPATH search paths from a binary or library
# For example: path @loader_path/../lib/pspp (offset 12)
# Replace the loader_path with full path name
def get_rsearchpaths(filename):
    loaderpath=os.path.dirname(filename)
    res = subprocess.run(['otool', '-l', filename], stdout=subprocess.PIPE)
    t = res.stdout.decode('utf-8')
    rpathlist = []
    for line in t.splitlines():
        # search for strings like  path @loader_path/../lib/pspp (offset 12)
        m=re.search(' path (.*) \\(',line)
        if m:
            lpath = m.group(1) #should be @loader_path/../lib/pspp
            m=re.search('@loader_path/(.*)',lpath)
            if m:
                partpath=m.group(1) #should be ../lib/pspp
                # Now prepend the loaderpath
                fullpath=loaderpath + "/" + partpath #should be /opt/homebrew/bin/../lib/pspp
                apath = os.path.abspath(fullpath) #now /opt/homebrew/lib/pspp
            else:
                apath = lpath
            rpathlist.append(apath)
            print("adding to rpath: ", apath)
    return rpathlist

# Get a list of dependent libraries from a binary or library
def get_libraries(filename):
    libname=os.path.basename(filename)
    if libname in libdict:
        return libdict[libname]["libs"]
    rsearchpathlist=get_rsearchpaths(filename)
    res = subprocess.run(['otool', '-L', filename], stdout=subprocess.PIPE)
    t = res.stdout.decode('utf-8')
    libraryset = set()
    rpathset = set()
    p = homebrew_prefix()
    pattern=p+"/.*dylib|@rpath.*dylib"
    for line in t.splitlines():
        m=re.search(pattern,line)
        if m:
            libpath=m.group()
            if "@rpath" in libpath:
                for rp in rsearchpathlist:
                    testlibpath=libpath.replace("@rpath",rp)
                    if os.path.isfile(testlibpath):
                        rpathset.add(libpath)
                        libraryset.add(testlibpath)
            elif not libname in libpath:
                libraryset.add(libpath)
    libdict[libname] = {"libs": libraryset, "rpaths": rpathset}
    return libraryset

# Recurse through all library dependencies to get the full set of libraries
def get_libraries_recursive(filename):
    unknownset=get_libraries(filename)
    checkedset = set()
    while len(unknownset) > 0:
        newlibs = set()
        for lib in unknownset:
            newlibs = newlibs.union(get_libraries(lib))
        checkedset = checkedset.union(unknownset)
        unknownset = newlibs.difference(checkedset)
    return checkedset

def create_skeleton(appdir):
    global skeldir
    skeldir=appdir
    os.mkdir(appdir)
    os.mkdir(appdir + "/Contents")
    os.mkdir(appdir + "/Contents/MacOS")
    os.mkdir(appdir + "/Contents/Resources")
    os.mkdir(appdir + "/Contents/Resources/lib")
    os.mkdir(appdir + "/Contents/Resources/share")

def copy_libraries(libs):
    if skeldir == "":
        return
    destpath=skeldir+"/Contents/Resources/lib"
    for lib in libs:
        bn=os.path.basename(lib)
        if not(os.path.isfile(destpath+"/"+bn)):
            shutil.copy(lib,destpath)

def copy_main_binary(src, dest):
    shutil.copy(src,dest)

# Call install_name_tool to fix the path of the dependencies in the binary
# or library to point to the place in the bundle
def fix_libraries(name,prefix):
    if not os.path.exists(name):
        print("Could not find: ", name)
        raise RuntimeError
    if libdict[os.path.basename(name)]:
        print("Fixing: ", name)
        for oldname in libdict[os.path.basename(name)]["libs"]:
            #print("oldname: ", oldname);
            libbn=os.path.basename(oldname)
            newname = prefix + libbn;
            #print("newname: ", newname)
            res = subprocess.run(['install_name_tool', '-change', oldname, newname, name], stdout=subprocess.PIPE)
            #print(res)
        for oldname in libdict[os.path.basename(name)]["rpaths"]:
            #print("oldname: ", oldname);
            libbn=os.path.basename(oldname)
            newname = prefix + libbn;
            #print("newname: ", newname)
            res = subprocess.run(['install_name_tool', '-change', oldname, newname, name], stdout=subprocess.PIPE)
            #print(res)
    else:
        print(name + " not found!")

def fix_all_libraries_in_dir(dir,prefix):
    for f in os.listdir(dir):
        fullpath = dir+"/"+f
        if os.path.isfile(fullpath):
            fix_libraries(skeldir+"/Contents/Resources/lib/"+f,prefix)

def codesign(dir):
    for f in os.listdir(dir):
        fullpath = dir+"/"+f
        print(fullpath)
        if os.path.isfile(fullpath):
            res = subprocess.run(['codesign', '-f', '-s', '-', fullpath], stdout=subprocess.PIPE)
            print(res)

def copy_share():
    dirs = ["applications","doc/pspp","glib-2.0","gtksourceview-4","icons","locale","metainfo","mime","pspp","themes"]
    for dir in dirs:
        shutil.copytree(homebrew_prefix()+"/share/"+dir,skeldir+"/Contents/Resources/share/"+dir)

def install_gdk_pixbufs():
    shutil.copytree(homebrew_prefix()+"/lib/gdk-pixbuf-2.0",skeldir+"/Contents/Resources/lib/gdk-pixbuf-2.0")
    wildcardfilelist = glob.glob(skeldir+"/Contents/Resources/lib/gdk-pixbuf-2.0/*")
    loaderdir=wildcardfilelist[0]+"/loaders"
    loadercachefile=wildcardfilelist[0]+"/loaders.cache"
    with open(loadercachefile, 'r') as file:
        data = file.read()
        data = data.replace(homebrew_prefix(),"@executable_path/../Resources")
    with open(loadercachefile, 'w') as file:
        file.write(data)
    pixlibs = set();
    for lib in glob.glob(skeldir+"/Contents/Resources/lib/gdk-pixbuf-2.0/*/loaders/*"):
        newset = get_libraries_recursive(lib)
        pixlibs = pixlibs.union(newset)
        fix_libraries(lib, "@executable_path/../Resources/lib/")
    copy_libraries(pixlibs)
    codesign(loaderdir)

def copy_info_and_icons():
    shutil.copy("Info-pspp-version.plist",skeldir+"/Contents/Info.plist")
    shutil.copy("pspp.icns",skeldir+"/Contents/Resources")

def finalize():
    shutil.move(skeldir, "pspp.app")

create_skeleton("app")
main_binary=homebrew_prefix()+"/bin/psppire"

libs=get_libraries_recursive(main_binary)
libdict["pspp"] = libdict.pop("psppire")
main_binary_bundle=skeldir+"/Contents/MacOS/pspp"
copy_main_binary(main_binary,main_binary_bundle)

copy_libraries(libs)

copy_share()
copy_info_and_icons()

fix_libraries(main_binary_bundle,"@executable_path/../Resources/lib/")

install_gdk_pixbufs()
fix_all_libraries_in_dir(skeldir+"/Contents/Resources/lib","@executable_path/../Resources/lib/")
#print(libdict.keys())
print(libdict)

codesign(skeldir+"/Contents/Resources/lib")
codesign(skeldir+"/Contents/MacOS")
finalize()




