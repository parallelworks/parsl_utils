#!/bin/bash
set -e

# Runs in the remote resource before running parsl
job_number=__job_number__

INSTALL_CONDA=__INSTALL_CONDA__
CONDA_DIR=__CONDA_DIR__
CONDA_ENV=__CONDA_ENV__
PW_CONDA_YAML=__LOCAL_CONDA_YAML__

CREATE_SINGULARITY_CONTAINER=__CREATE_SINGULARITY_CONTAINER__
SINGULARITY_CONTAINER_PATH=__SINGULARITY_CONTAINER_PATH__
PW_SINGULARITY_FILE=__LOCAL_SINGULARITY_FILE__

WORKER_PORT_1=__WORKER_PORT_1__
WORKER_PORT_2=__WORKER_PORT_2__

RUN_DIR=__RUN_DIR__
PARSL_UTILS_DIR=__PARSL_UTILS_DIR__
WORKFLOW_APPS_PY=__WORKFLOW_APPS_PY__



# WONT WORK IN EINSTEINMED:
USER_CONTAINER_HOST="usercontainer"

mkdir -p ${RUN_DIR}

# PRINT SCHEDULER TYPE (Needed to clean jobs)
# FIXME: This info should be included in the resource definition page
if ! [ -z $(which sbatch 2> /dev/null) ]; then
    echo "SCHEDULER_TYPE=SLURM"
elif ! [ -z $(which qsub 2> /dev/null) ]; then
    echo "SCHEDULER_TYPE=PBS"
fi

# COPY REQUIRED FILES FROM PW
if ! [ -z "${PARSL_UTILS_DIR}" ]; then
    rsync -avzq ${USER_CONTAINER_HOST}:${PARSL_UTILS_DIR} ${RUN_DIR}/
fi
if ! [ -z "${WORKFLOW_APPS_PY}" ]; then
    scp ${USER_CONTAINER_HOST}:${WORKFLOW_APPS_PY} ${RUN_DIR}/workflow_apps.py
fi

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
    CONDA_YAML=${RUN_DIR}/$(basename ${PW_CONDA_YAML})
    scp usercontainer:${PW_CONDA_YAML} ${CONDA_YAML}
    CONDA_SH="${CONDA_DIR}/etc/profile.d/conda.sh"
    # conda env export
    # Remove line starting with name, prefix and remove empty lines
    sed -i -e 's/name.*$//' -e 's/prefix.*$//' -e '/^$/d' ${CONDA_YAML}

    # Check if miniconda is installed
    {
        source ${CONDA_SH}
    } || {
        f_install_miniconda ${CONDA_DIR}
        source ${CONDA_SH}
    }
    # Make sure conda environment meets requirements:
    conda env update -n ${CONDA_ENV} -f ${CONDA_YAML} #--prune
fi

# CREATE SINGULARITY CONTAINER
if [[ ${CREATE_SINGULARITY_CONTAINER} == "true" ]]; then
    if ! [ -f "${SINGULARITY_CONTAINER_PATH}" ]; then
        mkdir -p $(dirname ${SINGULARITY_CONTAINER_PATH})
        SINGULARITY_FILE=${RUN_DIR}/$(basename ${PWDA_YAML})
        scp usercontainer:${PW_SINGULARITY_FILE} ${SINGULARITY_FILE}
        sudo singularity build ${SINGULARITY_CONTAINER_PATH} ${SINGULARITY_FILE}
    fi
fi

echo 
echo HOSTNAME: $HOSTNAME
echo 

# ESTABLISH TUNNELS
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -fN -L 0.0.0.0:${WORKER_PORT_1}:localhost:${WORKER_PORT_1} -L 0.0.0.0:${WORKER_PORT_2}:localhost:${WORKER_PORT_2} ${USER_CONTAINER_HOST} </dev/null &>/dev/null &
