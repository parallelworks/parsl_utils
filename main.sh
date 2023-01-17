#!/bin/bash
set -x
date

pudir=parsl_utils #$(dirname $0)
. ${pudir}/utils.sh

# Copy the kill file
cp parsl_utils/kill.sh ./

# Clear logs
mkdir -p logs
rm -rf logs/*

# replace the executors file if an override exists
if [ -f "executors.override.json" ];then
    cp executors.override.json executors.json
fi

# check if executors file exists
if [ ! -f executors.json ]; then
    echo "ERROR: File executors.json is missing; workflow does not know where to run!"
    echo "This missing file should have at least the following information:"
    echo "{"
    echo " \"myexecutor_1\": {"
    echo "  \"POOL\": \"pool_name\","
    echo "  \"HOST_USER\": \"user_name\","
    echo "  \"HOST_IP\": \"ip_address\","
    echo "  \"RUN_DIR\": \"/path/to/rundir\","
    echo "  \"NODES\": integer_number_nodes,"
    echo "  \"PARTITION\": \"SLURM_partition\","
    echo "  \"NTASKS_PER_NODE\": integer_tasks_per_node,"
    echo "  \"WALLTIME\": \"01:00:00\","
    echo "  \"CONDA_ENV\": \"conda_environment_name\","
    echo "  \"CONDA_DIR\": \"/path/to/condadir\","
    echo "  \"WORKER_LOGDIR_ROOT\": \"/shared/centos/\","
    echo "  \"SSH_CHANNEL_SCRIPT_DIR\": \"/shared/centos/\","
    echo "  \"CORES_PER_WORKER\": integer_or_fractional_number_cores,"
    echo "  \"INSTALL_CONDA\": \"<true|false>\","
    echo "  \"LOCAL_CONDA_YAML\": \"./requirements/conda_env_remote.yaml\""
    echo " },"
    echo " \"myexecutor_2\": {...},"
    echo " ..."
    echo "}"
    exit 1
fi

# Use a job_number to:
# 1. Track / cancel job
# 2. Stage temporary files
job_number=$(basename ${PWD})   #job-${job_num}_date-$(date +%s)_random-${RANDOM}
wfargs="$@ --job_number ${job_number}"

# Replace special placeholders:
wfargs="$(echo ${wfargs} | sed "s|__job_number__|${job_number}|g")"
sed -i "s|__job_number__|${job_number}|g" executors.json
sed -i "s|__job_number__|${job_number}|g" kill.sh

#########################################
# CHECKING AND PREPARING USER CONTAINER #
#########################################
# - Install conda requirements in local environment (user container)
# - Different workflows may have different local environments
# - Shared workflows may be missing their environment
# - Not required if running a notebook since the kernel would be changed to this environment
if [ ! -f local.conf ]; then
    echo "ERROR: Need to specify a local configuration file with at least the following variables:"
    echo CONDA_DIR=/path/to/conda/
    echo CONDA_ENV=name-of-conda-environment
    exit 1
fi

source local.conf
if [[ ${INSTALL_CONDA} == true ]]; then
    bash ${pudir}/install_conda_requirements.sh ${CONDA_DIR} ${CONDA_ENV} ${LOCAL_CONDA_YAML} &> logs/local_install_conda_requirements.out
fi
# Activate or install and activate conda environment in user container
source ${CONDA_DIR}/etc/profile.d/conda.sh
conda activate ${CONDA_ENV}

############################################
# CHECKING AND PREPRARING REMOTE EXECUTORS #
############################################
bash ${pudir}/prepare_resources.sh ${job_number} &> logs/prepare_resources.out

###############################
# CREATE MONITORING HTML FILE #
###############################
sed "s/__JOBNUM__/${job_number}/g" ${pudir}/service.html.template > service.html

####################
# SUBMIT PARSL JOB #
####################
echo; echo; echo
echo "RUNNING PARSL JOB"
echo "python -u main.py ${wfargs}"
# To track and cancel the job
python -u main.py ${wfargs}
ec=$?
main_pid=$!
echo; echo; echo

##########################
# CLEAN REMOTE EXECUTORS #
##########################
bash kill.sh

##########################
# Exit                   #
##########################
echo Exit code ${ec}
exit ${ec}
