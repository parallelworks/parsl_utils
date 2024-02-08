
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

# This script always runs in the controller node so we cannot use the 
# resource_ssh_usercontainer_options environment variable which may
# be set to run in the compute node
if [ -f "${resource_workdir}/pw/.pw/config" ]; then
    RESOURCE_SSH_USERCONTAINER_OPTIONS="-F ${resource_workdir}/pw/.pw/config -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
else 
    RESOURCE_SSH_USERCONTAINER_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
fi


copy_pw_job_file() {
    pw_path=$1
    # Ensure path is absolute
    if ! [[ ${pw_path} == /* ]]; then
        pw_path="${PW_JOB_DIR}/${pw_path}"
    fi
    # Path to pw_path on the controller node
    worker_path="${resource_jobdir}/${RANDOM}-$(basename ${pw_path})"
    rsync -avzq  -e "ssh ${RESOURCE_SSH_USERCONTAINER_OPTIONS}" ${USER_CONTAINER_HOST}:${pw_path} ${worker_path}
    echo ${worker_path}
}

mkdir -p ${resource_jobdir}

# COPY REQUIRED FILES FROM PW
# - These are required for parsl to start, therefore, parsl cannot transfer them
if ! [ -z "${PARSL_UTILS_DIR}" ]; then
    rsync -avzq ${USER_CONTAINER_HOST}:${PARSL_UTILS_DIR} ${resource_jobdir}
fi
if ! [ -z "${WORKFLOW_APPS_PY}" ]; then
    scp ${USER_CONTAINER_HOST}:${WORKFLOW_APPS_PY} ${resource_jobdir}/workflow_apps.py
fi

# SET UP WORKER CONDA FROM YAML
worker_path=$(copy_pw_job_file ${worker_conda_yaml})
f_set_up_conda_from_yaml ${worker_conda_dir} ${worker_conda_env} ${worker_path}

# INSTALL OTHER YAML FILES
env | grep bootstrap_conda_yaml | while IFS= read -r line; do
    # Do something with each line, for example, printing it
    pw_path=$(echo "${line}" | cut -d'=' -f2)
    worker_path=$(copy_pw_job_file ${pw_path})
    conda_env=$(echo "${line}" | cut -d'=' -f1 | sed "s/_bootstrap_conda_yaml//g")
    f_set_up_conda_from_yaml ${worker_conda_dir} ${conda_env} ${worker_path}
done


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