#!/bin/bash
# Runs in the remote resource after running parsl
set -x
job_number=__job_number__
WORKER_PORT_1=__WORKER_PORT_1__
JOB_SCHEDULER_TYPE=__JOB_SCHEDULER_TYPE__
JOB_NAMES="__JOB_NAMES__"

echo "Cleaning resource ${HOSTNAME}"

if [[ "${JOB_SCHEDULER_TYPE}" == "SLURM" ]]; then
    # KILL SLURM JOBS
    for JOB_NAME in $(echo ${JOB_NAMES} | tr '|' ' '); do
        JOB_ID=$(squeue --name ${JOB_NAME}  -h | awk '{print $1}')
        # Note that these are all the parsl jobs in runinfo/000/submit_scripts and may not be
        # running in this particular resource.
        if ! [ -z ${JOB_ID} ]; then
            scancel ${JOB_ID}
        fi
    done
fi

if [[ "${JOB_SCHEDULER_TYPE}" == "PBS" ]]; then
    # KILL SLURM JOBS
    for JOB_NAME in $(echo ${JOB_NAMES} | tr '|' ' '); do
        # qstat abreviates jobnames...
        JOB_ID=$(qstat | grep ${JOB_NAME: -13} | awk '{print $1}')
        # Note that these are all the parsl jobs in runinfo/000/submit_scripts and may not be
        # running in this particular resource.
        if ! [ -z ${JOB_ID} ]; then
            qdel ${JOB_ID}
        fi
    done
fi



# Kill tunnel processes
kill $(ps -x | grep ssh | grep ${WORKER_PORT_1} | awk '{print $1}')
