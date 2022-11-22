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

    openPort=$(curl -s "https://${PW_USER_HOST}/api/v2/usercontainer/getSingleOpenPort?minPort=${minPort}&maxPort=${maxPort}&key=${PW_API_KEY}")
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


# GET SLURM JOB NAMES
# FIXME: Need to test PBS + SLURM jobs!
get_slurm_job_names() {
    job_names=""
    if [ -d "runinfo" ]; then
        # GET LATEST RUNINFO DIRECTORY
        # - Example: 000 or 001
        run_info_000=$(ls -t runinfo/ | head -n1)
        if [ -d "runinfo/${run_info_000}/submit_scripts/" ]; then
            job_names=$(cat runinfo/${run_info_000}/submit_scripts/*.submit | grep job-name | cut -d'=' -f2)
        fi
    fi
    echo ${job_names} | tr ' ' '|'
}
