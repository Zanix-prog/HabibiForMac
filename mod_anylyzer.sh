#!/bin/bash

# macOS Bash 3.2 Compatible
# Minecraft Mod Integrity & Unknown Scanner

clear
echo "=========================================="
echo " Minecraft Mod Integrity Analyzer (macOS)"
echo "=========================================="
echo

DEFAULT_MODS="$HOME/Library/Application Support/minecraft/mods"

echo -n "Enter path to mods folder (Press Enter for default): "
read MODS

if [ -z "$MODS" ]; then
    MODS="$DEFAULT_MODS"
fi

if [ ! -d "$MODS" ]; then
    echo "Invalid directory."
    exit 1
fi

echo
echo "Scanning:"
echo "$MODS"
echo

# Minecraft uptime
JAVA_PID=$(pgrep -f java)
if [ ! -z "$JAVA_PID" ]; then
    echo "{ Minecraft Uptime }"
    ps -p $JAVA_PID -o pid,etime,command
    echo
fi

TEMP_HASH_FILE="/tmp/mod_hashes.txt"
> "$TEMP_HASH_FILE"

VERIFIED_COUNT=0
UNKNOWN_COUNT=0
DUP_COUNT=0

echo "Checking mods..."
echo

for file in "$MODS"/*.jar; do
    [ -e "$file" ] || continue

    FILENAME=$(basename "$file")
    HASH=$(shasum -a 256 "$file" | awk '{print $1}')

    # Duplicate detection
    if grep -q "$HASH" "$TEMP_HASH_FILE"; then
        echo "🔁 Duplicate detected: $FILENAME"
        DUP_COUNT=$((DUP_COUNT+1))
        continue
    fi

    echo "$HASH" >> "$TEMP_HASH_FILE"

    RESPONSE=$(curl -s "https://api.modrinth.com/v2/version_file/$HASH?algorithm=sha256")

    echo "$RESPONSE" | grep -q "project_id"
    if [ $? -eq 0 ]; then
        TITLE=$(echo "$RESPONSE" | sed -n 's/.*"project_id":"\([^"]*\)".*/\1/p')
        echo "✔ Verified: $FILENAME"
        VERIFIED_COUNT=$((VERIFIED_COUNT+1))
    else
        echo "⚠ Unknown: $FILENAME"
        UNKNOWN_COUNT=$((UNKNOWN_COUNT+1))
    fi

    # Metadata check
    unzip -l "$file" | grep -q "fabric.mod.json"
    if [ $? -eq 0 ]; then
        echo "   ↳ Fabric metadata found"
    else
        unzip -l "$file" | grep -q "mods.toml"
        if [ $? -eq 0 ]; then
            echo "   ↳ Forge metadata found"
        else
            echo "   ↳ No standard metadata detected"
        fi
    fi

    # Nested jars check
    unzip -l "$file" | grep -q "META-INF/jars"
    if [ $? -eq 0 ]; then
        echo "   ↳ Contains nested jars"
    fi

    echo
done

echo "=========================================="
echo "Scan Complete"
echo "Verified: $VERIFIED_COUNT"
echo "Unknown: $UNKNOWN_COUNT"
echo "Duplicates: $DUP_COUNT"
echo "=========================================="
echo

rm -f "$TEMP_HASH_FILE"
