#!/bin/bash
set -x
pudir=$(dirname $0)
. ${pudir}/utils.sh

slurmpooltypes="gclusterv2 pclusterv2 azclusterv2 awsclusterv2 slurmshv2"
pbspooltypes="pbsshv2"


if [ -z $1 ]; then
    job_number=$(basename ${PWD}) #job-$(basename ${PWD})_date-$(date +%s)_random-${RANDOM}
else
    job_number=$1
fi

ssh_options="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
kill_sh=/pw/jobs/${job_number}/kill.sh

# CHECKING AND PREPRARING REMOTE EXECUTORS
# FIXME: SANITY CHECKS:


# Complete configuration with executor ports and IP addresses
# Convert JSON format to line by line format (see loop_exec_conf.py)
python ${pudir}/json2txt.py executors.json > exec_conf.export
rm -rf exec_conf_completed.export
while IFS= read -r exec_conf; do
    export ${exec_conf}
    echo "Completeting configuration for executor <${LABEL}>"

    # Get resource info from the API
    TYPE=$(${CONDA_PYTHON_EXE} ${pudir}/pool_api.py ${POOL} type)
    if [ -z "${TYPE}" ]; then
        echo "ERROR: Pool type not found - exiting the workflow"
        echo "${CONDA_PYTHON_EXE} ${pudir}/pool_api.py ${POOL} type"
        bash ${kill_sh}
        exit 1
    fi
    exec_conf="${exec_conf} POOL_TYPE=${TYPE}"

    if [[ " ${slurmpooltypes} " == *" ${TYPE} "* ]]; then
        JOB_SCHEDULER_TYPE=SLURM
    elif [[ " ${pbspooltypes} " == *" ${TYPE} "* ]]; then
        JOB_SCHEDULER_TYPE=PBS
    else
        echo "ERROR: Pool type <${TYPE}> not present in SLURM types <${slurmpooltypes}> or PBS types <${pbspooltypes}>"
        exit 1
    fi
    exec_conf="${exec_conf} JOB_SCHEDULER_TYPE=${JOB_SCHEDULER_TYPE}"

    STATUS=$(${CONDA_PYTHON_EXE} ${pudir}/pool_api.py ${POOL} status)
    if [[ ${STATUS} == "off" ]]; then
        if [[ ${REQUIRED} == "false" ]]; then
            echo "ERROR: Pool status is off - continuing to next pool"
            continue
        else
            echo "ERROR: Pool status is off and this pool is required - exiting workflow"
            bash ${kill_sh}
            exit 1
        fi
    fi

    if [[ ${TYPE} == "slurmshv2" ]]; then
        WORKDIR=$(${CONDA_PYTHON_EXE} ${pudir}/pool_api.py ${POOL} workdir)
    else
        WORKDIR=${HOME}
    fi

    if [ -z ${WORKDIR} ]; then
        echo "ERROR: Pool workdir not found - exiting the workflow"
        echo ${CONDA_PYTHON_EXE} ${pudir}/pool_api.py ${POOL} workdir
        bash ${kill_sh}
        exit 1
    fi

    if [ -z ${RUN_DIR} ]; then
        RUN_DIR=${WORKDIR}/pw/jobs/${job_number}
        exec_conf="${exec_conf} RUN_DIR=${RUN_DIR}"
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
            echo "ERROR: Host IP <${HOST_IP}> for pool <${POOL}> wast not found! Exiting workflow"\
            bash ${kill_sh}
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
        HOST_USER=${PW_USER}
    fi
    exec_conf="${exec_conf} HOST_USER=${HOST_USER}"

    # Address for SlurmProvider compute nodes to reach the interchange:
    # This is the internal IP address of the controller node
    ADDRESS=$(ssh -o StrictHostKeyChecking=no ${HOST_USER}@${HOST_IP} hostname -I < /dev/null | cut -d' ' -f1)
    exec_conf="${exec_conf} ADDRESS=${ADDRESS}"

    echo ${exec_conf} | sed "s|__POOLWORKDIR__|${WORKDIR}|g" | sed "s|__USER__|${PW_USER}|g"  >> exec_conf_completed.export
    unset HOST_IP WORKER_PORT_2 WORKER_PORT_1 HOST_USER RUN_DIR

done <  exec_conf.export
# Make sure exec_conf_completed.export ends in new line
echo >>  exec_conf_completed.export

# Convert executor configuration to JSON
cp executors.json executors.orig.json
python ${pudir}/json2txt.py exec_conf_completed.export > executors.json

# TODO: Consider using CSSH or PSSH here?
while IFS= read -r exec_conf; do
    if [ -z "$exec_conf" ]; then
        continue
    fi
    
    export ${exec_conf}
    
    echo "Preparing executor <${LABEL}>"
    mkdir -p ${LABEL}

    # This is needed for SSHChannel in Parsl
    ssh-keygen -f "/home/${PW_USER}/.ssh/known_hosts" -R ${HOST_IP}

    # Make sure run directory exists
    ssh ${ssh_options} ${HOST_USER}@${HOST_IP} mkdir -p ${RUN_DIR}

    # Copy conda environment definition
    if [[ ${INSTALL_CONDA} == "true" ]]; then
        REMOTE_CONDA_YAML=${RUN_DIR}/$(basename ${LOCAL_CONDA_YAML})
        scp ${ssh_options} ${LOCAL_CONDA_YAML} ${HOST_USER}@${HOST_IP}:${REMOTE_CONDA_YAML}
    fi

    # Copy singularity container definition
    if [[ ${CREATE_SINGULARITY_CONTAINER} == "true" ]]; then
        REMOTE_SINGULARITY_FILE=${RUN_DIR}/$(basename ${LOCAL_SINGULARITY_FILE})
        scp ${ssh_options} ${LOCAL_SINGULARITY_FILE} ${HOST_USER}@${HOST_IP}:${REMOTE_SINGULARITY_FILE}
    fi

    # Create bootstrap script
    sed \
        -e "s|__job_number__|${job_number}|g" \
        -e "s|__INSTALL_CONDA__|${INSTALL_CONDA}|g" \
        -e "s|__CONDA_DIR__|${CONDA_DIR}|g" \
        -e "s|__CONDA_ENV__|${CONDA_ENV}|g" \
        -e "s|__REMOTE_CONDA_YAML__|${REMOTE_CONDA_YAML}|g" \
        -e "s|__CREATE_SINGULARITY_CONTAINER__|${CREATE_SINGULARITY_CONTAINER}|g" \
        -e "s|__SINGULARITY_CONTAINER_PATH__|${SINGULARITY_CONTAINER_PATH}|g" \
        -e "s|__REMOTE_SINGULARITY_FILE__|${REMOTE_SINGULARITY_FILE}|g" \
        -e "s|__WORKER_PORT_1__|${WORKER_PORT_1}|g" \
        -e "s|__WORKER_PORT_2__|${WORKER_PORT_2}|g" \
        ${pudir}/prepare_remote_resource.sh > ${LABEL}/prepare_remote_resource.sh

    # Prepare remote resource:
    ssh ${ssh_options} ${HOST_USER}@${HOST_IP} 'bash -s' < ${LABEL}/prepare_remote_resource.sh &> ${LABEL}/prepare_remote_resource.out

    unset INSTALL_CONDA REMOTE_CONDA_YAML CREATE_SINGULARITY_CONTAINER REMOTE_SINGULARITY_FILE

done < exec_conf_completed.export
