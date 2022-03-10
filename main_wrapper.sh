#!/bin/bash
set -e

# FIXME: This entire script should not be needed!
#        Users need to be able to decide which python environment is needed by their workflows!
# FIXME: Need to stage correct python environment to remote VM

local_conda_env="parsl_py39"
local_conda_sh="/pw/.miniconda3/etc/profile.d/conda.sh"

export REMOTE_CONDA_ENV="parsl_py39"
export REMOTE_CONDA_SH="/contrib/${PW_USER}/miniconda3/etc/profile.d/conda.sh"


# Activate conda environment in user container
{
    source ${local_conda_sh}
    conda activate ${local_conda_env}
} || {
    "Conda environment ${local_conda_env} not found"
    exit 0
}

# Check remote conda environment
echo "source ${REMOTE_CONDA_SH}" > check_remote_conda.sh
echo "conda activate ${REMOTE_CONDA_ENV}" >> check_remote_conda.sh
{
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${HOST_IP} 'bash -s' < check_remote_conda.sh
} || {
    echo Remote conda environment not found:
    echo     CONDA SH:  ${REMOTE_CONDA_SH}
    echo     CONDA ENV: ${REMOTE_CONDA_ENV}
    echo See install instructions below:
    echo "Install miniconda under /contrib/${PW_USER}/miniconda3 https://docs.conda.io/en/latest/miniconda.html"
    echo "Run: conda create --name parsl_py39 python=3.9; pip install parsl==1.1.0"
    exit 0
}

$@