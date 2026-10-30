#!/bin/bash

cd "$(dirname "$0")" 2>/dev/null || true

# Fallbacks if run independently
BRANCH="${BRANCH:-16}"
ROM_NAME="${ROM_NAME:-EvolutionX}"
ROM_SCRIPT="${ROM_SCRIPT:-evox}"
DEVICE="${DEVICE:-creek}"
RAW_URL="https://raw.githubusercontent.com/nuruszama/build_scripts/A${BRANCH}"

# Check if .env file exists
if [ ! -f ".env" ]; then 
    echo "⚠️ .env file not found! Exiting ..."
    exit 0
fi

source .env

echo ">> Building $ROM_NAME for $DEVICE (Branch: A${BRANCH})"

LOG_FILE="crave_build.log"
rm -f "$LOG_FILE"

# Pass ROM_TYPE and other variables inline into the remote container execution
crave run --projectID 93 --no-patch -- "curl -sf ${RAW_URL}/${ROM_SCRIPT}/crave_run.sh | bash" 2>&1 | tee "$LOG_FILE"

CRAVE_STATUS=${PIPESTATUS[0]}

if [ ! -f "$LOG_FILE" ]; then
    echo ">> Build script failed to start! Check the setup"
    exit 1
    
elif [ "${CRAVE_STATUS:-1}" -eq 0 ]; then
    break

elif [ "${CRAVE_STATUS:-1}" -eq 130 ]; then
    exit 130 # ⚠️ Build Queue Cancelled

else
    echo ">> Rejected with exit code $CRAVE_STATUS."

    if grep -q "Setting up workspace" "$LOG_FILE"; then
        echo ">> build failed.. inspect the logs"
        exit 1
    fi
fi
