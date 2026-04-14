#!/bin/bash

# --- CONFIGURATION ---
PROJECT_NAME="Neural Loop"
SCHEME_NAME="Neural Loop"   # <--- Updated this
BUNDLE_ID="com.sanjeevhalyal.Neural-Loop"
DEVICE_UDID="72D40F6B-9625-5561-932B-E71F4E30E3BF"
EXPORT_PATH="./build"

echo "🚀 Starting Build for ${SCHEME_NAME}..."

# 1. Clean and Archive
xcodebuild archive \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_NAME}" \
  -archivePath "${EXPORT_PATH}/${PROJECT_NAME}.xcarchive" \
  -destination "generic/platform=iOS" \
  ALLOW_PROVISIONING_DEVICE_REGISTRATION=NO

# 2. Identify the .app bundle
APP_BUNDLE_PATH="${EXPORT_PATH}/${PROJECT_NAME}.xcarchive/Products/Applications/${PROJECT_NAME}.app"

echo "📲 Installing to device ${DEVICE_UDID} using devicectl..."

# Use Apple's native tool for iOS 17+ devices
xcrun devicectl device install app --device "${DEVICE_UDID}" "${APP_BUNDLE_PATH}"


echo "🚀 Launch app on device"
xcrun devicectl device process launch --device "${DEVICE_UDID}" com.sanjeevhalyal.Neural-Loop


echo "✅ Done!"
