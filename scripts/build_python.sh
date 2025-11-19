#!/usr/bin/env bash
set -euo pipefail

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_DIR="${THIS_DIR}/.."
readonly DATA_DIR="${BASE_DIR}/data"
readonly PCM_CSV="${DATA_DIR}/pcm-build-py.csv"
readonly PCM_DIR="${BASE_DIR}/../pcm"
readonly PCM_FILE="${PCM_DIR}/build/bin/pcm"

readonly BUILD_DIR='/tmp/python-build'

pcm_pid=0

function init() {
    echo 'Starting PCM monitoring.'
    sudo bash -c "\"${PCM_FILE}\" -csv" > "${PCM_CSV}" &
    pcm_pid=$!
    swapoff -a
}

function cleanup() {
    echo "Stopping PCM (PID ${1:-$pcm_pid})..."
    sudo kill "${1:-$pcm_pid}" 2>/dev/null || true
    swapon -a
}

function interrupt() {
    echo 'Interrupted. Stopping PCM.'
    cleanup "$pcm_pid"
    exit 1
}

function workload() {
    local python_zip="$1"
    local iter="$2"

    cd "${BASE_DIR}"

    # Clear build directory.
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"

    # Clear system cache.
    echo 3 | sudo tee '/proc/sys/vm/drop_caches'

    # Extract source file.
    tar -xJf "${python_zip}" -C "${BUILD_DIR}"
    cd "${BUILD_DIR}"/*/

    # Configure and build Python.
    ./configure > "${DATA_DIR}/configure_${iter}.log" 2>&1
    make -j 7 > "${DATA_DIR}/make_${iter}.log" 2>&1
}

function main() {
    if [[ $# -ne 2 ]]; then
        echo "USAGE: $0 <num iterations> <python zip path>"
        exit 1
    fi

    local num_iter="$1"
    local zipfile="$2"

    mkdir -p "${DATA_DIR}"

    init
    sleep 2
    trap interrupt SIGINT

    for i in $(seq 1 "${num_iter}"); do
        echo "=== Iteration ${i}/${num_iter} ==="
        workload "${zipfile}" "${i}"
    done

    cleanup "$pcm_pid"

    echo "Experiment complete. PCM data: ${PCM_CSV}"
    exit 0
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
