#!/bin/bash
set -e

clear

# Array of target variants: "FS_TYPE GAPPS_BUILD"
VARIANTS=(
    "erofs gapps"
    "erofs vanilla"
)

# Export environment variables for the upload script
export SF_USER="nuruszama"
export SF_PROJECT="xiaomicreek"
export ANDROID_VER="16"
export ROM_NAME="EvolutionX"
export ROM_VERSION="11.11"
export BUILD_TYPE="userdebug"
export DEVICE="creek"
export SSH_KEY="$HOME/.ssh/id_ed25519"
export SCREENSHOTS="https://t.me/creekglobal/3776"
export DISCUSSION="https://t.me/creekglobal"
export BANNER="https://raw.githubusercontent.com/nuruszama/crave/creek/evox/EvolutionX_Banner.png"

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
}
trap cleanup_updater EXIT

# Remove local manifest and device/vendor trees to allow fresh local_manifest sync
rm -rf .repo/local_manifests
rm -rf vendor/xiaomi/creek
rm -rf device/xiaomi/creek
rm -rf device/xiaomi/creek-kernel

# Re-initialize the source
repo init -u https://github.com/Evolution-X/manifest -b bka --git-lfs --depth=1

# Clone local manifest
git clone https://github.com/XiaomiCreek/android.git -b lineage-23.2 --depth=1 .repo/local_manifests

# Resync the repo source
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

# Extract vendor tree
./vendorextract.sh

for VARIANT in "${VARIANTS[@]}"; do
    read -r FS_TYPE GAPPS_CHOICE <<< "$VARIANT"
    
    echo ""
    echo "=================================================="
    echo " STARTING BUILD: FS=${FS_TYPE^^} | TYPE=${GAPPS_CHOICE^^}"
    echo "=================================================="
    echo ""

    # Export flags read by your Lineage device tree / overlay config
    if [ "$FS_TYPE" == "erofs" ]; then
        export WITH_EROFS=true
    else
        export WITH_EROFS=false
    fi
    
    if [ "$GAPPS_CHOICE" == "gapps" ]; then
        export WITH_GMS=true
    else
        export WITH_GMS=false
    fi
    
    # Reset strings.xml so sed can find the original string every loop
    if [ -d "packages/apps/Updater" ]; then
        git -C packages/apps/Updater checkout app/src/main/res/values/strings.xml 2>/dev/null || true
    fi
    
    # Dynamically patch the Updater URL with variable expansion and pipe delimiters
    UPDATER_FILE="packages/apps/Updater/app/src/main/res/values/strings.xml"
    if [ -f "$UPDATER_FILE" ]; then
        echo "==> Patching Updater URL for ${FS_TYPE}-${GAPPS_CHOICE}..."
        TARGET_URL="raw.githubusercontent.com/XiaomiCreek/OTA/bka/builds/{device}-${FS_TYPE}-${GAPPS_CHOICE}.json"
        sed -i "s|raw.githubusercontent.com/OTA/bka/builds/{device}.json/|${TARGET_URL}|g" "$UPDATER_FILE"
    fi
    
    # Setup build env
    source build/envsetup.sh

    # Maintainer and Host Info
    export BUILD_USERNAME="nuruszama"
    export BUILD_HOSTNAME="creek"

    # Make build name unique (e.g. erofs-vanilla, erofs-gapps)
    export BUILD_CONFIG="${FS_TYPE}-${GAPPS_CHOICE}"
    export TARGET_UNOFFICIAL_BUILD_ID=${BUILD_CONFIG}

    # Prepare device menu
    breakfast ${DEVICE} ${BUILD_TYPE}

    # Clean staging dirs
    make installclean

    # Start building
    m evolution

    # Custom SSH key location (if using a different key or path)
    export SSH_KEY="$HOME/.ssh/id_ed25519"

    # Upload
    echo "uploading file..."
    ROM_DIR="out/target/product/creek/"
    ZIP_FILE=$(ls "$ROM_DIR" | grep "${ROM_NAME}-.*.zip$" | tail -n 1)
    export BUILD_DATE=$(echo "$ZIP_FILE" | grep -oP '\b20\d{6}\b')
    if [ -n "${ZIP_FILE}" ]; then
        curl -sfLo ota_json.sh -z ota_json.sh https://raw.githubusercontent.com/nuruszama/crave/creek/tools/telegram/send_doc.sh
        chmod +x ota_json.sh ; ./ota_json.sh "${ROM_DIR}${DEVICE}.json"
        curl -sfLo upload.sh -z upload.sh https://raw.githubusercontent.com/nuruszama/crave/creek/tools/sf-upload.sh
        chmod +x upload.sh ; ./upload.sh "${ROM_DIR}${ZIP_FILE}"
        echo "upload done!"
        export ROM_URL="https://sourceforge.net/projects/${SF_PROJECT}/files/${ANDROID_VER}/${ROM_NAME}/${ZIP_FILE}/download"
        export REC_URL="https://sourceforge.net/projects/${SF_PROJECT}/files/${ANDROID_VER}/${ROM_NAME}/recovery.img/download"
        curl -sfLo post_release.sh -z post_release.sh https://raw.githubusercontent.com/nuruszama/crave/creek/tools/telegram/post_release.sh
        chmod +x post_release.sh ; ./post_release.sh
        echo "release updated to telegram"
    else
        echo "no zip found at out/ dir..."
        exit 1
    fi
done

clear
echo "All variants built and uploaded successfully!"
