from parsl.config import Config
from parsl.channels import SSHChannel
from parsl.providers import LocalProvider, SlurmProvider, PBSProProvider
from parsl.executors import HighThroughputExecutor
#from parsl.monitoring.monitoring import MonitoringHub
from parsl.addresses import address_by_hostname
from parsl.data_provider.rsync import RSyncStaging

import os
import json

import parsl_utils


# Need to name the job to be able to remove it with clean_resources.sh!
job_number = os.getcwd().replace('/pw/jobs/', '')

with open('executors.json', 'r') as f:
    exec_conf = json.load(f)

for label, executor in exec_conf.items():
    for k, v in executor.items():
        if type(v) == str:
            exec_conf[label][k] = os.path.expanduser(v)

# Define HighThroughputExecutors
executors = []
for exec_label, exec_conf_i in exec_conf.items():
    # Add sandbox directory
    if 'RUN_DIR' in exec_conf_i:
        exec_conf[exec_label]['RUN_DIR'] = exec_conf_i['RUN_DIR']
    else:
        base_dir = '/tmp'
        exec_conf[exec_label]['RUN_DIR'] = os.path.join(base_dir, str(job_number))
                
    channel = SSHChannel(
        hostname = exec_conf[exec_label]['HOST_IP'],
        username = exec_conf[exec_label]['HOST_USER'],
        # Full path to a script dir where generated scripts could be sent to
        script_dir = exec_conf[exec_label]['SSH_CHANNEL_SCRIPT_DIR'],
            key_filename = '/home/{PW_USER}/.ssh/pw_id_rsa'.format(
            PW_USER = os.environ['PW_USER']
        )
    )

    # Define worker init:
    # - export PYTHONPATH={run_dir} is needed to use custom staging providers
    worker_init = 'export PYTHONPATH={run_dir}; bash {workdir}/pw/remote.sh; source {conda_sh}; conda activate {conda_env}; cd {run_dir}'.format(
        workdir = exec_conf[exec_label]['WORKDIR'],
        conda_sh = os.path.join(exec_conf[exec_label]['CONDA_DIR'], 'etc/profile.d/conda.sh'),
        conda_env = exec_conf[exec_label]['CONDA_ENV'],
        run_dir = exec_conf[exec_label]['RUN_DIR']
    )

    if "PROVIDER_TYPE" in exec_conf_i:
        if exec_conf[exec_label]['PROVIDER_TYPE'] == "LOCAL":
            # Need to overwrite the default worker_init since we don't want to run remote.sh in this case
            worker_init = 'export PYTHONPATH={run_dir}; source {conda_sh}; conda activate {conda_env}; cd {run_dir}'.format(
                conda_sh = os.path.join(exec_conf[exec_label]['CONDA_DIR'], 'etc/profile.d/conda.sh'),
                conda_env = exec_conf[exec_label]['CONDA_ENV'],
                run_dir = exec_conf[exec_label]['RUN_DIR']
            )

    # Define provider
    # Default provider
    provider = None
    if "PROVIDER_TYPE" in exec_conf_i:
        if exec_conf[exec_label]['PROVIDER_TYPE'] == "PBS":
            provider = PBSProProvider(
                queue = exec_conf[exec_label]['QUEUE'],
                scheduler_options = '#PBS -q {QUEUE}'.format(
                    QUEUE = exec_conf[exec_label]['QUEUE']
                ),
                nodes_per_block = int(exec_conf[exec_label]['NODES_PER_BLOCK']),
                cpus_per_node = exec_conf[exec_label]['CPUS_PER_NODE'],
                min_blocks = int(exec_conf[exec_label]['MIN_BLOCKS']),
                max_blocks = int(exec_conf[exec_label]['MAX_BLOCKS']),
                walltime = exec_conf[exec_label]['WALLTIME'],
                worker_init = worker_init,
                channel = channel
            )
        elif exec_conf[exec_label]['PROVIDER_TYPE'] == "LOCAL":
            provider = LocalProvider(
                worker_init = worker_init,
                channel = channel
            )

    if provider == None:
        provider = SlurmProvider(
            partition = exec_conf[exec_label]['PARTITION'],
            nodes_per_block = int(exec_conf[exec_label]['NODES_PER_BLOCK']),
            cores_per_node = int(exec_conf[exec_label]['NTASKS_PER_NODE']),
            min_blocks = int(exec_conf[exec_label]['MIN_BLOCKS']),
            max_blocks = int(exec_conf[exec_label]['MAX_BLOCKS']),
            walltime = exec_conf[exec_label]['WALLTIME'],
            worker_init = worker_init,
            channel = channel
        )
    
    executors.append(
        HighThroughputExecutor(
            worker_ports=((
                int(exec_conf[exec_label]['WORKER_PORT_1']), 
                int(exec_conf[exec_label]['WORKER_PORT_2'])
            )),
            label = exec_label,
            worker_debug = True,             # Default False for shorter logs
            cores_per_worker = float(exec_conf[exec_label]['CORES_PER_WORKER']),
            worker_logdir_root = exec_conf[exec_label]['WORKER_LOGDIR_ROOT'],
            address = exec_conf[exec_label]['ADDRESS'],
            provider = provider,
            storage_access=[parsl_utils.staging.RSyncStaging('usercontainer')]
        )
    )
    
config = Config(
    executors = executors
)
# ,
#    monitoring = MonitoringHub(
#       hub_address = address_by_hostname(),
#       resource_monitoring_interval = 5
#   )
# )
