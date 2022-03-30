#!/bin/bash
set -e
CONDA_DIR=$1
CONDA_ENV=$2
CONDA_YAML=$3

CONDA_SH="${CONDA_DIR}/etc/profile.d/conda.sh"

# Remove line starting with name, prefix and remove empty lines
sed -i -e 's/name.*$//' -e 's/prefix.*$//' -e '/^$/d' ${CONDA_YAML}

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

{
    # Check if miniconda is installed
    {
        source ${CONDA_SH}
    } || {
        f_install_miniconda ${CONDA_DIR}
        source ${CONDA_SH}
    }

    # Make sure conda environment meets requirements:
    conda env update -n ${CONDA_ENV} -f ${CONDA_YAML} #--prune
}
