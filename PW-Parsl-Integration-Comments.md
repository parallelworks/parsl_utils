# Native Parsl Utils
This repo contains helper wrapper scripts for running native/official Parsl in cluster pools on the PW platform. These scripts are considered temporary ad-hoc code that should be better integrated on the platform and were develeped to temporarily address the issues below:

### 1. Conda Environment
Workflows needs to run in a specific conda environment which needs to be installed and accessible on the user container (local) and on the head node of the cluster (remote). Both conda environments need to be compatible: same Parsl and Python versions. 

The wrapper scripts install the local and remote conda environments as specified in the `local.conf` and `executors.json` files, respectively. These conda environments are defined using YAML files. Be careful with the name of the conda environment as you may overwrite an existing environment. Use the following keywords to controll the conda environment:
1. CONDA_ENV: Name of the conda environment to activate on the local (local.conf) or remote (executors.json) hosts.
2. CONDA_DIR: Path to the conda install directory.
3. INSTALL_CONDA: Can take the values true or false to install (bootstrap) the conda environment (true) or only activate it (false).
4. LOCAL_CONDA_YAML: Path to the YAML file defining the conda environment (`conda env export`) to install it if INSTALL_CONDA=true

##### Sample local.conf
```
CONDA_ENV=parsl-1.2
CONDA_DIR=/pw/.miniconda3
INSTALL_CONDA=true
LOCAL_CONDA_YAML=./requirements/conda_env_local.yaml
```

##### Sample executors.json
```
{
  "myexecutor_1": {
   ...
    "CONDA_ENV": "parsl-1.2",
    "CONDA_DIR": "/p/home/avidalto/pw/miniconda",
    "LOCAL_CONDA_YAML": "./requirements/conda_env_remote.yaml",
    "INSTALL_CONDA": "true",
    ...
  }
}
```


### 2. Tunnels for the worker ports:
Parsl needs to access at least two remote executor ports per executor resource. SSH tunnels are created by the wrapper scripts. The script searches for available ports, establishes the tunnels before running the workflow and cancels the tunnels after running the workflow.


### 3. Staging:
We can create multiple data providers without having to build a custom parsl distribution as long as we stage parsl_utils to the remote side and export the right `PYTHONPATH` at worker initialization (worker_init).

### 4. Multihost:
The resource definition section for workflows is very outdated on the platform. For multihost Parsl this section should associate the labels in the executors of the Parsl configuration to the names of the pools and to certain pool properties or specifications (location of the conda environment in the remote host, number of cores, directory for parsl logs, pool ports, etc). These specifications may be defined at different level:
- Resource level: For all workflows running in this resource. For example, the workdir or the scheduler type (PBS / SLURM). These could be added to the resource definition page and obtained by the parsl_utils via API calls.
- Workflow level: For all jobs of a given workflow. For example, the cores per worker or the conda environment to activate. These could defined in a workflow definition page or hardcoded for a given workflow. 
- Job level: For a given job. Need to defined in the input form at launch time as well as changing any previous workflow defaults.


For now, all these parameters are defined in the `executors.json` file for each executor. An example of this file is pasted below:

```
{
    "cpu_executor": {
        "POOL": "koehr_cpu",
        "CONDA_ENV": "parsl_py39",
        "CONDA_DIR": "/contrib/Alvaro.Vidal/miniconda3",
        "RUN_DIR": "/home/Alvaro.Vidal/tmp",
        "WORKER_LOGDIR_ROOT": "/home/Alvaro.Vidal/tmp",
        "SSH_CHANNEL_SCRIPT_DIR": "/home/Alvaro.Vidal/tmp",
        "SINGULARITY_CONTAINER_PATH": "/contrib/Alvaro.Vidal/tensorflow_latest-gpu-jupyter-extra.sif",
        "CORES_PER_WORKER": 4,
        "CREATE_SINGULARITY_CONTAINER": "true",
        "INSTALL_CONDA": "true",
        "LOCAL_CONDA_YAML": "./requirements/conda_env.yaml",
        "LOCAL_SINGULARITY_FILE": "./requirements/singularity.file"
    },
    "gpu_executor": {
        "POOL": "google_gpu",
        "CONDA_ENV": "parsl_py39",
        "CONDA_DIR": "/contrib/Alvaro.Vidal/miniconda3",
        "RUN_DIR": "/home/Alvaro.Vidal/tmp",
        "WORKER_LOGDIR_ROOT": "/home/Alvaro.Vidal/tmp",
        "SSH_CHANNEL_SCRIPT_DIR": "/home/Alvaro.Vidal/tmp",
        "SINGULARITY_CONTAINER_PATH": "/contrib/Alvaro.Vidal/tensorflow_latest-gpu-jupyter-extra.sif",
        "CORES_PER_WORKER": 4,
        "CREATE_SINGULARITY_CONTAINER": "true",
        "INSTALL_CONDA": "true",
        "LOCAL_CONDA_YAML": "./requirements/conda_env.yaml",
        "LOCAL_SINGULARITY_FILE": "./requirements/singularity.file"
    }
}
```

