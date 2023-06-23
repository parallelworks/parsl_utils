#!/bin/bash
echo; echo; echo "PREPARING REMOTE RESOURCES"
source ${PU_DIR}/utils.sh
resource_labels=$(ls -d  resources/*/ | tr ' ' '\n' | sed "s|resources/||g" | sed "s|/||g")
# TODO: Consider using CSSH or PSSH here?
for label in ${resource_labels}; do
    echo; echo "PREPARING RESOURCE ${label}"
    source resources/${label}/inputs.sh
    prepare_resource_sh="resources/${label}/prepare_remote_resource.sh"
    echo "#!/bin/bash" > ${prepare_resource_sh}
    cat resources/${label}/inputs.sh >> ${prepare_resource_sh}
    cat ${PU_DIR}/set_up_conda_from_yaml.sh >> ${prepare_resource_sh}
    cat ${PU_DIR}/prepare_remote_resource.sh >> ${prepare_resource_sh}
    ssh ${SSH_OPTIONS} ${resource_publicIp} 'bash -s' < ${prepare_resource_sh}
done