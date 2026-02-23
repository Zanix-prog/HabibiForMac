#!/bin/bash

clear

# Colors
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

echo "Habibi Advanced Mod Analyzer (macOS)"
echo

mods="$1"
if [ -z "$mods" ]; then
    read -p "Enter path to mods folder: " mods
fi

if [ ! -d "$mods" ]; then
    echo "Invalid path."
    exit 1
fi

echo
echo "{ Minecraft Uptime }"
pgrep -fl java
echo

# Suspicious modules / classes
suspiciousPatterns="AirAnchor|AutoCrystal|AutoDoubleHand|AutoTotem|AutoAnchor|AnchorTweaks|Velocity|TriggerBot|PingSpoof|ShieldBreaker|AxeSpam|CrystalAura|Krypton|ThreadTweak|SelfDestruct"

verified=()
unknown=()
cheat=()

while IFS= read -r file; do
    name=$(basename "$file")
    echo "Scanning: $name"

    # SHA512 for Modrinth
    hash=$(shasum -a 512 "$file" | awk '{print $1}')

    modrinth=$(curl -s "https://api.modrinth.com/v2/version_file/$hash")

    if echo "$modrinth" | grep -q "\"project_id\""; then
        verified+=("$name")
        continue
    fi

    # Deep string scan
    if strings "$file" | grep -Eiq "$suspiciousPatterns"; then
        cheat+=("$name")
        continue
    fi

    # Extract and scan class names
    tmpdir=$(mktemp -d)
    unzip -qq "$file" -d "$tmpdir" 2>/dev/null

    if find "$tmpdir" -iname "*AirAnchor*.class" | grep -q .; then
        cheat+=("$name (AirAnchor class detected)")
        rm -rf "$tmpdir"
        continue
    fi

    # Detect heavy obfuscation pattern (aa.class ab.class etc.)
    obfCount=$(find "$tmpdir" -type f -regex ".*/[a-z][a-z]\.class" | wc -l)

    if [ "$obfCount" -gt 25 ]; then
        cheat+=("$name (Highly Obfuscated Client)")
        rm -rf "$tmpdir"
        continue
    fi

    rm -rf "$tmpdir"

    unknown+=("$name")

done < <(find "$mods" -type f -name "*.jar")

echo
echo "{ Verified Mods }"
for m in "${verified[@]}"; do
    echo -e "  ${GREEN}$m${RESET}"
done

echo
echo "{ Unknown Mods }"
for m in "${unknown[@]}"; do
    echo -e "  ${YELLOW}$m${RESET}"
done

echo
echo "{ Suspicious / Cheat Mods }"
for m in "${cheat[@]}"; do
    echo -e "  ${RED}$m${RESET}"
done

echo
