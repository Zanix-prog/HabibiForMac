#!/usr/bin/env bash

# ==============================
# Advanced Minecraft Mod Integrity Analyzer (macOS)
# ==============================

set -euo pipefail

clear
echo "=============================================="
echo " Advanced Minecraft Mod Integrity Analyzer"
echo " macOS Edition"
echo "=============================================="
echo

DEFAULT_MODS="$HOME/Library/Application Support/minecraft/mods"

read -r -p "Enter path to mods folder (Press Enter for default): " MODS
if [[ -z "${MODS}" ]]; then
    MODS="$DEFAULT_MODS"
fi

if [[ ! -d "$MODS" ]]; then
    echo "❌ Invalid directory: $MODS"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "❌ jq is required. Install with: brew install jq"
    exit 1
fi

echo
echo "📂 Scanning directory:"
echo "$MODS"
echo

# Minecraft uptime
JAVA_PID=$(pgrep -f java || true)
if [[ -n "${JAVA_PID}" ]]; then
    echo "{ Minecraft Uptime }"
    ps -p "$JAVA_PID" -o pid,etime,command
    echo
fi

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

declare -A HASH_MAP
declare -a VERIFIED
declare -a UNKNOWN
declare -a DUPLICATES

scan_file() {
    local file="$1"
    local filename
    filename=$(basename "$file")

    HASH=$(shasum -a 256 "$file" | awk '{print $1}')

    # Duplicate detection
    if [[ -n "${HASH_MAP[$HASH]:-}" ]]; then
        DUPLICATES+=("$filename == ${HASH_MAP[$HASH]}")
        return
    fi
    HASH_MAP[$HASH]="$filename"

    RESPONSE=$(curl -s "https://api.modrinth.com/v2/version_file/$HASH?algorithm=sha256" || true)

    if echo "$RESPONSE" | jq -e '.project_id' &>/dev/null; then
        PROJECT_ID=$(echo "$RESPONSE" | jq -r '.project_id')
        PROJECT_DATA=$(curl -s "https://api.modrinth.com/v2/project/$PROJECT_ID")
        TITLE=$(echo "$PROJECT_DATA" | jq -r '.title')
        VERIFIED+=("$TITLE ($filename)")
    else
        UNKNOWN+=("$filename")
    fi
}

echo "⚡ Hashing & verifying mods..."
echo

# Parallel scan
export -f scan_file
export TEMP_DIR

find "$MODS" -type f -name "*.jar" | while read -r file; do
    scan_file "$file"
done

echo
echo "=============================================="

if [[ ${#VERIFIED[@]} -gt 0 ]]; then
    echo
    echo "✅ Verified Mods:"
    for mod in "${VERIFIED[@]}"; do
        echo "  ✔ $mod"
    done
fi

if [[ ${#UNKNOWN[@]} -gt 0 ]]; then
    echo
    echo "⚠ Unknown Mods:"
    for mod in "${UNKNOWN[@]}"; do
        echo "  ⚠ $mod"
    done
fi

if [[ ${#DUPLICATES[@]} -gt 0 ]]; then
    echo
    echo "🔁 Duplicate Mods:"
    for mod in "${DUPLICATES[@]}"; do
        echo "  🔁 $mod"
    done
fi

echo
echo "🔎 Metadata Validation:"
echo

for file in "$MODS"/*.jar; do
    [[ -e "$file" ]] || continue
    filename=$(basename "$file")

    if unzip -l "$file" | grep -q "fabric.mod.json"; then
        echo "  📦 $filename → Fabric mod detected"
    elif unzip -l "$file" | grep -q "mods.toml"; then
        echo "  📦 $filename → Forge mod detected"
    else
        echo "  ❓ $filename → No standard mod metadata found"
    fi

    # Nested jar scan
    unzip -l "$file" | grep "META-INF/jars" >/dev/null 2>&1 && \
        echo "     ↳ Contains nested jars"
done

echo
echo "=============================================="
echo " Scan Complete."
echo "=============================================="
echo
