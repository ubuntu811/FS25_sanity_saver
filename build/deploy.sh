#!/usr/bin/env bash

# Exit immediately if any command fails
set -e

# Define source archive and destination folder name
cd "$(dirname "${BASH_SOURCE[0]}")/.."
MOD_NAME=$(basename "$PWD")
SOURCE_ZIP="build/${MOD_NAME}.zip"
TARGET_DIR_NAME="$HOME/fs25/mods/${MOD_NAME}"

echo "=== Starting FS25 Hot-Reload Deployment Pipeline ==="

# 1. Always rebuild from current source - a "build if missing" check here
# bit several sibling mods (IW, whatAmILookingAt) by silently redeploying a
# stale pre-session zip once the zip already existed on disk. build/build.sh,
# not ./build.sh - this script, like build.sh itself, assumes it's run from
# the mod root, e.g. `bash build/deploy.sh`.
build/build.sh

rm -rf "${TARGET_DIR_NAME}"

echo "--> Constructing staging directory at: ${TARGET_DIR_NAME}"
mkdir -p "$TARGET_DIR_NAME"

# 3. Deploy cleanly unzipped development package
echo "--> Unzipping production package directly into development target..."
unzip -q "$SOURCE_ZIP" -d "$TARGET_DIR_NAME"

echo "================================================="
echo " SUCCESS: Mod deployed as a loose unzipped folder!"
echo " Path: ${TARGET_DIR_NAME}"
echo "================================================="
