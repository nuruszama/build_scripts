#!/bin/bash

# ==============================================================================
# LineageOS Multi-Variant Build Matrix
# Variants: EROFS Vanilla, EXT4 Vanilla, EROFS GApps
# ==============================================================================

set -e # Exit immediately if a command or build step fails
clear

# Array of target variants: "FS_TYPE GAPPS_BUILD"
VARIANTS=(
    "erofs vanilla"
    "erofs gapps"
    "ext4 vanilla"
    "ext4 gapps"
)

# Export constant variables for all runs
export SF_USER="nuruszama"
export SF_PROJECT="xiaomicreek"
export ANDROID_VER="16"
export ROM_NAME="LineageOS"
export ROM_VERSION="23.2"
export BUILD_TYPE="userdebug"
export DEVICE_CODENAME="creek"
export SCREENSHOTS="https://t.me/creekglobal"
export DISCUSSION="https://t.me/creekglobal"
export SSH_KEY="$HOME/.ssh/id_ed25519"
export BANNER="https://raw.githubusercontent.com/nuruszama/crave/creek/lineageos/LineageOS_Banner.jpg"

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

# re-initialize the lineage source
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --depth=1

# clone local manifest
git clone https://github.com/XiaomiCreek/android.git -b lineage-23.2 --depth=1 .repo/local_manifests

# resync the repo source
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags

# Extract vendor tree
curl -sfLo vendorextract.sh https://raw.githubusercontent.com/nuruszama/crave/creek/tools/vendorextract.sh
chmod +x vendorextract.sh
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
        export WITH_GAPPS=true
    else
        export WITH_GAPPS=false
    fi

    # Reset strings.xml so sed can find the original string every loop
    if [ -d "packages/apps/Updater" ]; then
        git -C packages/apps/Updater checkout app/src/main/res/values/strings.xml 2>/dev/null || true
    fi
    
    # Dynamically patch the Updater URL with variable expansion and pipe delimiters
    UPDATER_FILE="packages/apps/Updater/app/src/main/res/values/strings.xml"
    if [ -f "$UPDATER_FILE" ]; then
        echo "==> Patching Updater URL for ${FS_TYPE}-${GAPPS_CHOICE}..."
        TARGET_URL="raw.githubusercontent.com/XiaomiCreek/OTA/lineage-23.2/builds/{device}-${FS_TYPE}-${GAPPS_CHOICE}.json"
        sed -i "s|download.lineageos.org/api/v2/devices/{device}/builds|${TARGET_URL}|g" "$UPDATER_FILE"
    fi

    # setup build env
    source build/envsetup.sh

    # Maintainer and Host Info
    export BUILD_USERNAME=nuruszama
    export BUILD_HOSTNAME=creek

    # Make build name unique (e.g. erofs-vanilla, ext4-vanilla, erofs-gapps)
    export BUILD_CONFIG="${FS_TYPE}-${GAPPS_CHOICE}"
    export TARGET_UNOFFICIAL_BUILD_ID=${BUILD_CONFIG}
    
    # prepare device menu
    breakfast creek userdebug

    # Clean staging dirs
    make installclean

    # start building
    mka bacon

    # Upload
    echo "uploading file..."
    ROM_DIR="out/target/product/creek/"
    ZIP_FILE=$(ls "$ROM_DIR" 2>/dev/null | grep -E "^lineage-.*creek\.zip$" | tail -n 1)
    export BUILD_DATE=$(echo "$ZIP_FILE" | grep -oP '\b20\d{6}\b')
    if [ -n "${ZIP_FILE}" ]; then
        curl -sfLo upload.sh https://raw.githubusercontent.com/nuruszama/crave/creek/tools/sf-upload.sh
        chmod +x upload.sh ; ./upload.sh "${ROM_DIR}/${ZIP_FILE}"
        echo "Upload done for ${FS_TYPE}-${GAPPS_CHOICE}!"
        export ROM_URL="https://sourceforge.net/projects/${SF_PROJECT}/files/${ANDROID_VER}/${ROM_NAME}/${ZIP_FILE}/download"
        export REC_URL="https://sourceforge.net/projects/${SF_PROJECT}/files/${ANDROID_VER}/${ROM_NAME}/recovery.img/download"
        curl -sfLo post_release.sh -z post_release.sh https://raw.githubusercontent.com/nuruszama/crave/creek/tools/telegram/post_release.sh
        chmod +x post_release.sh ; ./post_release.sh ${ROM_URL} ${REC_URL}
        echo "release updated to telegram"
        
        # Clean uploaded zip to preserve workspace disk space
        rm -f "${ROM_DIR}/${ZIP_FILE}"
    else
        echo "no zip found at out/ dir..."
        exit 1
    fi
done

clear
echo "All variants built and uploaded successfully!"
