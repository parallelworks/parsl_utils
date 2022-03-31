#!/bin/bash
set -e
SINGULARITY_CONTAINER_PATH=$1
SINGULARITY_FILE=$2

if ! [ -f "${SINGULARITY_CONTAINER_PATH}" ]; then
    mkdir -p $(basename ${SINGULARITY_CONTAINER_PATH})
    sudo singularity build ${SINGULARITY_CONTAINER_PATH} ${SINGULARITY_FILE}
fi

