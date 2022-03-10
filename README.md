# Native Parsl Utils
This repo contains helper scripts for running native/official Parsl in cluster pools on the PW platform. These scripts are considered temporary ad-hoc code that should be better integrated on the platform and were develeped to temporarily address the issues below:

### 1. Conda Environment:
Workflows needs to run in a specific conda environment which needs to be installed and accessible on the user container and on the head node of the cluster. The scripts `main_wrapper.py` and `main_wrapper.sh` are used to activate the environment on the PW platform before running the workflow. The `workflow.xml` executes the python wrapper `<command interpreter='parsl'>main_wrapper.py</command>` using the parsl interpreter that executes python in the default conda environment. The `main_wrapper.py` script redirects the arguments to the `main_wrapper.sh` script that activates the right conda environment and checks that it is installed and available on the user container and on the head node of the cluster. The `main_wrapper.py` could be avoided with a `bash` workflow interpreter. I think we should support either one native parsl environment or a bring your own conda environment(s) approach.

### 2. Tunnels for the worker ports:
Parsl needs to access at least two remote executor ports.  The script `tunnels.py` was developed to establish the port connection.

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
