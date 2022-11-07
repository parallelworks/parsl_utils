# Native Parsl Utils
This repo contains helper scripts for running native/official Parsl in cluster pools on the PW platform. These scripts are considered temporary ad-hoc code that should be better integrated on the platform and were develeped to temporarily address the issues below:

### 1. Conda Environment:
Workflows needs to run in a specific conda environment which needs to be installed and accessible on the user container and on the head node of the cluster.
- The scripts `main_wrapper.py` and `main_wrapper.sh` are used to activate the environment on the PW platform before running the workflow. The `workflow.xml` executes the python wrapper `<command interpreter='parsl'>main_wrapper.py</command>` using the parsl interpreter that executes python in the default conda environment. The `main_wrapper.py` could be avoided with a `bash` workflow interpreter.
- The `main_wrapper.py` script redirects the arguments to the `main_wrapper.sh` script that activates the right conda environment
- The scripts `install_conda_requirements.sh` makes sure that conda is installed and the right conda environment is present. Conda environments are defined by their corresponding YAML files (`conda env export`) for the local (PW) and executor environments in the `local.conf` and `executor.json` files of the workflow. The `main_wrapper.py` could be avoided with a `bash` workflow interpreter.
- The YAML files for the local and executor environments are provided as workflow files, for example, under a requirements directory.

### 2. Tunnels for the worker ports:
Parsl needs to access at least two remote executor ports. SSH tunnels are created by the `main_wrapper.sh` scripts. The script searches for available ports, establishes the tunnels before running the workflow and cancels the tunnels after running the workflow.

```
# Create tunnel for worker ports
worker_ports = (55233, 52234)
parsl_utils.tunnels.set_up_worker_ssh_tunnel(host, ports = list(worker_ports))
```

```
config = Config(
    executors=[
        HighThroughputExecutor(
            worker_ports = (worker_ports),
            label = 'parsl-cluster',
            worker_debug = True,             # Default False for shorter logs
            cores_per_worker = int(4),     # One worker per node
            worker_logdir_root = args['remote_dir'], #os.getcwd() + '/parsllogs',
            provider = local_provider
        )
    ]
)
```

TODO: This approach only works with the LocalProvider. To us the SlurmProvider we need tunnels also from compute nodes (not just the head node). Right now it is failing to connect:
```
[Alvaro.Vidal@compute-0001 tmp]$ cat parsl.slurm.1648163466.0924313.submit.stdout
Found cores : 30
Launching worker: 1
Failed to find a viable address to connect to interchange. Exiting
```

### 3. Staging:
I have not been able to use a data provider available in native parsl. Note that if we were to develop our own data providers we would need to address how to integrate this into the native/official parsl distributions. Therefore, the script `parsl_wrappers.py` and `staging.py` were developed to handle inputs and outputs before and after the app runs, respectively, using a function decorator. An example is shown below:

```
# App to test Parsl wrappers
@parsl_utils.parsl_wrappers.log_app
@parsl_utils.parsl_wrappers.stage_app(host)
@bash_app
def parsl_app(cmd, inputs = [], outputs = [], inputs_dict = {}, outputs_dict = {}, stdout='std.out', stderr = 'std.err'):
    # APP CODE HERE
```


The staging criteria is simple. Input and output files are defined in dictionaries `inputs_dict` and `output_dict`, respectively, as shown in the example below:

```
inputs_dict = {
    "start_jplab_sh": {
        "type": "directory",
        "global_path": "pw://{cwd}/start_jupyterlab",
        "worker_path": "{remote_dir}/start_jupyterlab".format(remote_dir = args['remote_dir'])
    },
    "sample_notebooks": {
        "type": "directory",
            "global_path": "pw://{cwd}/start_jupyterlab/sample_notebooks",
            "worker_path": "{jupyter_lab_dir}/sample_notebooks".format(jupyter_lab_dir = args['jupyter_lab_dir'])
        },
    }
}
```

The type can be a file or a directory. The global path points to the place where the data resides. Use pw, gs, and s3 for the pw user container, google bucket and s3 storage, respectively. The placeholder `{cwd}` is replaced by the path to the job directory (`/pw/jobs/job_number`). The worker path points to the place where the data is staged in the worker. All paths must be absolute.


### 4. Multihost:
The resource definition section for workflows is very outdated on the platform. For multihost Parsl this section should associate the labels in the executors of the Parsl configuration to the names of the pools and to certain pool properties or specifications (location of the conda environment in the remote host, number of cores, directory for parsl logs, pool ports, etc). For now, this is resolved with the `executors.json` file. An example of this file is pasted below:

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

The label is the top level key of the JSON. The script `parsl_utils/complete_exec_conf.py` completes the configuration by adding the IP address and worker ports of the host, for example:

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

The completed configuration is used by `main.py` script to define the Parsl configuration.

An option that would provide flexibility to the workflow developer would be to:
1. Add a JSON parser to the workflow launching process such that it is up to the workflow developer to include different executor properties (singularity, docker, Vcinity end point, etc).
2. Add some documentation (like the workflow description) to be displayed together with the JSON expaining the requirements for each pool (image names, software requirements, external disks, ...) and the meaning of the keys in the JSON file

This can be achieved already using Jupyter notebooks to edit the JSON (see DIU notebook). For presenting the JSON parser in the input form I see two options:
1. Use the cloud-like icon to display the parser
2. Present it when the user clicks execute in the context of "update / verify / accept" these executor settings.

### 5. Killing jobs:
Some workflow run indefinitely like the `start_scheduler` (GT) or `start_jupyterlab`. For the `start_jupyterlab` workflow I have not been able to exit the workflow without killing juputerlab. Other times you just want to kill a job because it was running for two long or you detect some issue. This is particularly importante since you also need to kill the tunnels. Right now there is no way of doing this. I have added the following lines to the `main_wrapper.sh` to handle this. The job is passed an argument with the job id:

```
job_number=$(basename ${PWD})
job_number=job-${job_number}_date-$(date +%s)_random-${RANDOM}
# To track and cancel the job
$@ --job_number ${job_number}
ec=$?
main_pid=$!
```

Such that you can find the running process with `ps -x | grep job_number` (or by date). And the following lines to make sure all processes started by the job die including the tunnels in the user container:

```
# Kill all descendant processes
pkill -P ${main_pid}
pkill -P $$

# Make super sure python process dies:
python_pid=$(ps -x | grep  ${job_number} | grep python | awk '{print $1}')
if ! [ -z "${python_pid}" ]; then
    echo
    echo "Killing remaining python process ${python_pid}"
    pkill -p ${python_pid}
    kill ${python_pid}
fi
```







