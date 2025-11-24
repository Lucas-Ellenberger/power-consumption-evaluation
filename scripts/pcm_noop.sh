#!/usr/bin/env bash
set -euo pipefail

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_DIR="${THIS_DIR}/.."
readonly DATA_DIR="${BASE_DIR}/data"
readonly PCM_CSV="${DATA_DIR}/pcm-noop.csv"
readonly PCM_DIR="${BASE_DIR}/../pcm"
readonly PCM_FILE="${PCM_DIR}/build/bin/pcm"

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
    sleep 60
}

function main() {
    if [[ $# -ne 1 ]]; then
        echo "USAGE: $0 <num iterations>"
        exit 1
    fi

    local num_iter="$1"

    mkdir -p "${DATA_DIR}"

    init
    sleep 2
    trap interrupt SIGINT

    for i in $(seq 1 "${num_iter}"); do
        echo "=== Noop Iteration ${i}/${num_iter} ==="
        workload
    done

    cleanup "$pcm_pid"

    echo "Experiment complete. PCM data: ${PCM_CSV}"
    exit 0
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
