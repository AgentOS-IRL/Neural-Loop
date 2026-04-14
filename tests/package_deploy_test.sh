#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_PATH="${REPO_ROOT}/package_deploy.sh"

make_mock_bin_dir() {
    local dir
    dir="$(mktemp -d)"
    mkdir -p "${dir}/bin"
    printf '%s\n' "${dir}/bin"
}

run_failure_case() {
    local temp_dir mock_bin_dir output_file status_file
    temp_dir="$(mktemp -d)"
    mock_bin_dir="$(make_mock_bin_dir)"
    output_file="${temp_dir}/output.log"
    status_file="${temp_dir}/status"

    cat >"${mock_bin_dir}/xcodebuild" <<'EOF'
#!/bin/bash
exit 42
EOF
    chmod +x "${mock_bin_dir}/xcodebuild"

    cat >"${mock_bin_dir}/xcrun" <<EOF
#!/bin/bash
touch "${temp_dir}/xcrun-called"
exit 0
EOF
    chmod +x "${mock_bin_dir}/xcrun"

    set +e
    (
        cd "${temp_dir}"
        PATH="${mock_bin_dir}:$PATH" bash "${SCRIPT_PATH}" >"${output_file}" 2>&1
    )
    local status=$?
    set -e
    echo "${status}" >"${status_file}"

    local status
    status="$(cat "${status_file}")"
    if [ "${status}" -eq 0 ]; then
        echo "expected failure case to exit non-zero"
        exit 1
    fi

    grep -q "Build failed. Skipping deployment." "${output_file}"

    if [ -e "${temp_dir}/xcrun-called" ]; then
        echo "xcrun should not be called when the archive fails"
        exit 1
    fi
}

run_success_case() {
    local temp_dir mock_bin_dir output_file status_file
    temp_dir="$(mktemp -d)"
    mock_bin_dir="$(make_mock_bin_dir)"
    output_file="${temp_dir}/output.log"
    status_file="${temp_dir}/status"

    cat >"${mock_bin_dir}/xcodebuild" <<EOF
#!/bin/bash
mkdir -p "\$(pwd)/build/Neural Loop.xcarchive/Products/Applications/Neural Loop.app"
exit 0
EOF
    chmod +x "${mock_bin_dir}/xcodebuild"

    cat >"${mock_bin_dir}/xcrun" <<EOF
#!/bin/bash
case "\$*" in
    "devicectl list devices")
        printf '%s\n' "Some Device ${DEVICE_UDID:-72D40F6B-9625-5561-932B-E71F4E30E3BF}"
        for _ in \$(seq 1 5000); do
            printf '%s\n' "additional device listing output"
        done
        ;;
    "devicectl device install app --device 72D40F6B-9625-5561-932B-E71F4E30E3BF ./build/Neural Loop.xcarchive/Products/Applications/Neural Loop.app")
        touch "${temp_dir}/install-called"
        ;;
    "devicectl device process launch --device 72D40F6B-9625-5561-932B-E71F4E30E3BF com.sanjeevhalyal.Neural-Loop")
        touch "${temp_dir}/launch-called"
        ;;
    *)
        echo "unexpected xcrun invocation: \$*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "${mock_bin_dir}/xcrun"

    set +e
    (
        cd "${temp_dir}"
        PATH="${mock_bin_dir}:$PATH" bash "${SCRIPT_PATH}" >"${output_file}" 2>&1
    )
    local status=$?
    set -e
    echo "${status}" >"${status_file}"

    local status
    status="$(cat "${status_file}")"
    if [ "${status}" -ne 0 ]; then
        echo "expected success case to exit zero"
        cat "${output_file}"
        exit 1
    fi

    [ -e "${temp_dir}/install-called" ]
    [ -e "${temp_dir}/launch-called" ]
}

main() {
    run_failure_case
    run_success_case
    echo "package_deploy.sh regression tests passed"
}

main "$@"
