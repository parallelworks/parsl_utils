#!/bin/bash
pudir=$(dirname $0)
. ${pudir}/utils.sh

# Clear logs
mkdir -p logs
rm -rf logs/*

# Use a job_id to:
# 1. Track / cancel job
# 2. Stage temporary files
job_id=job-$(basename ${PWD})_date-$(date +%s)_random-${RANDOM}

ssh_options="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

# CHECKING AND PREPARING USER CONTAINER
# Install conda requirements in local environment (user container)
# Different workflows may have different local environments
# Shared workflows may be missing their environment
if [ ! -f local.conf ]; then
    echo "ERROR: Need to specify a local configuration file with at least the following variables:"
    echo CONDA_DIR=/path/to/conda/
    echo CONDA_ENV=name-of-conda-environment
    exit 1
fi

source local.conf
if [[ ${INSTALL_CONDA} == true ]]; then
    bash ${pudir}/install_conda_requirements.sh ${CONDA_DIR} ${CONDA_ENV} ${LOCAL_CONDA_YAML} &> logs/local_install_conda_requirements.out
fi
# Activate or install and activate conda environment in user container
source ${CONDA_DIR}/etc/profile.d/conda.sh
conda activate ${CONDA_ENV}

# CHECKING AND PREPRARING REMOTE EXECUTORS
# Complete configuration with executor ports and IP addresses
# - Get used ports
netstat -tulpn | grep LISTEN | awk '{print $4}' | rev |cut -d':' -f1 > used_ports.txt
python parsl_utils/complete_exec_conf.py executors.json used_ports.txt

# Convert JSON format to line by line format (see loop_exec_conf.py)
python parsl_utils/loop_exec_conf.py executors.json > exec_conf.export

while IFS= read -r exec_conf; do
    export ${exec_conf}

    # This is needed for SSHChannel in Parsl
    ssh-keygen -f "/home/${PW_USER}/.ssh/known_hosts" -R ${HOST_IP}

    # Install conda requirements if not found in remote executors
    if [[ ${INSTALL_CONDA} == true ]]; then
        REMOTE_CONDA_YAML=/tmp/${job_id}_conda.yaml
        scp ${ssh_options} ${LOCAL_CONDA_YAML} ${HOST_IP}:${REMOTE_CONDA_YAML}
        ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${HOST_IP} 'bash -s' < ${pudir}/install_conda_requirements.sh ${CONDA_DIR} ${CONDA_ENV} ${REMOTE_CONDA_YAML} &> logs/${LABEL}_install_conda_requirements.out
    fi

    # Create singularity container if not found in remote executors
    if [[ ${CREATE_SINGULARITY_CONTAINER} == true ]]; then
        REMOTE_SINGULARITY_FILE=/tmp/${job_id}_singularity.file
        scp ${ssh_options} ${LOCAL_SINGULARITY_FILE} ${HOST_IP}:${REMOTE_SINGULARITY_FILE}
        ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${HOST_IP} 'bash -s' < ${pudir}/create_singularity_container.sh ${SINGULARITY_CONTAINER_PATH} ${REMOTE_SINGULARITY_FILE} &> logs/${LABEL}_create_singularity_container.out
    fi

    # Establish SSH tunnel on available ports for parsl worker
    ssh_establish_tunnel_to_head_node ${HOST_IP} ${WORKER_PORT_1} ${WORKER_PORT_2}

done <   exec_conf.export

# Submit Parsl JOB:
echo; echo; echo
echo "RUNNING PARSL JOB"
echo
# To track and cancel the job
$@ --job_id ${job_id}
ec=$?
main_pid=$!
echo; echo; echo

# Cancel tunnel on the remote side only
while IFS= read -r exec_conf; do
    export ${exec_conf}
    ssh_cancel_tunnel_to_head_node ${HOST_IP} ${WORKER_PORT_1} ${WORKER_PORT_2}
done <   exec_conf.export

# Kill all descendant processes
pkill -P ${main_pid}
pkill -P $$

# Make super sure python process dies:
python_pid=$(ps -x | grep  ${job_id} | grep python | awk '{print $1}')
if ! [ -z "${python_pid}" ]; then
    echo
    echo "Killing remaining python process ${python_pid}"
    pkill -p ${python_pid}
    kill ${python_pid}
fi

exit ${ec}

