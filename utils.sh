#!/bin/bash

ssh_options="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

is_in_list () {
    list=$1
    x=$2
    [[ $list =~ (^|[[:space:]])$x($|[[:space:]]) ]] && echo true || echo false
}

find_available_port_pair () {
    port_1=55233
    port_2=$((port_1+1))

    # WARNING: Tunnel ports only shows up in netstat after running the parsl app. Otherwise they only show up on the head node.
    used_ports=$(netstat -tulpn | grep LISTEN | awk '{print $4}' | rev |cut -d':' -f1 | rev)

    while true; do

        if $(is_in_list "${used_ports}" ${port_1}) || $(is_in_list "${used_ports}" ${port_2}); then
            port_1=$((port_1+1))
            port_2=$((port_1+1))
        else
            echo ${port_1} ${port_2}
            break
        fi
    done
}



# Exports inputs in the format
# --a 1 --b 2 --c 3
# to:
# export a=1 b=2 c=3
f_read_cmd_args(){
    index=1
    args=""
    for arg in $@; do
	    prefix=$(echo "${arg}" | cut -c1-2)
	    if [[ ${prefix} == '--' ]]; then
	        pname=$(echo $@ | cut -d ' ' -f${index} | sed 's/--//g')
	        pval=$(echo $@ | cut -d ' ' -f$((index + 1)))
		    # To support empty inputs (--a 1 --b --c 3)
		    if [ ${pval:0:2} != "--" ]; then
	            echo "export ${pname}=${pval}" >> $(dirname $0)/env.sh
	            export "${pname}=${pval}"
		    fi
	    fi
        index=$((index+1))
    done
}


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

export_scheduler_type_from_resource_logs() {
    JOB_SCHEDULER_TYPE=$(cat ${POOL}/prepare_remote_resource.out | grep SCHEDULER_TYPE | cut -d'=' -f2)
    export JOB_SCHEDULER_TYPE=${JOB_SCHEDULER_TYPE}
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
