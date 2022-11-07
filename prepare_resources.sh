#!/bin/bash
set -x
pudir=$(dirname $0)
. ${pudir}/utils.sh

if [ -z $1 ]; then
    job_number=$(basename ${PWD}) #job-$(basename ${PWD})_date-$(date +%s)_random-${RANDOM}
else
    job_number=$1
fi

ssh_options="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"


# CHECKING AND PREPRARING REMOTE EXECUTORS

# Complete configuration with executor ports and IP addresses
# Convert JSON format to line by line format (see loop_exec_conf.py)
python ${pudir}/json2txt.py executors.json > exec_conf.export
rm -rf exec_conf_completed.export
while IFS= read -r exec_conf; do
    POOL=$(echo ${exec_conf} | tr ' ' '\n' | grep POOL | cut -d'=' -f2)
    # Get resource info from the API
    TYPE=$(${CONDA_PYTHON_EXE} ${pudir}/pool_api.py ${POOL} type)
    if [ -z "${TYPE}" ]; then
        echo "ERROR: Pool type not found - exiting the workflow"
        echo "${CONDA_PYTHON_EXE} ${pudir}/pool_api.py ${POOL} type"
        exit 1
    fi
    if [[ ${TYPE} == "slurmshv2" ]]; then
        WORKDIR=$(${CONDA_PYTHON_EXE} ${pudir}/pool_api.py ${POOL} workdir)
    else
        WORKDIR=${HOME}
    fi
    if [ -z ${WORKDIR} ]; then
        echo "ERROR: Pool workdir not found - exiting the workflow"
        echo ${CONDA_PYTHON_EXE} ${pudir}/pool_api.py ${POOL} workdir
        exit 1
    fi

    HOST_USER=$(echo ${exec_conf} | tr ' ' '\n' | grep HOST_USER | cut -d'=' -f2)
    WORKER_PORT_1=$(echo ${exec_conf} | tr ' ' '\n' | grep WORKER_PORT_1 | cut -d'=' -f2)
    WORKER_PORT_2=$(echo ${exec_conf} | tr ' ' '\n' | grep WORKER_PORT_2 | cut -d'=' -f2)

    if [ -z ${WORKER_PORT_1} ]; then
        exec_conf="${exec_conf} WORKER_PORT_1=$(getOpenPort)"
        # Give enough time to checkout port
        sleep 2
    fi

    if [ -z ${WORKER_PORT_2} ]; then
        exec_conf="${exec_conf} WORKER_PORT_2=$(getOpenPort)"
    fi

    if [ -z ${HOST_IP} ]; then
        HOST_IP=$(${CONDA_PYTHON_EXE} /swift-pw-bin/utils/cluster-ip-api-wrapper.py ${POOL}.clusters.pw)
        # When the ip-api-wrapper times out it returns the pool name
        if [ -z ${HOST_IP} ] || [[ "${HOST_IP}" == "${POOL}" ]]; then
            echo "ERROR: Host IP <${HOST_IP}> for pool <${POOL}> wast not found! Exiting workflow"
            exit 1
        fi
        # Sometimes host_ip as returned by the API is in the format USER@IP and sometimes it is not.
        if [[ ${HOST_IP} == *"@"* ]]; then
            HOST_USER=$(echo ${HOST_IP} | cut -d'@' -f1)
            HOST_IP=$(echo ${HOST_IP} | cut -d'@' -f2)
        fi
        exec_conf="${exec_conf} HOST_IP=${HOST_IP}"
    fi

    if [ -z ${HOST_USER} ]; then
        exec_conf="${exec_conf} HOST_USER=${PW_USER}"
        HOST_USER=${PW_USER}
    fi

    # Address for SlurmProvider compute nodes to reach the interchange:
    # This is the internal IP address of the controller node
    ADDRESS=$(ssh -o StrictHostKeyChecking=no ${HOST_USER}@${HOST_IP} hostname -I | cut -d' ' -f1)
    exec_conf="${exec_conf} ADDRESS=${ADDRESS}"

    echo ${exec_conf} | sed "s|__poolworkdir__|${WORKDIR}|g"  >> exec_conf_completed.export
    unset HOST_IP WORKER_PORT_2 WORKER_PORT_1 HOST_USER

done <  exec_conf.export

# Convert executor configuration to JSON
python ${pudir}/json2txt.py exec_conf_completed.export > executors.json


# TODO: Consider using CSSH or PSSH here?
while IFS= read -r exec_conf; do
    export ${exec_conf}

    # This is needed for SSHChannel in Parsl
    ssh-keygen -f "/home/${PW_USER}/.ssh/known_hosts" -R ${HOST_IP}

    # Install conda requirements if not found in remote executors
    if [[ ${INSTALL_CONDA} == true ]]; then
        REMOTE_CONDA_YAML=/tmp/${job_number}_conda.yaml
        scp ${ssh_options} ${LOCAL_CONDA_YAML} ${HOST_USER}@${HOST_IP}:${REMOTE_CONDA_YAML}
        ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${HOST_USER}@${HOST_IP} 'bash -s' < ${pudir}/install_conda_requirements.sh ${CONDA_DIR} ${CONDA_ENV} ${REMOTE_CONDA_YAML} &> logs/${LABEL}_install_conda_requirements.out
    fi

    # Create singularity container if not found in remote executors
    if [[ ${CREATE_SINGULARITY_CONTAINER} == true ]]; then
        REMOTE_SINGULARITY_FILE=/tmp/${job_number}_singularity.file
        scp ${ssh_options} ${LOCAL_SINGULARITY_FILE} ${HOST_USER}@${HOST_IP}:${REMOTE_SINGULARITY_FILE}
        ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${HOST_USER}@${HOST_IP} 'bash -s' < ${pudir}/create_singularity_container.sh ${SINGULARITY_CONTAINER_PATH} ${REMOTE_SINGULARITY_FILE} &> logs/${LABEL}_create_singularity_container.out
    fi

    # Establish SSH tunnel on available ports for parsl worker
    ssh_establish_tunnel_to_head_node ${HOST_IP} ${HOST_USER} ${WORKER_PORT_1} ${WORKER_PORT_2}

done < exec_conf_completed.export
