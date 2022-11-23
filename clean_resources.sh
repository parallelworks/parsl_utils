#!/bin/bash
pudir=$(dirname $0)
. ${pudir}/utils.sh

if [ -z $1 ]; then
    job_number=$(basename ${PWD}) #job-$(basename ${PWD})_date-$(date +%s)_random-${RANDOM}
else
    job_number=$1
fi

# Cancel tunnel on the remote side only
while IFS= read -r exec_conf; do
    export ${exec_conf}

    if [[ ${JOB_SCHEDULER_TYPE} == "SLURM" ]]; then
        JOB_NAMES=$(get_slurm_job_names)
    fi

    sed \
        -e "s|__job_number__|${job_number}|g" \
        -e "s|__WORKER_PORT_1__|${WORKER_PORT_1}|g" \
        -e "s|__JOB_SCHEDULER_TYPE__|${JOB_SCHEDULER_TYPE}|g" \
        -e "s/__JOB_NAMES__/${JOB_NAMES}|g" \
        ${pudir}/clean_remote_resource.sh > ${POOL}/clean_remote_resource.sh

    ssh ${ssh_options} ${HOST_USER}@${HOST_IP} 'bash -s' < ${POOL}/clean_remote_resource.sh &> ${POOL}/clean_remote_resource.out
done <  exec_conf_completed.export
