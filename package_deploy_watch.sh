#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- CONFIGURATION ---
PROJECT_NAME="Neural Loop"
SCHEME_NAME="Neural Loop Watch Watch App"
APP_NAME="Neural Loop Watch Watch App"
BUNDLE_ID="com.sanjeevhalyal.Neural-Loop.watchkitapp"
WATCH_DEVICE_UDID="${WATCH_DEVICE_UDID:-767DB7E0-3FAB-5B93-AEF2-F1BC55072BBF}"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUILD_PRODUCTS_PATH="${SCRIPT_DIR}/build/watch-products"
LOG_DIR="${SCRIPT_DIR}/build/logs"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"

# --- STATE ---
ACTION="install"
HAS_GUM=false
command -v gum &>/dev/null && HAS_GUM=true

# --- USAGE ---

usage() {
    cat <<EOF
Usage: $0 [action]

Actions:
  install    Build, install, and launch the watch app (default)
  build      Build the watch app only
  check      Check if the watch device is reachable

Options:
  -h, --help Show this help message
EOF
}

# --- CLI PARSING ---

if [ $# -eq 0 ] && [ "${HAS_GUM}" = true ] && [ -t 0 ]; then
    # ✨ Interactive mode
    echo ""
    gum style --border rounded --padding "0 1" --border-foreground 141 \
        "⌚ Neural Loop Watch Deploy"
    echo ""

    ACTION=$(gum choose --header "Select action" \
        "install — Build, install, and launch" \
        "build — Build only" \
        "check — Verify watch connectivity")
    ACTION="${ACTION%% —*}"

    echo ""
    gum style --foreground 245 "▸ Action: ${ACTION}"
    echo ""
else
    # 🤖 Headless mode
    case "${1:-install}" in
        install|build|check) ACTION="${1:-install}" ;;
        -h|--help)           usage; exit 0 ;;
        *)
            echo "❌ Unknown argument: $1" >&2
            echo "" >&2
            usage >&2
            exit 2
            ;;
    esac
fi

mkdir -p "${LOG_DIR}"

# --- HELPERS ---

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

# Run a command silently, logging output to a file.
# Prints a ✅ or ❌ status line and returns 0 on success, 1 on failure.
run_quietly() {
    local label="$1"
    local log_file="$2"
    shift 2

    echo "  → ${label}..."

    set +e
    "$@" >"${log_file}" 2>&1
    local status=$?
    set -e

    if [ "${status}" -eq 0 ]; then
        echo "  ✅ ${label}"
    else
        echo "  ❌ ${label}"
        echo "  Errors:"
        print_error_summary "${log_file}"
        echo "  Full log: ${log_file}"
    fi
    return "${status}"
}

check_device() {
    echo "  🔍 Watch (${WATCH_DEVICE_UDID})..."

    local device_log="${LOG_DIR}/watch-devices-${TIMESTAMP}.log"
    local device_list
    if ! device_list="$(xcrun devicectl list devices 2>"${device_log}")"; then
        echo "  ❌ Watch device lookup failed. See: ${device_log}"
        return 1
    fi

    if [[ "${device_list}" == *"${WATCH_DEVICE_UDID}"* ]]; then
        echo "  ⌚ Watch found"
        return 0
    else
        echo "  ⚠️  Watch not available"
        return 1
    fi
}

# ============================
# CHECK
# ============================
if [ "${ACTION}" = "check" ]; then
    echo "🔍 Checking watch device..."
    if check_device; then
        echo "✅ Watch device reachable."
    else
        echo "❌ Watch device check failed."
        exit 1
    fi
    exit 0
fi

# ============================
# INSTALL: verify device before spending time building
# ============================
if [ "${ACTION}" = "install" ]; then
    echo "🔍 Checking watch device..."
    if ! check_device; then
        echo "❌ Aborting — watch device not reachable."
        exit 1
    fi
    echo ""
fi

# ============================
# BUILD
# ============================
echo "🚀 Building ${SCHEME_NAME}..."

BUILD_LOG="${LOG_DIR}/watch-build-${TIMESTAMP}.log"
if ! run_quietly "Build watch app" "${BUILD_LOG}" \
  xcodebuild build \
  -project "${SCRIPT_DIR}/${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_NAME}" \
  -configuration "${CONFIGURATION}" \
  -destination "generic/platform=watchOS" \
  SYMROOT="${BUILD_PRODUCTS_PATH}" \
  ALLOW_PROVISIONING_DEVICE_REGISTRATION=NO
then
    echo "Watch build failed. Skipping deployment."
    exit 1
fi

APP_BUNDLE_PATH="${BUILD_PRODUCTS_PATH}/${CONFIGURATION}-watchos/${APP_NAME}.app"
if [ ! -d "${APP_BUNDLE_PATH}" ]; then
    echo "❌ Watch app bundle not found at ${APP_BUNDLE_PATH}."
    exit 1
fi

if [ "${ACTION}" = "build" ]; then
    echo "✅ Watch build complete → ${APP_BUNDLE_PATH}"
    exit 0
fi

# ============================
# INSTALL + LAUNCH
# ============================
echo ""
echo "📲 Installing watch app..."

INSTALL_LOG="${LOG_DIR}/watch-install-${TIMESTAMP}.log"
if ! run_quietly "Install" "${INSTALL_LOG}" \
  xcrun devicectl device install app --device "${WATCH_DEVICE_UDID}" "${APP_BUNDLE_PATH}"
then
    exit 1
fi

LAUNCH_LOG="${LOG_DIR}/watch-launch-${TIMESTAMP}.log"
if ! run_quietly "Launch ${BUNDLE_ID}" "${LAUNCH_LOG}" \
  xcrun devicectl device process launch --device "${WATCH_DEVICE_UDID}" "${BUNDLE_ID}"
then
    exit 1
fi

echo "✅ Watch deployed!"
