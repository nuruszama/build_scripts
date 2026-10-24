#!/bin/bash

# ------ What this script can do?? ------
# Details coming soon.... be patient ;-)

# set pipelined command flow
set -o pipefail

BUILD_LOG="build.log"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️ .env file not found!"
    # define 
    DEVICE="creek"
    BUILD_TYPE="userdebug"
fi

# Load your local secrets
set -o allexport
source .env
set +o allexport

# Defining the printing steps in terminal
print_step() {
    echo "----------------------------------------------------"
    echo "${1}"
    echo ""
}

print_exit() {
    telegram_reply "$1"
    echo "$1"
    exit 1
}

# Send telegram message
telegram_send() {
    # Append new log entry
    BUILD_HISTORY="🌏 _$(date +"%d %b %Y %I:%M %p GST")_
${1}"
    
    local response
    response=$(curl -sS \
        -X POST \
        "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${BUILD_HISTORY}")

    TG_MSG_ID=$(echo "$response" | grep -o '"message_id":[0-9]*' | cut -d: -f2)

    export ID
}

# Edit existing telegram message
telegram_edit() {

    [ -z "$ID" ] && {
        telegram_send "${1}"
        return
    }

    # Append new log entry
    export BUILD_HISTORY="${BUILD_HISTORY}

🌏 _$(date +"%d %b %Y %I:%M %p GST")_
${1}"

    curl -sS \
        -X POST \
        "https://api.telegram.org/bot${TG_TOKEN}/editMessageText" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "message_id=${ID}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "text=${BUILD_HISTORY}" \
        >/dev/null
}

# reply to initial telegram message
telegram_reply() {
    local TEXT="🌏 _$(date +"%d %b %Y %I:%M %p GST")_
${1}"

    curl -sS \
        -X POST \
        "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TG_CHAT}" \
        --data-urlencode "parse_mode=Markdown" \
        --data-urlencode "disable_web_page_preview=true" \
        --data-urlencode "reply_parameters={\"message_id\":${ID}}" \
        --data-urlencode "text=${TEXT}" \
        >/dev/null
}

# Send a file document to telegram
telegram_send_document() {
    local file_path="${1}"
    local caption="${2}"

    curl -sS \
        -X POST \
        "https://api.telegram.org/bot${TG_TOKEN}/sendDocument" \
        -F "chat_id=${TG_CHAT}" \
        -F "document=@${file_path}" \
        -F "parse_mode=Markdown" \
        -F "reply_parameters={\"message_id\":${ID}}" \
        -F "caption=${caption}" \
        >/dev/null
}

# checking JQ and install if it is absent
if ! command -v jq &> /dev/null; then
    mkdir -p ~/bin
    curl -L -o ~/bin/jq https://github.com/jqlang/jq/releases/download/jq-1.7/jq-linux64
    chmod +x ~/bin/jq
    export PATH=$HOME/bin:$PATH
fi

