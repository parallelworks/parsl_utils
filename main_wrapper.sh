#!/bin/bash
pudir=$(dirname $0)
. ${pudir}/utils.sh

# Clear logs
mkdir -p logs
rm -rf logs/*

# HANDLING ENVIRONMENT IN USER CONTAINER
LOCAL_CONDA_ENV="parsl_py39"
LOCAL_CONDA_SH="/pw/.miniconda3/etc/profile.d/conda.sh"

# Activate or install and activate conda environment in user container
bash ${pudir}/check_install_local.sh ${LOCAL_CONDA_SH} ${LOCAL_CONDA_ENV}
source ${LOCAL_CONDA_SH}
conda activate ${LOCAL_CONDA_ENV}

# CHECKING AND PREPRARING REMOTE EXECUTORS
# Complete configuration with executor ports and IP addresses
# - Get used ports
netstat -tulpn | grep LISTEN | awk '{print $4}' | rev |cut -d':' -f1 > used_ports.txt
python parsl_utils/complete_exec_conf.py executors.json used_ports.txt

# Convert JSON format to line by line format (see loop_exec_conf.py)
python parsl_utils/loop_exec_conf.py executors.json > exec_conf.export

while IFS= read -r exec_conf; do
    export ${exec_conf}

    # This is needed for SSHChannel in Parsl
    ssh-keygen -f "/home/${PW_USER}/.ssh/known_hosts" -R ${HOST_IP}

    # Handling remote environment
    export REMOTE_CONDA_SH="${REMOTE_CONDA_DIR}/etc/profile.d/conda.sh"
    # Activate or install and activate conda environment in remote machine
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${HOST_IP} 'bash -s' < ${pudir}/check_install_remote.sh ${REMOTE_CONDA_DIR} ${REMOTE_CONDA_SH} ${REMOTE_CONDA_ENV}

    # Establish SSH tunnel on available ports for parsl worker
    ssh_establish_tunnel_to_head_node ${HOST_IP} ${WORKER_PORT_1} ${WORKER_PORT_2}

done <   exec_conf.export

# Submit Parsl JOB:
echo; echo; echo
echo "RUNNING PARSL JOB"
echo
job_id=job-$(basename ${PWD})_date-$(date +%s)_random-${RANDOM} # To track and cancel the job
$@ --job_id ${job_id}
ec=$?
main_pid=$!
echo; echo; echo

# Cancel tunnel on the remote side only
while IFS= read -r exec_conf; do
    export ${exec_conf}
    ssh_cancel_tunnel_to_head_node ${HOST_IP} ${WORKER_PORT_1} ${WORKER_PORT_2}
done <   exec_conf.export

# Kill all descendant processes
pkill -P ${main_pid}
pkill -P $$

# Make super sure python process dies:
python_pid=$(ps -x | grep  ${job_id} | grep python | awk '{print $1}')
if ! [ -z "${python_pid}" ]; then
    echo
    echo "Killing remaining python process ${python_pid}"
    pkill -p ${python_pid}
    kill ${python_pid}
fi

exit ${ec}

