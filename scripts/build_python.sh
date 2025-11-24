#!/usr/bin/env bash
set -euo pipefail

readonly THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly BASE_DIR="${THIS_DIR}/.."
readonly DATA_DIR="${BASE_DIR}/data"
readonly CONFIGURE_DIR="${DATA_DIR}/configure"
readonly MAKE_DIR="${DATA_DIR}/make"

readonly BUILD_DIR='/tmp/python-build'

function init() {
    swapoff -a
}

function cleanup() {
    swapon -a
}

function interrupt() {
    cleanup
    exit 1
}

function workload() {
    local iter="$1"
    local python_zip="$2"

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
    ./configure > "${CONFIGURE_DIR}/configure_${iter}.log" 2>&1
    make -j 7 > "${MAKE_DIR}/make_${iter}.log" 2>&1
}

function main() {
    if [[ $# -ne 2 ]]; then
        echo "USAGE: $0 <num iterations> <python zip path>"
        exit 1
    fi

    local num_iter="$1"
    local zipfile="$2"

    mkdir -p "${DATA_DIR}"
    mkdir -p "${CONFIGURE_DIR}"
    mkdir -p "${MAKE_DIR}"

    init
    sleep 2
    trap interrupt SIGINT

    for i in $(seq 1 "${num_iter}"); do
        echo "=== Build Python Iteration ${i}/${num_iter} ==="
        workload "${i}" "${zipfile}"
    done

    cleanup

    echo "Experiment complete."
    exit 0
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"
