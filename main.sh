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

####################
# SUBMIT PARSL JOB #
####################
echo; echo; echo
echo "RUNNING PARSL JOB"
echo "python main.py ${wfargs}"
# To track and cancel the job
python main.py ${wfargs}
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