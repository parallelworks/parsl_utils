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
    "myexecutor_1": {
        "POOL": "gcpclustergen2",
        "CONDA_ENV": "parsl_py39",
        "CONDA_DIR": "/contrib/Alvaro.Vidal/miniconda3",
        "RUN_DIR": "/contrib/Alvaro.Vidal/tmp",
        "WORKER_LOGDIR_ROOT": "/contrib/Alvaro.Vidal/tmp",
        "SSH_CHANNEL_SCRIPT_DIR": "/contrib/Alvaro.Vidal/tmp",
        "CORES_PER_WORKER": 4,
        "INSTALL_CONDA": "true",
        "LOCAL_CONDA_YAML": "./requirements/conda_env.yaml"
    },
    "myexecutor_2": {
        "POOL": "gcpcluster",
        "CONDA_ENV": "parsl_py39",
        "CONDA_DIR": "/contrib/Alvaro.Vidal/miniconda3",
        "RUN_DIR": "/contrib/Alvaro.Vidal/tmp",
        "WORKER_LOGDIR_ROOT": "/contrib/Alvaro.Vidal/tmp",
        "SSH_CHANNEL_SCRIPT_DIR": "/contrib/Alvaro.Vidal/tmp",
        "CORES_PER_WORKER": 4,
        "INSTALL_CONDA": "true",
        "LOCAL_CONDA_YAML": "./requirements/conda_env.yaml"
    }
}
```

The label is the top level key of the JSON. The script `parsl_utils/complete_exec_conf.py` completes the configuration by adding the IP address and worker ports of the host, for example:

```
{
    "myexecutor_1": {
        "POOL": "gcpclustergen2",
        "REMOTE_CONDA_ENV": "parsl_py39",
        "REMOTE_CONDA_DIR": "/contrib/Alvaro.Vidal/miniconda3",
        "RUN_DIR": "/contrib/Alvaro.Vidal/tmp",
        "WORKER_LOGDIR_ROOT": "/contrib/Alvaro.Vidal/tmp",
        "SSH_CHANNEL_SCRIPT_DIR": "/contrib/Alvaro.Vidal/tmp",
        "CORES_PER_WORKER": 4,
        "INSTALL_CONDA": "true",
        "LOCAL_CONDA_YAML": "./requirements/conda_env.yaml",
        "HOST_IP": "35.222.130.18",
        "WORKER_PORT_1": 55254,
        "WORKER_PORT_2": 55255
    },
    "myexecutor_2": {
        "POOL": "gcpcluster",
        "REMOTE_CONDA_ENV": "parsl_py39",
        "REMOTE_CONDA_DIR": "/contrib/Alvaro.Vidal/miniconda3",
        "RUN_DIR": "/contrib/Alvaro.Vidal/tmp",
        "WORKER_LOGDIR_ROOT": "/contrib/Alvaro.Vidal/tmp",
        "SSH_CHANNEL_SCRIPT_DIR": "/contrib/Alvaro.Vidal/tmp",
        "CORES_PER_WORKER": 4,
        "INSTALL_CONDA": "true",
        "LOCAL_CONDA_YAML": "./requirements/conda_env.yaml",
        "HOST_IP": "34.136.181.73",
        "WORKER_PORT_1": 55256,
        "WORKER_PORT_2": 55257
    }
}
```

The completed configuration is used by `main.py` script to define the Parsl configuration.


