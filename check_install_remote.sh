#!/bin/bash
set -e
REMOTE_CONDA_DIR=$1
REMOTE_CONDA_SH=$2
REMOTE_CONDA_ENV=$3

f_install_miniconda() {
    install_dir=$1
    echo "Installing Miniconda3-py39_4.9.2"
    conda_repo="https://repo.anaconda.com/miniconda/Miniconda3-py39_4.9.2-Linux-x86_64.sh"
    nohup wget ${conda_repo} -O /tmp/miniconda.sh 2>&1 > /tmp/miniconda_wget.out
    rm -rf ${install_dir}
    mkdir -p $(dirname ${install_dir})
    nohup bash /tmp/miniconda.sh -b -p ${install_dir} 2>&1 > /tmp/miniconda_sh.out
}

{
    # Check if miniconda is installed
    {
        source ${REMOTE_CONDA_SH}
    } || {
        f_install_miniconda ${REMOTE_CONDA_DIR}
        source ${REMOTE_CONDA_SH}
    }

    # Check if conda environment is present
    {
        conda activate ${REMOTE_CONDA_ENV}
    } || {
        conda create --name ${REMOTE_CONDA_ENV} python=3.9
        conda activate ${REMOTE_CONDA_ENV}
    }

    # Check if parsl is installed
    parsl_version=$(pip show parsl | grep Version | awk '{print $2}')
    if ! [[ ${parsl_version} == 1.1.0 ]]; then
        yes | pip install parsl==1.1.0
    fi
}
