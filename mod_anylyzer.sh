so how do i save #!/bin/bash

clear
echo "Habibi Mod Analyzer (macOS Edition)"
echo "------------------------------------"
echo

DEFAULT_MODS="$HOME/Library/Application Support/minecraft/mods"

read -p "Enter path to mods folder (Press Enter for default): " MODS

if [ -z "$MODS" ]; then
    MODS="$DEFAULT_MODS"
    echo "Using default path:"
    echo "$MODS"
    echo
fi

if [ ! -d "$MODS" ]; then
    echo "Invalid Path!"
    exit 1
fi

# Minecraft Uptime
JAVA_PID=$(pgrep -f java)

if [ ! -z "$JAVA_PID" ]; then
    echo "{ Minecraft Uptime }"
    ps -p $JAVA_PID -o pid,etime,command
    echo
fi

echo "Scanning mods..."
echo

VERIFIED=()
UNKNOWN=()

for file in "$MODS"/*.jar; do
    [ -e "$file" ] || continue

    HASH=$(shasum -a 1 "$file" | awk '{print $1}')
    FILENAME=$(basename "$file")

    echo "Checking: $FILENAME"

    RESPONSE=$(curl -s "https://api.modrinth.com/v2/version_file/$HASH")

    if echo "$RESPONSE" | grep -q "project_id"; then
        PROJECT_ID=$(echo "$RESPONSE" | grep -o '"project_id":"[^"]*' | cut -d'"' -f4)
        PROJECT_DATA=$(curl -s "https://api.modrinth.com/v2/project/$PROJECT_ID")
        TITLE=$(echo "$PROJECT_DATA" | grep -o '"title":"[^"]*' | cut -d'"' -f4)

        VERIFIED+=("$TITLE ($FILENAME)")
    else
        UNKNOWN+=("$FILENAME")
    fi

    echo
done

echo "-------------------------"

if [ ${#VERIFIED[@]} -gt 0 ]; then
    echo "{ Verified Mods }"
    for mod in "${VERIFIED[@]}"; do
        echo "✔ $mod"
    done
    echo
fi

if [ ${#UNKNOWN[@]} -gt 0 ]; then
    echo "{ Unknown Mods }"
    for mod in "${UNKNOWN[@]}"; do
        echo "⚠ $mod"
    done
fi