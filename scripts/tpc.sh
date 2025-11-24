#!/usr/bin/env bash
set -euo pipefail

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_DIR="${THIS_DIR}/.."
readonly DATA_DIR="${BASE_DIR}/data"
readonly PCM_CSV="${DATA_DIR}/pcm-tpc.csv"
readonly PCM_DIR="${BASE_DIR}/../pcm"
readonly PCM_FILE="${PCM_DIR}/build/bin/pcm"
readonly TPC_DIR="${BASE_DIR}/../benchbase/target/benchbase-postgres"
readonly TPC_DATA_DIR="${TPC_DIR}/datafiles"

function init() {
    # Minimize caching effects between runs.
    swapoff -a

    # Start postgresql server.
    sudo systemctl start postgresql
}

function cleanup() {
    # Turn swapping back on.
    swapon -a
}

function interrupt() {
    echo 'Interrupted. Stopping PCM.'
    cleanup
    exit 1
}

function workload() {
    cd "${TPC_DIR}"

    # Clear system cache.
    echo 3 | sudo tee '/proc/sys/vm/drop_caches'

    java -jar benchbase.jar -b tpcc -c config/postgres/sample_tpcc_config.xml --create=true --load=true --execute=true
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
    trap cleanup EXIT

    for i in $(seq 1 "${num_iter}"); do
        echo "=== TPC Iteration ${i}/${num_iter} ==="
        workload
    done

    cleanup

    echo "Experiment complete. PCM data: ${PCM_CSV}"
    exit 0
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
