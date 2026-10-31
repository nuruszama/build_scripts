#!/bin/bash
clear

# Default configurations
export BRANCH="16"
ROM_TYPE=""
TARGET_DIR=""
ROM_NAME=""
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --los)
            ROM_NAME="lineage"
            ROM_SCRIPT="lineageos"
            TARGET_DIR="creek"
            ;;
        --evox)
            ROM_NAME="EvolutionX"
            ROM_SCRIPT="evox"
            TARGET_DIR="creek"
            ;;
        --pos)
            ROM_NAME="PixelOS"
            ROM_SCRIPT="pixelos"
            TARGET_DIR="pixelos"
            ;;
        -[0-9]*|--[0-9]*)
            BRANCH="${1//-/}"
            export BRANCH
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--los | --pos | --evox] [--17]"
            exit 1
            ;;
    esac
    shift
done

if [ -z "$ROM_SCRIPT" ]; then
    echo "Error: No ROM specified!"
    echo "Usage: $0 [--los | --pos | --evox] [--17]"
    exit 1
fi

# Export variables so they carry over to piped/called scripts
export ROM_SCRIPT
export ROM_NAME
export RAW_URL="https://raw.githubusercontent.com/nuruszama/build_scripts/A${BRANCH}"

echo ">> Setting build to ${ROM_SCRIPT} (Branch: A${BRANCH})"

cd "$TARGET_DIR" || { echo "Directory '$TARGET_DIR' not found!"; exit 1; }

# Call the unified crave_queue.sh from the root of the branch repository
curl -sf "${RAW_URL}/crave_queue.sh" | bash
