

echo "Cleaning resource ${HOSTNAME}"

if [[ "${jobschedulertype}" == "SLURM" ]]; then
    # KILL SLURM JOBS
    for JOB_NAME in $(echo ${JOB_NAMES} | tr '|' ' '); do
        JOB_ID=$(squeue --name ${JOB_NAME}  -h | awk '{print $1}')
        # Note that these are all the parsl jobs in runinfo/000/submit_scripts and may not be
        # running in this particular resource.
        if ! [ -z ${JOB_ID} ]; then
            echo "scancel ${JOB_ID}"
            scancel ${JOB_ID}
        fi
    done
fi

if [[ "${jobschedulertype}" == "PBS" ]]; then
    # KILL PBS JOBS
    for JOB_NAME in $(echo ${JOB_NAMES} | tr '|' ' '); do
        # qstat abreviates jobnames...
        JOB_ID=$(qstat | grep ${JOB_NAME: -13} | awk '{print $1}')
        # Note that these are all the parsl jobs in runinfo/000/submit_scripts and may not be
        # running in this particular resource.
        if ! [ -z ${JOB_ID} ]; then
            echo "qdel ${JOB_ID}"
            qdel ${JOB_ID}
        fi
    done
fi


# Kill tunnel processes
PW_WORKER_PORT_1=$(echo ${resource_ports} | sed "s/___/,/g" | cut -d',' -f1)
kill $(ps -x | grep ssh | grep ${PW_WORKER_PORT_1} | awk '{print $1}')

echo Done!