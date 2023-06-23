
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

f_set_up_conda_from_yaml() {
    CONDA_DIR=$1
    CONDA_ENV=$2
    CONDA_YAML=$3
    CONDA_SH="${CONDA_DIR}/etc/profile.d/conda.sh"
    # conda env export
    # Remove line starting with name, prefix and remove empty lines
    sed -i -e 's/name.*$//' -e 's/prefix.*$//' -e '/^$/d' ${CONDA_YAML}    
    
    if [ ! -d "${CONDA_DIR}" ]; then
        echo "Conda directory <${CONDA_DIR}> not found. Installing conda..."
        f_install_miniconda ${CONDA_DIR}
    fi
    
    echo "Sourcing Conda SH <${CONDA_SH}>"
    source ${CONDA_SH}
    echo "Activating Conda Environment <${CONDA_ENV}>"
    {
        conda activate ${CONDA_ENV}
    } || {
        echo "Conda environment <${CONDA_ENV}> not found. Installing conda environment from YAML file <${CONDA_YAML}>"
        conda env update -n ${CONDA_ENV} -q -f ${CONDA_YAML} #--prune
        {
            echo "Activating Conda Environment <${CONDA_ENV}> again"
            conda activate ${CONDA_ENV}
        } || {
            echo "ERROR: Conda environment <${CONDA_ENV}> not found. Exiting workflow"
            exit 1
        }
    }
}
