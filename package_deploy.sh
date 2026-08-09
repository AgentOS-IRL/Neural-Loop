#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- CONFIGURATION ---
PROJECT_NAME="Neural Loop"
SCHEME_NAME="Neural Loop"
BUNDLE_ID="com.sanjeevhalyal.Neural-Loop"
DEVICE_UDID="72D40F6B-9625-5561-932B-E71F4E30E3BF"
EXPORT_PATH="./build"
LOG_DIR="${EXPORT_PATH}/logs"
TIMESTAMP="$(date +"%Y%m%d-%H%M%S")"

# --- STATE ---
ACTION="install"
INCLUDE_WATCH=false
HAS_GUM=false
command -v gum &>/dev/null && HAS_GUM=true

# --- USAGE ---

usage() {
    cat <<EOF
Usage: $0 [action] [options]

Actions:
  install    Build, install, and launch the app (default)
  build      Build the archive only
  check      Check if the target device is reachable

Options:
  --watch    Include the watchOS companion app
  -h, --help Show this help message

Examples:
  $0                     Install iOS app
  $0 --watch             Install iOS + Watch apps
  $0 build               Build iOS archive only
  $0 build --watch       Build iOS + Watch archives
  $0 check               Check if iPhone is reachable
  $0 check --watch       Check if iPhone + Watch are reachable
EOF
}

# --- CLI PARSING ---

if [ $# -eq 0 ] && [ "${HAS_GUM}" = true ] && [ -t 0 ]; then
    # ✨ Interactive mode — no args, gum available, running in a terminal
    echo ""
    gum style --border rounded --padding "0 1" --border-foreground 212 \
        "📱 Neural Loop Deploy"
    echo ""

    ACTION=$(gum choose --header "Select action" \
        "install — Build, install, and launch" \
        "build — Build archive only" \
        "check — Verify device connectivity")
    ACTION="${ACTION%% —*}"

    if gum confirm "Include watchOS companion app?"; then
        INCLUDE_WATCH=true
    fi

    echo ""
    gum style --foreground 245 \
        "▸ Action: ${ACTION}  ·  Watch: $([ "${INCLUDE_WATCH}" = true ] && echo "yes" || echo "no")"
    echo ""
else
    # 🤖 Headless mode — parse arguments for CI / scripting
    for arg in "$@"; do
        case "${arg}" in
            install|build|check) ACTION="${arg}" ;;
            --watch)             INCLUDE_WATCH=true ;;
            -h|--help)           usage; exit 0 ;;
            *)
                echo "❌ Unknown argument: ${arg}" >&2
                echo "" >&2
                usage >&2
                exit 2
                ;;
        esac
    done
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

    # Run outside an `if` so we can capture the real exit code directly.
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
    echo "  🔍 iPhone (${DEVICE_UDID})..."

    local device_log="${LOG_DIR}/devices-${TIMESTAMP}.log"
    local device_list
    if ! device_list="$(xcrun devicectl list devices 2>"${device_log}")"; then
        echo "  ❌ Device lookup failed. See: ${device_log}"
        return 1
    fi

    if [[ "${device_list}" == *"${DEVICE_UDID}"* ]]; then
        echo "  📱 iPhone found"
        return 0
    else
        echo "  ⚠️  iPhone not available"
        return 1
    fi
}

run_watch() {
    "${SCRIPT_DIR}/package_deploy_watch.sh" "$1"
}

# Verify all required devices are reachable.
preflight() {
    echo "🔍 Checking devices..."
    local ok=true

    if ! check_device; then ok=false; fi

    if [ "${INCLUDE_WATCH}" = true ]; then
        if ! run_watch check; then ok=false; fi
    fi

    [ "${ok}" = true ]
}

# ============================
# CHECK
# ============================
if [ "${ACTION}" = "check" ]; then
    if preflight; then
        echo "✅ All devices reachable."
    else
        echo "❌ Device check failed."
        exit 1
    fi
    exit 0
fi

# ============================
# INSTALL: verify devices before spending time building
# ============================
if [ "${ACTION}" = "install" ]; then
    if ! preflight; then
        echo "❌ Aborting — device(s) not reachable."
        exit 1
    fi
    echo ""
fi

# ============================
# BUILD
# ============================
echo "🚀 Building ${SCHEME_NAME}..."

BUILD_LOG="${LOG_DIR}/archive-${TIMESTAMP}.log"
if ! run_quietly "Archive" "${BUILD_LOG}" \
  xcodebuild archive \
  -project "${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME_NAME}" \
  -archivePath "${EXPORT_PATH}/${PROJECT_NAME}.xcarchive" \
  -destination "generic/platform=iOS" \
  ALLOW_PROVISIONING_DEVICE_REGISTRATION=NO
then
    echo "Build failed. Skipping deployment."
    exit 1
fi

APP_BUNDLE_PATH="${EXPORT_PATH}/${PROJECT_NAME}.xcarchive/Products/Applications/${PROJECT_NAME}.app"
if [ ! -d "${APP_BUNDLE_PATH}" ]; then
    echo "❌ App bundle not found at ${APP_BUNDLE_PATH}."
    exit 1
fi

if [ "${ACTION}" = "build" ]; then
    echo "✅ iOS build complete → ${EXPORT_PATH}/${PROJECT_NAME}.xcarchive"
    if [ "${INCLUDE_WATCH}" = true ]; then
        run_watch build
    fi
    exit 0
fi

# ============================
# INSTALL + LAUNCH
# ============================
echo ""
echo "📲 Installing..."

INSTALL_LOG="${LOG_DIR}/install-${TIMESTAMP}.log"
if ! run_quietly "Install" "${INSTALL_LOG}" \
  xcrun devicectl device install app --device "${DEVICE_UDID}" "${APP_BUNDLE_PATH}"
then
    exit 1
fi

LAUNCH_LOG="${LOG_DIR}/launch-${TIMESTAMP}.log"
if ! run_quietly "Launch ${BUNDLE_ID}" "${LAUNCH_LOG}" \
  xcrun devicectl device process launch --device "${DEVICE_UDID}" "${BUNDLE_ID}"
then
    exit 1
fi

echo "✅ iOS deployed!"

if [ "${INCLUDE_WATCH}" = true ]; then
    echo ""
    run_watch install
fi

echo ""
echo "🎉 Done!"
