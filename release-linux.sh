#!/bin/bash
ARCH=$(uname -m)
echo "====================================="
echo "Building for $ARCH"
echo " "

echo "Erasing old builds..."
rm -rf builds/

echo "Building VST3 and LV2..."
dplug-build -c VST3 -c LV2 --final

echo "Zipping up.."

cd builds/
zip -r "NuCat-Linux-$ARCH.zip" license.html Linux-*-LV2 Linux-*-VST3

echo "Uploading to itch"
butler push "NuCat-Linux-$ARCH.zip" "lunafoxgirlvt/nucat:linux-$ARCH"
