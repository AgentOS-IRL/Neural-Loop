#!/bin/bash
set -euo pipefail

# --- CONFIGURATION ---
PROJECT_NAME="Neural Loop"
SCHEME_NAME="Neural Loop"
BUNDLE_ID="com.sanjeevhalyal.Neural-Loop"
DEVICE_UDID="72D40F6B-9625-5561-932B-E71F4E30E3BF"
EXPORT_PATH="./build"
LOG_DIR="${EXPORT_PATH}/logs"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"
DEPLOY_AFTER_BUILD=true

usage() {
    cat <<EOF
Usage: $0 [--build-only | --install]

Options:
  --build-only  Build the archive, then stop without installing or launching.
  --install     Build, install on the configured device, and launch the app.
                This is the default behavior.
  -h, --help    Show this help message.
EOF
}

if [ "$#" -gt 1 ]; then
    usage >&2
    exit 2
fi

case "${1:-}" in
    ""|--install)
        DEPLOY_AFTER_BUILD=true
        ;;
    --build-only)
        DEPLOY_AFTER_BUILD=false
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        echo "❌ Unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
esac

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

echo "🚀 Starting Build for ${SCHEME_NAME}..."

# 1. Clean and Archive
BUILD_LOG="${LOG_DIR}/archive-${TIMESTAMP}.log"
if ! run_quietly "Build archive" "${BUILD_LOG}" \
  xcodebuild archive \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_NAME}" \
  -archivePath "${EXPORT_PATH}/${PROJECT_NAME}.xcarchive" \
  -destination "generic/platform=iOS" \
  ALLOW_PROVISIONING_DEVICE_REGISTRATION=NO
then
    echo "❌ Skipping deployment."
    exit 1
fi

# 2. Identify the .app bundle
APP_BUNDLE_PATH="${EXPORT_PATH}/${PROJECT_NAME}.xcarchive/Products/Applications/${PROJECT_NAME}.app"

if [ ! -d "${APP_BUNDLE_PATH}" ]; then
    echo "❌ Expected app bundle not found at ${APP_BUNDLE_PATH}. Skipping deployment."
    exit 1
fi

if [ "${DEPLOY_AFTER_BUILD}" = false ]; then
    echo "✅ Build-only mode complete. Archive: ${EXPORT_PATH}/${PROJECT_NAME}.xcarchive"
    exit 0
fi

# --- DEVICE AVAILABILITY CHECK ---
echo "🔍 Checking if device ${DEVICE_UDID} is available..."

# Capture the device list first so `pipefail` does not turn a successful match
# into a false negative when upstream output is cut short.
DEVICE_LIST_LOG="${LOG_DIR}/devices-${TIMESTAMP}.log"
if ! DEVICE_LIST_OUTPUT="$(xcrun devicectl list devices 2>"${DEVICE_LIST_LOG}")"; then
    echo "❌ Device lookup failed."
    echo "Errors:"
    print_error_summary "${DEVICE_LIST_LOG}"
    echo "Full log: ${DEVICE_LIST_LOG}"
    exit 1
fi

# Search for the UDID in the list of connected devices
if [[ "${DEVICE_LIST_OUTPUT}" == *"${DEVICE_UDID}"* ]]; then
    echo "📱 Device found! Proceeding with install..."

    # 3. Install to device
    INSTALL_LOG="${LOG_DIR}/install-${TIMESTAMP}.log"
    if ! run_quietly "Install app" "${INSTALL_LOG}" \
      xcrun devicectl device install app --device "${DEVICE_UDID}" "${APP_BUNDLE_PATH}"
    then
        exit 1
    fi

    # 4. Launch app
    echo "🚀 Launching ${BUNDLE_ID}..."
    LAUNCH_LOG="${LOG_DIR}/launch-${TIMESTAMP}.log"
    if ! run_quietly "Launch app" "${LAUNCH_LOG}" \
      xcrun devicectl device process launch --device "${DEVICE_UDID}" "${BUNDLE_ID}"
    then
        exit 1
    fi

    echo "✅ Done!"
else
    echo "⚠️  Error: Device ${DEVICE_UDID} is not available/connected."
    echo "❌ Skipping install and launch."
    exit 1
fi
