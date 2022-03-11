#!/bin/bash
pudir=$(dirname $0)
. ${pudir}/utils.sh

# FIXME: This entire script should not be needed!
#        Users need to be able to decide which python environment is needed by their workflows!
# FIXME: Need to stage correct python environment to remote VM

# TODO: Move tunnel creation/destruction here

local_conda_env="parsl_py39"
local_conda_sh="/pw/.miniconda3/etc/profile.d/conda.sh"

export REMOTE_CONDA_ENV="parsl_py39"
export REMOTE_CONDA_SH="/contrib/${PW_USER}/miniconda3/etc/profile.d/conda.sh"


# Activate conda environment in user container
{
    source ${local_conda_sh}
    conda activate ${local_conda_env}
} || {
    "Conda environment ${local_conda_env} not found"
    exit 0
}

# Check remote conda environment
echo "source ${REMOTE_CONDA_SH}" > check_remote_conda.sh
echo "conda activate ${REMOTE_CONDA_ENV}" >> check_remote_conda.sh
{
    ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${HOST_IP} 'bash -s' < check_remote_conda.sh
} || {
    echo Remote conda environment not found:
    echo     CONDA SH:  ${REMOTE_CONDA_SH}
    echo     CONDA ENV: ${REMOTE_CONDA_ENV}
    echo See install instructions below:
    echo "Install miniconda under /contrib/${PW_USER}/miniconda3 https://docs.conda.io/en/latest/miniconda.html"
    echo "Run: conda create --name parsl_py39 python=3.9; pip install parsl==1.1.0"
    exit 0
}


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
    pkill -p ${python_pid}
    kill ${python_pid}
fi

exit ${ec}

