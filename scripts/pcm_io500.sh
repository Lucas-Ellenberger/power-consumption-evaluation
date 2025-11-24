#!/usr/bin/env bash
set -euo pipefail

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_DIR="${THIS_DIR}/.."
readonly DATA_DIR="${BASE_DIR}/data"
readonly PCM_CSV="${DATA_DIR}/pcm-io-500.csv"
readonly PCM_DIR="${BASE_DIR}/../pcm"
readonly PCM_FILE="${PCM_DIR}/build/bin/pcm"
readonly IO_500_DIR="${BASE_DIR}/../io500"
readonly IO_500_DATA_DIR="${IO_500_DIR}/datafiles"
readonly THIS_DIR_REL_FROM_IO_500='../power-consumption-evaluation'

pcm_pid=0
io500_pid=0

function init() {
    echo 'Starting PCM monitoring.'
    sudo bash -c "\"${PCM_FILE}\" -csv" > "${PCM_CSV}" &
    pcm_pid=$!
    swapoff -a
}

function cleanup() {
    echo "Stopping PCM (PID ${1:-$pcm_pid})..."
    sudo kill "${1:-$pcm_pid}" 2>/dev/null || true
    sudo kill "${1:-$io500_pid}" 2>/dev/null || true
    swapon -a
}

function interrupt() {
    echo 'Interrupted. Stopping PCM.'
    cleanup
    exit 1
}

function workload() {
    local io500_ini="$1"

    cd "${IO_500_DIR}"

    # Clear system cache.
    echo 3 | sudo tee '/proc/sys/vm/drop_caches'

    ./io500 "${THIS_DIR_REL_FROM_IO_500}/${io500_ini}"
    io500_pid=$!

    # Clean up written datafiles.
    rm -rf "${IO_500_DATA_DIR}"/*
}

function main() {
    if [[ $# -ne 2 ]]; then
        echo "USAGE: $0 <num iterations> <io500 ini>"
        exit 1
    fi

    local num_iter="$1"
    local io500_ini="$2"

    mkdir -p "${DATA_DIR}"

    init
    sleep 2
    trap interrupt SIGINT
    trap cleanup EXIT

    for i in $(seq 1 "${num_iter}"); do
        echo "=== IO 500 Iteration ${i}/${num_iter} ==="
        workload "${io500_ini}"
    done

    cleanup "$pcm_pid"

    echo "Experiment complete. PCM data: ${PCM_CSV}"
    exit 0
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
