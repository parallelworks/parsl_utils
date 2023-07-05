#!/bin/bash
echo; echo; echo "CLEANING REMOTE RESOURCES"
source ${PU_DIR}/utils.sh
export_runinfo_dir
export_job_names
resource_labels=$(ls -d  resources/*/ | tr ' ' '\n' | sed "s|resources/||g" | sed "s|/||g")
for label in ${resource_labels}; do
    echo; echo "CLEANING RESOURCE ${label}"
    source resources/${label}/inputs.sh
    clean_resource_sh="resources/${label}/clean_remote_resource.sh"
    echo "#!/bin/bash" > ${clean_resource_sh}
    cat resources/${label}/inputs.sh >> ${clean_resource_sh}
    if [[ ${jobschedulertype} == "SLURM" ]]; then
        JOB_NAMES=${SLURM_JOB_NAMES}
    elif [[ ${jobschedulertype} == "PBS" ]]; then
        JOB_NAMES=${PBS_JOB_NAMES}
    fi
    echo "export JOB_NAMES=${JOB_NAMES}" >> ${clean_resource_sh}
    cat ${PU_DIR}/clean_remote_resource.sh >> ${clean_resource_sh}
    ssh ${SSH_OPTIONS} ${resource_publicIp} 'bash -s' < ${clean_resource_sh}
done