#!/bin/bash
pudir=$(dirname $0)
. ${pudir}/utils.sh

if [ -z $1 ]; then
    job_id=$(basename ${PWD}) #job-$(basename ${PWD})_date-$(date +%s)_random-${RANDOM}
else
    job_id=$1
fi

ssh_options="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"


# CHECKING AND PREPRARING REMOTE EXECUTORS
# Complete configuration with executor ports and IP addresses
# - Get used ports
netstat -tulpn | grep LISTEN | awk '{print $4}' | rev |cut -d':' -f1 > used_ports.txt
python ${pudir}/complete_exec_conf.py executors.json used_ports.txt

# Convert JSON format to line by line format (see loop_exec_conf.py)
python ${pudir}/loop_exec_conf.py executors.json > exec_conf.export

# TODO: Consider using CSSH or PSSH here?
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
