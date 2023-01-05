#!/bin/bash
pudir=$(dirname $0)
. ${pudir}/utils.sh

if [ -z $1 ]; then
    job_number=$(basename ${PWD}) #job-$(basename ${PWD})_date-$(date +%s)_random-${RANDOM}
else
    job_number=$1
fi

export_runinfo_dir
export_job_names # PBS_JOB_NAMES and SLURM_JOB_NAMES
# Cancel tunnel on the remote side only
while IFS= read -r exec_conf; do
    export ${exec_conf}
    export_scheduler_type_from_resource_logs

    if [[ ${JOB_SCHEDULER_TYPE} == "SLURM" ]]; then
        JOB_NAMES=${SLURM_JOB_NAMES}
    elif [[ ${JOB_SCHEDULER_TYPE} == "PBS" ]]; then
        JOB_NAMES=${PBS_JOB_NAMES}
    fi

    sed \
        -e "s|__job_number__|${job_number}|g" \
        -e "s|__WORKER_PORT_1__|${WORKER_PORT_1}|g" \
        -e "s|__JOB_SCHEDULER_TYPE__|${JOB_SCHEDULER_TYPE}|g" \
        -e "s/__JOB_NAMES__/${JOB_NAMES}/g" \
        ${pudir}/clean_remote_resource.sh > ${LABEL}/clean_remote_resource.sh

    ssh ${ssh_options} ${HOST_USER}@${HOST_IP} 'bash -s' < ${LABEL}/clean_remote_resource.sh &> ${LABEL}/clean_remote_resource.out
done <  exec_conf_completed.export
