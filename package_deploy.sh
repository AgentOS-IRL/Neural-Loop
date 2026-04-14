#!/bin/bash
set -euo pipefail

# --- CONFIGURATION ---
PROJECT_NAME="Neural Loop"
SCHEME_NAME="Neural Loop"
BUNDLE_ID="com.sanjeevhalyal.Neural-Loop"
DEVICE_UDID="72D40F6B-9625-5561-932B-E71F4E30E3BF"
EXPORT_PATH="./build"

echo "🚀 Starting Build for ${SCHEME_NAME}..."

# 1. Clean and Archive
if ! xcodebuild archive \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_NAME}" \
  -archivePath "${EXPORT_PATH}/${PROJECT_NAME}.xcarchive" \
  -destination "generic/platform=iOS" \
  ALLOW_PROVISIONING_DEVICE_REGISTRATION=NO
then
    echo "❌ Build failed. Skipping deployment."
    exit 1
fi

# 2. Identify the .app bundle
APP_BUNDLE_PATH="${EXPORT_PATH}/${PROJECT_NAME}.xcarchive/Products/Applications/${PROJECT_NAME}.app"

if [ ! -d "${APP_BUNDLE_PATH}" ]; then
    echo "❌ Expected app bundle not found at ${APP_BUNDLE_PATH}. Skipping deployment."
    exit 1
fi

# --- DEVICE AVAILABILITY CHECK ---
echo "🔍 Checking if device ${DEVICE_UDID} is available..."

# Capture the device list first so `pipefail` does not turn a successful match
# into a false negative when upstream output is cut short.
DEVICE_LIST_OUTPUT="$(xcrun devicectl list devices)"

# Search for the UDID in the list of connected devices
if [[ "${DEVICE_LIST_OUTPUT}" == *"${DEVICE_UDID}"* ]]; then
    echo "📱 Device found! Proceeding with install..."

    # 3. Install to device
    xcrun devicectl device install app --device "${DEVICE_UDID}" "${APP_BUNDLE_PATH}"

    # 4. Launch app
    echo "🚀 Launching ${BUNDLE_ID}..."
    xcrun devicectl device process launch --device "${DEVICE_UDID}" "${BUNDLE_ID}"

    echo "✅ Done!"
else
    echo "⚠️  Error: Device ${DEVICE_UDID} is not available/connected."
    echo "❌ Skipping install and launch."
    exit 1
fi
