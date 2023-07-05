
set -e

f_install_miniconda() {
    install_dir=$1
    echo "Installing Miniconda3-py39_4.9.2"
    conda_repo="https://repo.anaconda.com/miniconda/Miniconda3-py39_4.9.2-Linux-x86_64.sh"
    ID=$(date +%s)-${RANDOM} # This script may run at the same time!
    nohup wget ${conda_repo} -O /tmp/miniconda-${ID}.sh 2>&1 > /tmp/miniconda_wget-${ID}.out
    rm -rf ${install_dir}
    mkdir -p $(dirname ${install_dir})
    nohup bash /tmp/miniconda-${ID}.sh -b -p ${install_dir} 2>&1 > /tmp/miniconda_sh-${ID}.out
}

echo 
echo HOSTNAME: $HOSTNAME
echo 

USER_CONTAINER_HOST="usercontainer"
PW_JOB_DIR=$(echo ${resource_jobdir} | sed 's/.*\(\/pw\/.*\)/\1/')
PARSL_UTILS_DIR=${PW_JOB_DIR}/parsl_utils
WORKFLOW_APPS_PY=${PW_JOB_DIR}/workflow_apps.py

mkdir -p ${resource_jobdir}

# COPY REQUIRED FILES FROM PW
# - These are required for parsl to start, therefore, parsl cannot transfer them
if ! [ -z "${PARSL_UTILS_DIR}" ]; then
    rsync -avzq ${USER_CONTAINER_HOST}:${PARSL_UTILS_DIR} ${resource_jobdir}
fi
if ! [ -z "${WORKFLOW_APPS_PY}" ]; then
    scp ${USER_CONTAINER_HOST}:${WORKFLOW_APPS_PY} ${resource_jobdir}/workflow_apps.py
fi

if ! [ -z "${worker_conda_yaml}" ]; then
    # Ensure path is absolute
    if ! [[ ${worker_conda_yaml} == /* ]]; then
        worker_conda_yaml="${PW_JOB_DIR}/${worker_conda_yaml}"
    fi
    # Path to worker_conda_yaml on the controller node
    WORKER_CONDA_YAML="${resource_jobdir}/${RANDOM}-$(basename ${worker_conda_yaml})"
    scp ${USER_CONTAINER_HOST}:${worker_conda_yaml} ${WORKER_CONDA_YAML}
fi


# SET UP WORKER CONDA FROM YAML
f_set_up_conda_from_yaml ${worker_conda_dir} ${worker_conda_env} ${WORKER_CONDA_YAML}


# ESTABLISH TUNNELS
PW_WORKER_PORT_1=$(echo ${resource_ports} | sed "s/___/,/g" | cut -d',' -f1)
PW_WORKER_PORT_2=$(echo ${resource_ports} | sed "s/___/,/g" | cut -d',' -f2)
if [ -z "${PW_WORKER_PORT_1}" ] || [ -z "${PW_WORKER_PORT_2}" ]; then
    echo "ERROR: Could not read PW worker ports <${PW_WORKER_PORT_1}> or <${PW_WORKER_PORT_2}> from resource ports <${resource_ports}>"
    exit 1
fi

# User ports don't work!
ssh -vvv -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -fN \
    -L 0.0.0.0:${PW_WORKER_PORT_1}:localhost:${PW_WORKER_PORT_1} \
    -L 0.0.0.0:${PW_WORKER_PORT_2}:localhost:${PW_WORKER_PORT_2} \
    ${USER_CONTAINER_HOST} &> ~/.ssh/parsl_utils.ssh.tunnel.log

echo Done!