#!/bin/bash
date

source /etc/profile.d/parallelworks.sh
source /etc/profile.d/parallelworks-env.sh
source /pw/.miniconda3/etc/profile.d/conda.sh
conda activate

python /swift-pw-bin/utils/input_form_resource_wrapper.py

source inputs.sh
export PU_DIR=parsl_utils #$(dirname $0)
source ${PU_DIR}/utils.sh
source ${PU_DIR}/set_up_conda_from_yaml.sh

# Support for kerberos
if [ -f "/pw/kerberos/source.env" ]; then
    source /pw/kerberos/source.env
fi

# Clear logs
export PARSL_LOGS=parsl_logs
rm -rf ${PARSL_LOGS}
mkdir -p ${PARSL_LOGS}

# Create kill script
echo "export PU_DIR=parsl_utils" > kill.sh
cat ${PU_DIR}/clean_resources.sh >> kill.sh
chmod +x kill.sh

echo; echo; echo "PREPARING USER WORKSPACE"
# Install conda requirements in local environment (user container)
# - Different workflows may have different local environments
# - Shared workflows may be missing their environment
# - Not required if running a notebook since the kernel would be changed to this environment
if [ -z "$pw_conda_dir" ] || [ -z "$pw_conda_env" ]; then
    echo "ERROR: Missing path to PW conda directory <${pw_conda_dir}> or PW conda environment name <${pw_conda_env}>"
    echo "       pw_conda_dir=/path/to/conda/"
    echo "       pw_conda_env=name-of-conda-environment"
    exit 1
fi

f_set_up_conda_from_yaml ${pw_conda_dir} ${pw_conda_env} ${pw_conda_yaml}
source ${pw_conda_dir}/etc/profile.d/conda.sh
conda activate ${pw_conda_env}

# Required even if empty because it is copied from the prepare_remote_resource.sh script
touch workflow_apps.py 

# PREPARE REMOTE RESOURCES
bash ${PU_DIR}/prepare_resources.sh

# CREATE MONITORING HTML FILE
# - Only supported for a single executor
number_of_executors=$(ls -d  resources/*/ | tr ' ' '\n' | sed "s|resources/||g" | sed "s|/||g" | wc -l)
if [ ${number_of_executors} -eq 1 ]; then
    cp ${PU_DIR}/service.json service.json
else
    echo "Parsl monitoring is not currently supported for more than one executor"
fi

echo; echo; echo "RUNNING PARSL"
python3 -u main.py ${wfargs}
ec=$?

# CLEAN REMOTE RESOURCES
bash kill.sh

echo Exit code ${ec}
exit ${ec}

