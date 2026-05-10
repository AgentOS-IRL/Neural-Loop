#!/bin/bash
set -euo pipefail

# --- CONFIGURATION ---
PROJECT_NAME="Neural Loop"
SCHEME_NAME="Neural Loop Watch Watch App"
APP_NAME="Neural Loop Watch Watch App"
BUNDLE_ID="com.sanjeevhalyal.Neural-Loop.watchkitapp"
WATCH_DEVICE_UDID="${WATCH_DEVICE_UDID:-767DB7E0-3FAB-5B93-AEF2-F1BC55072BBF}"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUILD_PRODUCTS_PATH="./build/watch-products"
LOG_DIR="./build/logs"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"

mkdir -p "${LOG_DIR}"

print_error_summary() {
    local log_file="$1"
    local matches

    matches="$(
        grep -Eai \
            "xcodebuild: error:|(^|[^[:alpha:]])error:|(^|[^[:alpha:]])ERROR([^[:alpha:]]|$)|failed|unable|not found|No such file|Operation not permitted|Permission denied|Provisioning|Signing|CodeSign|❌" \
            "${log_file}" | tail -n 80 || true
    )"

    if [ -n "${matches}" ]; then
        echo "${matches}"
    else
        tail -n 40 "${log_file}" || true
    fi
}

run_quietly() {
    local label="$1"
    local log_file="$2"
    shift 2

    echo "→ ${label}..."

    if "$@" >"${log_file}" 2>&1; then
        echo "✅ ${label} complete."
        return 0
    fi

    local status=$?
    echo "❌ ${label} failed."
    echo "Errors:"
    print_error_summary "${log_file}"
    echo "Full log: ${log_file}"
    return "${status}"
}

echo "🚀 Starting watchOS build for ${SCHEME_NAME}..."

# 1. Build the watch app scheme.
BUILD_LOG="${LOG_DIR}/watch-build-${TIMESTAMP}.log"
if ! run_quietly "Build watch app" "${BUILD_LOG}" \
  xcodebuild build \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_NAME}" \
  -configuration "${CONFIGURATION}" \
  -destination "generic/platform=watchOS" \
  SYMROOT="${BUILD_PRODUCTS_PATH}" \
  ALLOW_PROVISIONING_DEVICE_REGISTRATION=NO
then
    echo "❌ Skipping watch deployment."
    exit 1
fi

# 2. Identify the .app bundle.
APP_BUNDLE_PATH="${BUILD_PRODUCTS_PATH}/${CONFIGURATION}-watchos/${APP_NAME}.app"

if [ ! -d "${APP_BUNDLE_PATH}" ]; then
    echo "❌ Expected watch app bundle not found at ${APP_BUNDLE_PATH}. Skipping deployment."
    exit 1
fi

# --- DEVICE AVAILABILITY CHECK ---
echo "🔍 Checking if watch device ${WATCH_DEVICE_UDID} is available..."

# Capture the device list first so `pipefail` does not turn a successful match
# into a false negative when upstream output is cut short.
DEVICE_LIST_LOG="${LOG_DIR}/watch-devices-${TIMESTAMP}.log"
if ! DEVICE_LIST_OUTPUT="$(xcrun devicectl list devices 2>"${DEVICE_LIST_LOG}")"; then
    echo "❌ Watch device lookup failed."
    echo "Errors:"
    print_error_summary "${DEVICE_LIST_LOG}"
    echo "Full log: ${DEVICE_LIST_LOG}"
    exit 1
fi

if [[ "${DEVICE_LIST_OUTPUT}" == *"${WATCH_DEVICE_UDID}"* ]]; then
    echo "⌚ Watch device found. Proceeding with install..."

    # 3. Install to watch device.
    INSTALL_LOG="${LOG_DIR}/watch-install-${TIMESTAMP}.log"
    if ! run_quietly "Install watch app" "${INSTALL_LOG}" \
      xcrun devicectl device install app --device "${WATCH_DEVICE_UDID}" "${APP_BUNDLE_PATH}"
    then
        exit 1
    fi

    # 4. Launch watch app.
    LAUNCH_LOG="${LOG_DIR}/watch-launch-${TIMESTAMP}.log"
    if ! run_quietly "Launch watch app" "${LAUNCH_LOG}" \
      xcrun devicectl device process launch --device "${WATCH_DEVICE_UDID}" "${BUNDLE_ID}"
    then
        exit 1
    fi

    echo "✅ Done!"
else
    echo "⚠️  Error: Watch device ${WATCH_DEVICE_UDID} is not available/connected."
    echo "❌ Skipping install and launch."
    exit 1
fi
