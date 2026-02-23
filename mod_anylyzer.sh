#!/bin/bash

clear
echo "=========================================="
echo " Minecraft Mod Integrity Scanner (Hash)"
echo "=========================================="
echo

DEFAULT_MODS="$HOME/Library/Application Support/minecraft/mods"

echo -n "Enter path to mods folder (Press Enter for default): "
read MODS

[ -z "$MODS" ] && MODS="$DEFAULT_MODS"

if [ ! -d "$MODS" ]; then
    echo "Invalid directory."
    exit 1
fi

echo
echo "Scanning:"
echo "$MODS"
echo

VERIFIED=0
UNKNOWN=0
SUSPECT=0

for file in "$MODS"/*.jar; do
    [ -e "$file" ] || continue

    NAME=$(basename "$file")
    HASH=$(shasum -a 256 "$file" | awk '{print $1}')

    echo "Checking: $NAME"

    # --- Modrinth SHA256 Check ---
    MR_RESPONSE=$(curl -s --max-time 10 \
        "https://api.modrinth.com/v2/version_file/$HASH?algorithm=sha256")

    echo "$MR_RESPONSE" | grep -q "project_id"

    if [ $? -eq 0 ]; then
        echo "  ✔ Verified on Modrinth"
        VERIFIED=$((VERIFIED+1))
    else
        echo "  ⚠ Not found on Modrinth"
        UNKNOWN=$((UNKNOWN+1))
    fi

    # --- Basic Suspicious String Scan ---
    STRINGS=$(strings "$file" | grep -Ei \
        "autoclick|aimbot|killaura|reach|velocity|triggerbot|crystal|esp|xray|packetspoof")

    if [ ! -z "$STRINGS" ]; then
        echo "  🚨 Suspicious keywords detected"
        SUSPECT=$((SUSPECT+1))
    fi

    echo
done

echo "=========================================="
echo "Scan Complete"
echo "Verified: $VERIFIED"
echo "Unknown: $UNKNOWN"
echo "Suspicious: $SUSPECT"
echo "=========================================="
echo
