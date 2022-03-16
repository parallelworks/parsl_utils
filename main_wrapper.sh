#!/bin/bash
pudir=$(dirname $0)
. ${pudir}/utils.sh

# FIXME: This entire script should not be needed!
#        Users need to be able to decide which python environment is needed by their workflows!
# FIXME: Need to stage correct python environment to remote VM

ssh-keygen -f "/home/${PW_USER}/.ssh/known_hosts" -R ${HOST_IP}

LOCAL_CONDA_ENV="parsl_py39"
LOCAL_CONDA_SH="/pw/.miniconda3/etc/profile.d/conda.sh"

export REMOTE_CONDA_ENV="parsl_py39"
export REMOTE_CONDA_DIR="/contrib/${PW_USER}/miniconda3"
export REMOTE_CONDA_DIR="/tmp/${PW_USER}/miniconda3" # Used for testing!
export REMOTE_CONDA_SH="${REMOTE_CONDA_DIR}/etc/profile.d/conda.sh"

# Activate or install and activate conda environment in user container
bash ${pudir}/check_install_local.sh ${LOCAL_CONDA_SH} ${LOCAL_CONDA_ENV}
source ${LOCAL_CONDA_SH}
conda activate ${LOCAL_CONDA_ENV}

# Activate or install and activate conda environment in remote machine
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${HOST_IP} 'bash -s' < ${pudir}/check_install_remote.sh ${REMOTE_CONDA_DIR} ${REMOTE_CONDA_SH} ${REMOTE_CONDA_ENV}

# Establish SSH tunnel on available ports for parsl worker
port_pair=$(find_available_port_pair)
worker_port_1=$(echo ${port_pair} | cut -d' ' -f1)
worker_port_2=$(echo ${port_pair} | cut -d' ' -f2)
ssh_establish_tunnel_to_head_node ${worker_port_1} ${worker_port_2}

$@ --worker_port_1 ${worker_port_1} --worker_port_2 ${worker_port_2}
ec=$?
main_pid=$!

# Cancel tunnel on the remote side only
ssh_cancel_tunnel_to_head_node ${worker_port_1} ${worker_port_2}

# Kill all descendant processes
pkill -P ${main_pid}
pkill -P $$

# Make super sure python process dies:
python_pid=$(ps -x | grep  ${worker_port_1} | grep python | awk '{print $1}')
if ! [ -z "${python_pid}" ]; then
    echo "Killing remaining python process ${python_pid}"
    pkill -p ${python_pid}
    kill ${python_pid}
fi

exit ${ec}

