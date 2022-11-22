#!/bin/bash
set -e

# Runs in the remote resource before running parsl
job_number=__job_number__

INSTALL_CONDA=__INSTALL_CONDA__
CONDA_DIR=__CONDA_DIR__
CONDA_ENV=__CONDA_ENV__
REMOTE_CONDA_YAML=__REMOTE_CONDA_YAML__

CREATE_SINGULARITY_CONTAINER=__CREATE_SINGULARITY_CONTAINER__
SINGULARITY_CONTAINER_PATH=__SINGULARITY_CONTAINER_PATH__
REMOTE_SINGULARITY_FILE=__REMOTE_SINGULARITY_FILE__

WORKER_PORT_1=__WORKER_PORT_1__
WORKER_PORT_2=__WORKER_PORT_2__

# WONT WORK IN EINSTEINMED:
USER_CONTAINER_HOST="usercontainer"

f_install_miniconda() {
    install_dir=$1
    echo "Installing Miniconda3-py39_4.9.2"
    conda_repo="https://repo.anaconda.com/miniconda/Miniconda3-py39_4.9.2-Linux-x86_64.sh"
    ID=$(date +%s)-${RANDOM} # This script may run at the same time!
    nohup wget ${conda_repo} -O /tmp/miniconda-${ID}.sh 2>&1 > /tmp/miniconda_wget-${ID}.out
    rm -rf ${install_dir}
    mkdir -p $(dirname ${install_dir})
    nohup bash /tmp/miniconda-${ID}.sh -b -p ${install_dir} 2>&1 > /tmp/miniconda_sh-${ID}.out
}

# INSTALL CONDA REQUIREMENTS
if [[ ${INSTALL_CONDA} == "true" ]]; then
    CONDA_SH="${CONDA_DIR}/etc/profile.d/conda.sh"
    # conda env export
    # Remove line starting with name, prefix and remove empty lines
    sed -i -e 's/name.*$//' -e 's/prefix.*$//' -e '/^$/d' ${REMOTE_CONDA_YAML}

    # Check if miniconda is installed
    {
        source ${CONDA_SH}
    } || {
        f_install_miniconda ${CONDA_DIR}
        source ${CONDA_SH}
    }
    # Make sure conda environment meets requirements:
    conda env update -n ${CONDA_ENV} -f ${REMOTE_CONDA_YAML} #--prune
fi

# CREATE SINGULARITY CONTAINER
if [[ ${CREATE_SINGULARITY_CONTAINER} == "true" ]]; then
    if ! [ -f "${SINGULARITY_CONTAINER_PATH}" ]; then
        mkdir -p $(dirname ${SINGULARITY_CONTAINER_PATH})
        sudo singularity build ${SINGULARITY_CONTAINER_PATH} ${REMOTE_SINGULARITY_FILE}
    fi
fi

# ESTABLISH TUNNELS
screen -d -m ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -L 0.0.0.0:${WORKER_PORT_1}:localhost:${WORKER_PORT_1} -L 0.0.0.0:${WORKER_PORT_2}:localhost:${WORKER_PORT_2} ${USER_CONTAINER_HOST}