The label is the top level key of the JSON. The executors definition is completed at job runtime using the PW API and scripts to obtain current resource information such as the IP address and available worker ports, for example:

```
{
    "cpu_executor": {
        "POOL": "koehr_cpu",
        "CONDA_ENV": "parsl_py39",
        "CONDA_DIR": "/contrib/Alvaro.Vidal/miniconda3",
        "RUN_DIR": "/home/Alvaro.Vidal/tmp",
        "WORKER_LOGDIR_ROOT": "/home/Alvaro.Vidal/tmp",
        "SSH_CHANNEL_SCRIPT_DIR": "/home/Alvaro.Vidal/tmp",
        "SINGULARITY_CONTAINER_PATH": "/contrib/Alvaro.Vidal/tensorflow_latest-gpu-jupyter-extra.sif",
        "CORES_PER_WORKER": 4,
        "CREATE_SINGULARITY_CONTAINER": "true",
        "INSTALL_CONDA": "true",
        "LOCAL_CONDA_YAML": "./requirements/conda_env.yaml",
        "LOCAL_SINGULARITY_FILE": "./requirements/singularity.file",
        "HOST_IP": "34.136.254.27",
        "WORKER_PORT_1": 55351,
        "WORKER_PORT_2": 55352
    },
    "gpu_executor": {
        "POOL": "google_gpu",
        "CONDA_ENV": "parsl_py39",
        "CONDA_DIR": "/contrib/Alvaro.Vidal/miniconda3",
        "RUN_DIR": "/home/Alvaro.Vidal/tmp",
        "WORKER_LOGDIR_ROOT": "/home/Alvaro.Vidal/tmp",
        "SSH_CHANNEL_SCRIPT_DIR": "/home/Alvaro.Vidal/tmp",
        "SINGULARITY_CONTAINER_PATH": "/contrib/Alvaro.Vidal/tensorflow_latest-gpu-jupyter-extra.sif",
        "CORES_PER_WORKER": 4,
        "CREATE_SINGULARITY_CONTAINER": "true",
        "INSTALL_CONDA": "true",
        "LOCAL_CONDA_YAML": "./requirements/conda_env.yaml",
        "LOCAL_SINGULARITY_FILE": "./requirements/singularity.file",
        "HOST_IP": "34.121.107.245",
        "WORKER_PORT_1": 55353,
        "WORKER_PORT_2": 55354
    }
}
```

The completed configuration is used to define the Parsl configuration.

An option that would provide flexibility to the workflow developer would be to:
1. Add a JSON parser to the workflow launching process such that it is up to the workflow developer to include different executor properties (singularity, docker, Vcinity end point, etc).
2. Add some documentation (like the workflow description) to be displayed together with the JSON expaining the requirements for each pool (image names, software requirements, external disks, ...) and the meaning of the keys in the JSON file

This can be achieved already using Jupyter notebooks to edit the JSON (see DIU notebook). For presenting the JSON parser in the input form I see two options:
1. Use the cloud-like icon to display the parser
2. Present it when the user clicks execute in the context of "update / verify / accept" these executor settings.

### 5. Killing jobs:
When a job is killed/stropped in PW the script `/pw/jobs<job-number>/kill.sh` is called. When a job fails or runs successfully the kill.sh script is called by the workflow itself. This scripts handles cleaning tasks such as killing the port tunnels or any PBS or SLURM jobs (for PBS and SLURM providers only, not for LOCAL provider)




