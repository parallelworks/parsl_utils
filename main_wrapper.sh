#!/bin/bash
pudir=$(dirname $0)
. ${pudir}/utils.sh

# Clear logs
mkdir -p logs
rm -rf logs/*

# Use a job_id to:
# 1. Track / cancel job
# 2. Stage temporary files
job_id=$(basename ${PWD})   #job-${job_num}_date-$(date +%s)_random-${RANDOM}

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
bash ${pudir}/prepare_resources.sh ${job_id} &> logs/prepare_resources.out

####################
# SUBMIT PARSL JOB #
####################
echo; echo; echo
echo "RUNNING PARSL JOB"
echo
# To track and cancel the job
$@ --job_id ${job_id}
ec=$?
main_pid=$!
echo; echo; echo

##########################
# CLEAN REMOTE EXECUTORS #
##########################
bash ${pudir}/clean_resources.sh &> logs/clean_resources.out

#########################
# CLEAN LOCAL PROCESSES #
#########################

# Make super sure python process dies:
# - Also the monitoring is killed here!
python_pid=$(ps -x | grep  ${job_id} | grep python | awk '{print $1}')
if ! [ -z "${python_pid}" ]; then
    echo "Killing remaining python process ${python_pid}" >> logs/killed_pids.log
    kill ${python_pid}
fi

echo Exit code ${ec}
exit ${ec}