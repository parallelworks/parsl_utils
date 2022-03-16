#!/bin/bash
set -e

LOCAL_CONDA_SH=$1
LOCAL_COND_ENV=$2

{
    source ${LOCAL_CONDA_SH}
} || {
    echo "ERROR! Miniconda installation below not found!"
    echo "${LOCAL_CONDA_SH}"
    echo "You must install miniconda in the user's docker container!"
    exit 1
}


# Install conda environment if not found in user container
{
    conda activate ${LOCAL_CONDA_ENV}
} || {
    echo "Installing environment in ${PW_USER}'s local docker environment"
    conda create --name ${LOCAL_CONDA_ENV} python=3.9; yes | pip install parsl==1.1.0
}
