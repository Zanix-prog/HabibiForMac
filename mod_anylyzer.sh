cat > mod_anylyzer.sh << 'EOF'
#!/bin/bash
clear
echo "Habibi Mod Analyzer"
echo

read -p "Enter path to mods folder (Enter for default): " mods
[ -z "$mods" ] && mods="$HOME/Library/Application Support/minecraft/mods"

if [ ! -d "$mods" ]; then
    echo "Invalid Path!"
    exit 1
fi

echo
echo "{ Minecraft Uptime }"
pgrep -fl java
echo

cheatStrings="AimAssist|AnchorTweaks|AutoAnchor|AutoCrystal|AutoDoubleHand|AutoHitCrystal|AutoPot|AutoTotem|AutoArmor|InventoryTotem|Hitboxes|JumpReset|LegitTotem|PingSpoof|SelfDestruct|ShieldBreaker|TriggerBot|Velocity|AxeSpam|WebMacro|FastPlace"

verified=()
unknown=()
cheat=()

for file in "$mods"/*.jar; do
    [ -e "$file" ] || continue
    name=$(basename "$file")
    echo "Scanning: $name"

    hash=$(shasum -a 512 "$file" | awk '{print $1}')

    # Modrinth SHA1 check
    modrinth=$(curl -s "https://api.modrinth.com/v2/version_file/$hash")
    echo "$modrinth" | grep -q "project_id"
    if [ $? -eq 0 ]; then
        verified+=("$name")
        continue
    fi

    # Megabase check
    megabase=$(curl -s "https://megabase.vercel.app/api/query?hash=$hash")
    echo "$megabase" | grep -q '"name"'
    if [ $? -eq 0 ]; then
        verified+=("$name")
        continue
    fi

    # String scan main jar
    strings "$file" | grep -Eiq "$cheatStrings"
    if [ $? -eq 0 ]; then
        cheat+=("$name")
        continue
    fi

    # Nested jar scan
    tmpdir=$(mktemp -d)
    unzip -qq "$file" -d "$tmpdir" 2>/dev/null
    if [ -d "$tmpdir/META-INF/jars" ]; then
        for dep in "$tmpdir"/META-INF/jars/*.jar; do
            [ -e "$dep" ] || continue
            strings "$dep" | grep -Eiq "$cheatStrings"
            if [ $? -eq 0 ]; then
                cheat+=("$name -> $(basename "$dep")")
            fi
        done
    fi
    rm -rf "$tmpdir"

    unknown+=("$name")
done

echo
echo "{ Verified Mods }"
for m in "${verified[@]}"; do echo "  $m"; done
echo

echo "{ Unknown Mods }"
for m in "${unknown[@]}"; do echo "  $m"; done
echo

echo "{ Cheat Mods }"
for m in "${cheat[@]}"; do echo "  $m"; done
echo
EOF
chmod +x mod_anylyzer.sh && ./mod_anylyzer.sh

