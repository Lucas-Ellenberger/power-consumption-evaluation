#!/usr/bin/env bash
# set -euo pipefail

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_DIR="${THIS_DIR}/.."
readonly DATA_DIR="${BASE_DIR}/data"
readonly PCM_LOG="${DATA_DIR}/pcm-continuous.log"
readonly PCM_DIR="${BASE_DIR}/../pcm"
readonly PCM_FILE="${PCM_DIR}/build/bin/pcm"

readonly BUILD_DIR='/tmp/python-build'

pcm_pid=0

function start_pcm() {
    echo "Starting PCM monitoring..."
    sudo "${PCM_FILE}" --power 1 | tee "${PCM_LOG}" &
    pcm_pid=$!
}

function stop_pcm() {
    echo "Stopping PCM (PID ${1:-$pcm_pid})..."
    sudo kill "${1:-$pcm_pid}" 2>/dev/null || true
}

function interrupt() {
    echo "Interrupted. Stopping PCM..."
    stop_pcm "$pcm_pid"
    exit 1
}

function workload() {
    local python_zip="$1"
    local iter="$2"

    echo "Running workload iteration ${iter} with ${python_zip}"

    # Clear build directory.
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"

    # Extract source file.
    tar -xJf "${python_zip}" -C "${BUILD_DIR}"
    cd "${BUILD_DIR}"/*/

    # Configure and build Python.
    ./configure > "${DATA_DIR}/configure_${iter}.log" 2>&1
    make -j"$(nproc)" > "${DATA_DIR}/make_${iter}.log" 2>&1
}

function main() {
    if [[ $# -ne 2 ]]; then
        echo "USAGE: $0 <num iterations> <python zip path>"
        exit 1
    fi

    local num_iter="$1"
    local zipfile="$2"

    mkdir -p "${DATA_DIR}"

    start_pcm
    sleep 2
    trap interrupt SIGINT

    for i in $(seq 1 "${num_iter}"); do
        echo "=== Iteration ${i}/${num_iter} ==="
        workload "${zipfile}" "${i}"
    done

    stop_pcm "$pcm_pid"

    echo "Experiment complete. PCM data: ${PCM_LOG}"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
