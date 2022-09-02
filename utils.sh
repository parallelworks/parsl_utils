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

ssh_establish_tunnel_to_head_node() {
    HOST_IP=$1
    HOST_USER=$2
    port_1=$3
    port_2=$4
    int_ip=$(hostname -I | cut -d' ' -f1 | sed "s/ //g")
    u=${PW_USER}
    s=${PW_USER_HOST}
    tunnel_cmd="sudo -E -u ${HOST_USER} bash -c \"setsid ssh ${ssh_options} -L 0.0.0.0:${port_1}:${int_ip}:${port_1} -L 0.0.0.0:${port_2}:${int_ip}:${port_2} ${u}@${s} -fNT\""
    echo ${tunnel_cmd} > establish_tunnel_to_head_node.sh
    ssh ${ssh_options} ${HOST_USER}@${HOST_IP} -t 'sudo bash -s' < establish_tunnel_to_head_node.sh
}

ssh_cancel_tunnel_to_head_node() {
    HOST_IP=$1
    HOST_USER=$2
    port_1=$3
    port_2=$4
    int_ip=$(hostname -I | cut -d' ' -f1 | sed "s/ //g")
    u=${PW_USER}
    s=${PW_USER_HOST}
    tunnel_cmd="sudo -E -u ${PW_USER} bash -c \"ssh ${ssh_options} -O cancel -L 0.0.0.0:${port_1}:${int_ip}:${port_1} -L 0.0.0.0:${port_2}:${int_ip}:${port_2} ${u}@${s} -fNT\""
    echo ${tunnel_cmd} > cancel_tunnel_to_head_node.sh
    ssh ${ssh_options} ${HOST_USER}@${HOST_IP} -t 'sudo bash -s' < cancel_tunnel_to_head_node.sh
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
