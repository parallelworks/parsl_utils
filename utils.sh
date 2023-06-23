#!/bin/bash

export SSH_OPTIONS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

# get a unique open port
# - try end point
# - if not works --> use random
getOpenPort() {
    minPort=50000
    maxPort=50500

    openPort=$(curl -s "https://${PARSL_CLIENT_HOST}/api/v2/usercontainer/getSingleOpenPort?minPort=${minPort}&maxPort=${maxPort}&key=${PW_API_KEY}")
    # Check if openPort variable is a port
    if ! [[ ${openPort} =~ ^[0-9]+$ ]] ; then
        qty=1
        count=0
        for i in $(seq $minPort $maxPort | shuf); do
            out=$(netstat -aln | grep LISTEN | grep $i)
            if [[ "$out" == "" ]];then
                openPort=$(echo $i)
                (( ++ count ))
            fi
            if [[ "$count" == "$qty" ]];then
                break
            fi
        done
    fi
    echo $openPort
}


export_runinfo_dir() {
    if [ -d "runinfo" ]; then
        # GET LATEST RUNINFO DIRECTORY
        # - Example: 000 or 001
        export RUNINFO_DIR=$(ls -t runinfo/ | head -n1)
    else
       echo "ERROR: No runinfo directory found"
    fi
}


# GET SLURM JOB NAMES
# FIXME: Need to test PBS + SLURM jobs!
export_job_names() {
    job_names=""
    if [ -d "runinfo/${RUNINFO_DIR}/submit_scripts/" ]; then
        SLURM_JOB_NAMES=$(cat runinfo/${RUNINFO_DIR}/submit_scripts/*.submit | grep job-name | cut -d'=' -f2)
        PBS_JOB_NAMES=$(cat runinfo/${RUNINFO_DIR}/submit_scripts/*.submit | grep \#PBS | grep -- -N | cut -d' ' -f3)
    else
        echo "ERROR: directory runinfo/${RUNINFO_DIR}/submit_scripts/ not found"
    fi
    SLURM_JOB_NAMES=$(echo ${SLURM_JOB_NAMES} | tr ' ' '|')
    PBS_JOB_NAMES=$(echo ${PBS_JOB_NAMES} | tr ' ' '|')

    export SLURM_JOB_NAMES=${SLURM_JOB_NAMES}
    export PBS_JOB_NAMES=${PBS_JOB_NAMES}

}
