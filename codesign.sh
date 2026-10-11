#!/bin/bash -xve

# Unpack a DMG, codesign it, and pack it again

required_native_programs="hdiutil codesign jq"

for p in $required_native_programs; do
    if ! type "$p" > /dev/null; then
        echo $p must be installed and in PATH;
        exit 1
    fi
done

if ! test $# = 1; then
    echo "Usage: $0 <dmgfile>"
    exit 1
else
    dmgfilename=$1
fi

if ! test -f $dmgfilename; then
    echo "Cannot find dmg file $dmgfilename"
    exit 1
fi

if ! [[ ${dmgfilename##*.} == dmg ]]; then
    echo "The file $dmgfilename does not have the file ending .dmg. Is this a dmg file? Aborting."
    exit 1
fi

if test -d /Volumes/pspp; then
    echo "You must unmount the existing /Volumes/pspp before i can continue. Aborting."
    exit 1
fi

echo "Mounting the dmg file $dmgfilename"

hdiutil attach -readonly $dmgfilename

if ! test -d /Volumes/pspp/pspp.app; then
    echo "The dmg file $dmgfilename does not contain the "pspp.app". Aborting."
    exit 1
fi

# Copy the app to the tmp directory
rm -rf /tmp/pspp.app
cp -R /Volumes/pspp/pspp.app /tmp
# Unmount the Volume
hdiutil detach /Volumes/pspp
# Codesign pspp.app with Apple Developer ID
codesign --option runtime --timestamp -f -s FF9C7B489C6A33E94903A8891EFA9245FA60AC9A /tmp/pspp.app/Contents/Resources/lib/*.dylib
codesign --option runtime --timestamp -f -s FF9C7B489C6A33E94903A8891EFA9245FA60AC9A /tmp/pspp.app/Contents/Resources/lib/gdk-pixbuf-2.0/2.10.0/loaders/*
codesign --option runtime --timestamp -f -s FF9C7B489C6A33E94903A8891EFA9245FA60AC9A /tmp/pspp.app/Contents/MacOS/pspp
codesign --option runtime --timestamp -f -s FF9C7B489C6A33E94903A8891EFA9245FA60AC9A /tmp/pspp.app

# Move the original dmg to dmg.orig
mv $dmgfilename $dmgfilename.orig
# Create the new signed dmg with the old name
hdiutil create -fs HFS+J -format ULFO -srcfolder /tmp/pspp.app -volname pspp $dmgfilename
codesign -f -s FF9C7B489C6A33E94903A8891EFA9245FA60AC9A  $dmgfilename

echo "The bundle is now signed."

# Upload to notarization
UUID=$(xcrun notarytool submit $dmgfilename \
  --keychain-profile pspp-notary-password \
  --output-format json | jq -r '.id')

if [ -z "$UUID" ]; then
  echo "Notarization submit failed" >&2
  exit 1
fi

echo "The bundle is uploaded to notarization with UUID $UUID"
echo "Check the notarization status with:\n"
echo "xcrun notarytool info --keychain-profile pspp-notary-password $UUID\n"
echo "Then staple the notarization ticket with the dmg with: \n"
echo "xcrun stapler staple $dmgfilename"
