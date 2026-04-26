#!/bin/bash
set -euo pipefail

# --- CONFIGURATION ---
PROJECT_NAME="Neural Loop"
TARGET_NAME="Neural Loop Watch Watch App"
BUNDLE_ID="com.sanjeevhalyal.Neural-Loop.watchkitapp"
WATCH_DEVICE_UDID="${WATCH_DEVICE_UDID:-767DB7E0-3FAB-5B93-AEF2-F1BC55072BBF}"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUILD_PRODUCTS_PATH="./build/watch-products"

echo "Starting watchOS build for ${TARGET_NAME}..."

# 1. Build the watch app target.
if ! xcodebuild build \
  -project "${PROJECT_NAME}.xcodeproj" \
  -target "${TARGET_NAME}" \
  -configuration "${CONFIGURATION}" \
  -destination "generic/platform=watchOS" \
  SYMROOT="${BUILD_PRODUCTS_PATH}" \
  ALLOW_PROVISIONING_DEVICE_REGISTRATION=NO
then
    echo "Build failed. Skipping watch deployment."
    exit 1
fi

# 2. Identify the .app bundle.
APP_BUNDLE_PATH="${BUILD_PRODUCTS_PATH}/${CONFIGURATION}-watchos/${TARGET_NAME}.app"

if [ ! -d "${APP_BUNDLE_PATH}" ]; then
    echo "Expected watch app bundle not found at ${APP_BUNDLE_PATH}. Skipping deployment."
    exit 1
fi

# --- DEVICE AVAILABILITY CHECK ---
echo "Checking if watch device ${WATCH_DEVICE_UDID} is available..."

# Capture the device list first so `pipefail` does not turn a successful match
# into a false negative when upstream output is cut short.
DEVICE_LIST_OUTPUT="$(xcrun devicectl list devices)"

if [[ "${DEVICE_LIST_OUTPUT}" == *"${WATCH_DEVICE_UDID}"* ]]; then
    echo "Watch device found. Proceeding with install..."

    # 3. Install to watch device.
    xcrun devicectl device install app --device "${WATCH_DEVICE_UDID}" "${APP_BUNDLE_PATH}"

    # 4. Launch watch app.
    echo "Launching ${BUNDLE_ID}..."
    xcrun devicectl device process launch --device "${WATCH_DEVICE_UDID}" "${BUNDLE_ID}"

    echo "Done."
else
    echo "Error: Watch device ${WATCH_DEVICE_UDID} is not available/connected."
    echo "Skipping install and launch."
    exit 1
fi
