#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# AUTOMAGIC: Dynamically sets the mod name to the current folder name!
cd "$(dirname "${BASH_SOURCE[0]}")/.."
MOD_NAME=$(basename "$PWD")
TARGET_ZIP="build/${MOD_NAME}.zip"
BUILD_DIR="build/.build_staging"

echo "=== Starting FS25 Mod Packaging Loop ==="
echo "--> Target Mod: ${MOD_NAME}"

# 1. Clean up any previous old build artifacts
if [ -f "$TARGET_ZIP" ]; then
    echo "--> Removing old target zip archive..."
    rm "$TARGET_ZIP"
fi

if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

echo "=== sanity check lua scripts ==="
find . -path ./build -prune -o -name '*.lua' -print0 | xargs -0 -n1 luac5.1 -p

echo "=== sanity check xml files ==="
find . -path ./build -prune -o -name '*.xml' -print0 | xargs -0 -n1 python3 -c 'import sys, xml.dom.minidom; xml.dom.minidom.parse(sys.argv[1])'

echo "--> Copying production files to staging area..."
for i in modDesc.xml SanitySaver.lua icon_sanity_saver.dds; do
  cp -r "$i" "$BUILD_DIR/$i"
done

# 3. Compile the production archive
echo "--> Compiling optimized production zip archive..."
cd "$BUILD_DIR"
# Zip everything inside the folder (-r for recursive, -q for quiet execution)
zip -rq "../${MOD_NAME}.zip" ./*
cd ..

# 4. Post-build cleanup
echo "--> Tearing down temporary staging directory..."
rm -rf "$BUILD_DIR"

echo "========================================="
echo " SUCCESS: Built production package!"
echo " File: ./${TARGET_ZIP}"
echo "========================================="