# defining pixel drain uploads
pixeldrain_upload() {
    local FILE="${1}"

    if [ -f "$FILE" ]; then
        RESPONSE=$(curl -s -u ":$PIXELDRAIN" -T "$FILE" https://pixeldrain.com/api/file/)
        FILE_ID=$(echo "$RESPONSE" | jq -r '.id')

        if [[ "$FILE_ID" != "null" && -n "$FILE_ID" ]]; then
            # Mark file public
            curl -s -u ":$PIXELDRAIN" -X POST "https://pixeldrain.com/api/file/$FILE_ID/publicity" \
                 -H "Content-Type: application/json" \
                 -d '{"public": true}' > /dev/null
                 
            PD_URL="https://pixeldrain.com/u/$FILE_ID"
            echo "${PD_URL}"
            return 0  # Explicitly return success
        else
            # Print the raw error to standard error log so it shows up on your Crave console
            echo "PixelDrain API Error response: $RESPONSE" >&2
        fi
    else
        echo "Error: Target file $FILE not found." >&2
    fi

    return 1
}

# change local timezone to dev's
sudo rm -f /etc/localtime
sudo ln -s /usr/share/zoneinfo/${TZ} /etc/localtime

telegram_edit "${DEVICE} Build started"
START_TIME=$(date +%s)

echo "==> Resetting environment..."
git checkout . 2>/dev/null || true
git clean -fd 2>/dev/null || true

# Export environment variables for the upload script
export SF_USER="nuruszama"
export VERS="bka"
export SF_PROJECT="xiaomicreek"
export ROM_NAME="EvolutionX"
export ROM_VERSION="11.12"
export ANDROID_VER="${BRANCH}"
export RELEASE_TYPE="stable"
export BUILD_TYPE="userdebug"
export DEVICE="creek"
export FS_TYPE="erofs"
export GAPPS_CHOICE="gapps"
export BANNER="${RAW_URL}/evox/EvolutionX_Banner.png"

# Build Optimizations & Checks
export SKIP_ABI_CHECKS=true
export WITH_DEXPREOPT=true

# Clean up qcom-caf hardware repo without deleting it
if [ -d "hardware/qcom-caf/common" ]; then
    echo "==> Resetting hardware/qcom-caf/common..."
    git -C hardware/qcom-caf/common checkout . 2>/dev/null || true
    git -C hardware/qcom-caf/common clean -fd 2>/dev/null || true
fi

# Ensure git cleanup always runs even if the build is interrupted or fails
cleanup_updater() {
    echo "==> Restoring original Updater strings.xml..."
    if [ -d "packages/apps/Updater" ]; then
        git -C packages/apps/Updater checkout app/src/main/res/values/strings.xml 2>/dev/null || true
    fi
    if [ -d "vendor/lineage" ]; then
        git -C vendor/lineage checkout config/version.mk 2>/dev/null || true
    fi
}
trap cleanup_updater EXIT

# Remove local manifest and device/vendor trees to allow fresh local_manifest sync
rm -rf .repo/local_manifests
rm -rf vendor/xiaomi/creek
rm -rf device/xiaomi/creek
rm -rf device/xiaomi/creek-kernel

# Initialize the ROM source repository
print_step "repo init"
repo init -u https://github.com/Evolution-X/manifest -b ${VERS} --git-lfs --depth=1
if [ $? -ne 0 ]; then
    print_exit "Repo initialization failed. Exiting."
fi

# Clone or update local manifests
print_step "Cloning local manifests..."
git clone https://github.com/XiaomiCreek/android.git -b lineage-23.2 .repo/local_manifests --depth=1 --quiet
if [ $? -ne 0 ]; then
    print_exit "Failed to setup local manifests. Exiting."
fi

# Sync the repositories using the Crave sync script
print_step "resync the source and device tree"
/opt/crave/resync.sh
if [ $? -ne 0 ]; then
    print_exit "Crave sync failed. Exiting."
fi

# Reset version.mk before applying changes for this iteration
if [ -d "vendor/lineage" ]; then
    git -C vendor/lineage checkout config/version.mk 2>/dev/null || true
fi

# Patch EVO_BUILD_TYPE in version.mk
VERSION_MK="vendor/lineage/config/version.mk"
if [ -f "$VERSION_MK" ]; then
    echo "==> Patching EVO_BUILD_TYPE to stable..."
    sed -i 's/EVO_BUILD_TYPE ?= Unofficial/EVO_BUILD_TYPE := stable/' "$VERSION_MK"
    sed -i 's/\$(error EVO_BUILD_TYPE must be Official or Unofficial./# \$(error EVO_BUILD_TYPE must be Official or Unofficial./' "$VERSION_MK"
fi
    
# Reset strings.xml so sed can find the original string every loop
if [ -d "packages/apps/Updater" ]; then
    git -C packages/apps/Updater checkout app/src/main/res/values/strings.xml 2>/dev/null || true
fi
    
# Dynamically patch the Updater URL with variable expansion and pipe delimiters
UPDATER_FILE="packages/apps/Updater/app/src/main/res/values/strings.xml"
if [ -f "$UPDATER_FILE" ]; then
    echo "==> Patching Updater URL for ${FS_TYPE}-${GAPPS_CHOICE}..."
    TARGET_URL="raw.githubusercontent.com/XiaomiCreek/OTA/${VERS}/builds/{device}-${FS_TYPE}-${GAPPS_CHOICE}.json"
    sed -i "s|raw.githubusercontent.com/OTA/bka/builds/{device}.json/|${TARGET_URL}|g" "$UPDATER_FILE"
fi

# Build environment setup
print_step "setting up build environment"
source build/envsetup.sh

# Maintainer and Host Info
export BUILD_USERNAME="nuruszama"
export BUILD_HOSTNAME="creek"

# Make build name unique (e.g. erofs-gapps)
export BUILD_CONFIG="${FS_TYPE}-${GAPPS_CHOICE}"
export TARGET_UNOFFICIAL_BUILD_ID=${BUILD_CONFIG}

# Build the ROM
print_step "setting up breakfast"
breakfast ${DEVICE} ${BUILD_TYPE}
if [ $? -ne 0 ]; then
    print_exit "Breakfast failed. Exiting."
fi

print_step "baconing the rom hot"
make installclean
m evolution 2>&1 | tee "$BUILD_LOG"

END_TIME=$(date +%s)
BUILD_DIFF=$((END_TIME - START_TIME))
if [ $BUILD_DIFF -ge 3600 ]; then
    BUILD_TIME="$((BUILD_DIFF/3600))h $(((BUILD_DIFF%3600)/60))min"
else
    BUILD_TIME="$((BUILD_DIFF/60)) min"
fi

# what if build fails?
if grep -q -E "ninja failed|failed to build some targets" "$BUILD_LOG"; then
    telegram_reply "💥 *Build failed*
    
Took ${BUILD_TIME}"
    exit 0
else

# managing things if build succeed
    COMPLETE_TEXT="╒═══════════════════╕
            ◐ *Build Completed* ◑   
└───────────────────┘

Took ${BUILD_TIME}
"

    # Upload ROM zip file to PixelDrain
    # Define the target directory
    ROM_DIR="out/target/product/${DEVICE}/"
    ZIP_FILE=$(ls "$ROM_DIR" | grep "${ROM_NAME}-.*.zip$" | tail -n 1)
    export BUILD_DATE=$(echo "$ZIP_FILE" | grep -oP '\b20\d{6}\b')
    REC_FILE="recovery.img"

    # Check if we actually found a matching zip file
    if [ -n "${ZIP_FILE}" ]; then
        ROM_PATH="${ROM_DIR}/${ZIP_FILE}"
        REC_PATH="${ROM_DIR}/${REC_FILE}"
        
        echo "Uploading ROM file to PixelDrain: ${ZIP_FILE}..."

        # Call custom pixeldrain upload function and capture the output URL directly
        PD_URL=$(pixeldrain_upload "$ROM_PATH")
        UPLOAD_STATUS=$?
        
        if [ $UPLOAD_STATUS -eq 0 ] && [[ "$PD_URL" == http* ]]; then
            echo "ROM uploaded successfully to PixelDrain!"
            echo "URL: ${PD_URL}"

            # Start building the files block with the ROM zip entry
            FILES_TEXT="╭─ Files
• [${ROM_NAME}-${ROM_VERSION}](${PD_URL})"

            # Path to the compiler's auto-generated JSON
            OTA_JSON="out/target/product/${DEVICE}/${DEVICE}.json"

            if [ -f "$OTA_JSON" ]; then
                # Send the clean document file to the group chat
                CAPTION="🚀 *OTA Update Configuration File for ${DEVICE}*"
                telegram_send_document "$OTA_JSON" "$CAPTION"
            else
                # Fallback warning if build output tree context path is missing
                telegram_reply "⚠️ ${DEVICE}.json not found."
            fi
            
            # Start recovery upload
            REC_URL=""
            if [ -f "$REC_PATH" ]; then
                echo "Uploading recovery.img to PixelDrain..."
                PD_REC_URL=$(pixeldrain_upload "$REC_PATH")
                
                if [ $? -eq 0 ] && [ -n "$PD_REC_URL" ]; then
                    echo "Recovery uploaded successfully to PixelDrain!"
                    REC_URL="$PD_REC_URL"
                    # Dynamically add the recovery line if upload succeeded
                    FILES_TEXT="${FILES_TEXT}
• [recovery.img](${PD_REC_URL})"
                else
                    echo "Recovery upload failed, falling back to Telegram group link."
                fi
                
            else
                echo "recovery.img not found in ${ROM_DIR}. Skipping recovery upload."
            fi

            # Append the screenshots or channel link at the end of the block
            FILES_TEXT="${FILES_TEXT}
• [screenshots](https://t.me/los_creek)"

            telegram_reply "${COMPLETE_TEXT}
${FILES_TEXT}"

        else
            text="

Failed to upload ROM to PixelDrain.
Check your network or credentials."
            telegram_reply "${COMPLETE_TEXT}${text}"
        fi
    else
        text="ROM file matching ${ROM_NAME} not found in ${ROM_DIR}. Upload skipped."
        telegram_reply "${COMPLETE_TEXT}${text}"
    fi
fi

# Script ends here.. Thanks for checking it...
