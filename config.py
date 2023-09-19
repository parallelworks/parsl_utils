from parsl.config import Config
from parsl.channels import SSHChannel
from parsl.providers import LocalProvider, SlurmProvider, PBSProProvider
from parsl.executors import HighThroughputExecutor
#from parsl.monitoring.monitoring import MonitoringHub
from parsl.addresses import address_by_hostname
#from parsl.data_provider.rsync import RSyncStaging

import os
import json

import parsl_utils
from parsl_utils.data_provider.rsync import PWRSyncStaging
from parsl_utils.data_provider.gsutil import PWGsutil
from parsl_utils.data_provider.s3 import PWS3


def guess_correct_type(v):
    if type(v) is not str:
        return v
    
    try:
        result = int(v)
        return result
    except ValueError:
        try:
            result = float(v)
            return result
        except ValueError:
            return v


def get_provider_parameters_from_form(resource_inputs):
    provider_options = {}
    for k,v in resource_inputs.items():
        if k.startswith('_parsl_provider_'):
            key = k.replace('_parsl_provider_', '')
            provider_options[key] = guess_correct_type(v)
            if '__RUN_DIR__' in v:
                provider_options[key] = v.replace('__RUN_DIR__', resource_inputs['resource']['jobdir'])

    return provider_options

# job_name = workflow_name + job number
job_name = '-'.join(os.getcwd().split('/')[-2:])

# Find all resource labels
with open('inputs.json') as inputs_json:
    form_inputs = json.load(inputs_json)
        
resource_labels = [label.replace('pwrl_','') for label in form_inputs.keys() if label.startswith('pwrl_')]    

# Need to name the job to be able to remove it with clean_resources.sh!
job_name = '-'.join(os.getcwd().split('/')[-2:])

# Usefulfor workflows accessing information about the resources, e.g.: jobdir
executor_dict = {}

# Define HighThroughputExecutors
executors = []
for label in resource_labels:
    resource_inputs_json = os.path.join('resources', label, 'inputs.json')
    with open(resource_inputs_json) as inputs_json:
        resource_inputs = json.load(inputs_json)

    executor_dict[label] = resource_inputs
    
    script_dir = os.path.join(resource_inputs['resource']['jobdir'], 'ssh_channel_script_dir')
    worker_logdir_root = os.path.join(resource_inputs['resource']['jobdir'], 'worker_logdir_root')
    
    # To support kerberos:
    gssapi_auth = False
    if 'gssapi_auth' in resource_inputs:
        if resource_inputs['gssapi_auth'].lower() == "true":
            gssapi_auth = True

    hostname = resource_inputs['resource']['publicIp']
    if '@' in hostname:
        hostname = hostname.split('@')[1]

    channel = SSHChannel(
        hostname = hostname,
        username = resource_inputs['resource']['username'],
        # Full path to a script dir where generated scripts could be sent to
        script_dir = script_dir,
        key_filename = os.path.expanduser('~/.ssh/pw_id_rsa'),
        gssapi_auth = gssapi_auth
    )
    
    # To support jump boxes, overwrite
    # SSHChannel hostname and port with
    # localhost and local port to which
    # cluster login node 22 is forwarded.
    ssh_jump_config = os.path.join('/tmp/.ssh/', resource_inputs['resource']['name'], '.config')
    if os.path.isfile(ssh_jump_config):
        # There is a jump box. Get localport.
        file = open(ssh_jump_config, 'r')
        lines = file.readlines()
        for line in lines:
            if "Port" in line:
                localport=line.split()[1]

	    # Adjust Parsl config
        channel.hostname = "localhost"
        channel.port = localport

    # Define worker init:
    # - export PYTHONPATH={run_dir} is needed to use custom staging providers
    worker_init = 'export PYTHONPATH={run_dir}; bash {workdir}/pw/remote.sh; bash {workdir}/pw/.pw/remote.sh; source {conda_sh}; conda activate {conda_env}; cd {run_dir}; {clean_cmd}'.format(
        workdir = resource_inputs['resource']['workdir'],
        conda_sh = os.path.join(resource_inputs['worker_conda_dir'], 'etc/profile.d/conda.sh'),
        conda_env = resource_inputs['worker_conda_env'],
        run_dir = resource_inputs['resource']['jobdir'],
        clean_cmd = "ps -x | grep worker.pl | grep -v grep | awk '{print $1}'"
    )

    # Data provider:
    # One instance per executor
    storage_access = [ 
        PWRSyncStaging(label),
        PWGsutil(label),
        PWS3(label)
    ]

    # Define provider
    provider_options = get_provider_parameters_from_form(resource_inputs)
    if resource_inputs['jobschedulertype'] == 'PBS':
        provider = PBSProProvider(
            **provider_options,
            worker_init = worker_init,
            channel = channel
        )

    elif resource_inputs['jobschedulertype'] == 'SLURM':
        if 'init_blocks' not in provider_options:
            provider_options['init_blocks'] = 0

        provider = SlurmProvider(
            **provider_options,
            worker_init = worker_init,
            channel = channel
        )

    else:
        # Need to overwrite the default worker_init since we don't want to run remote.sh in this case
        worker_init = 'export PYTHONPATH={run_dir}; source {conda_sh}; conda activate {conda_env}; cd {run_dir}'.format(
            conda_sh = os.path.join(resource_inputs['worker_conda_dir'], 'etc/profile.d/conda.sh'),
            conda_env = resource_inputs['worker_conda_env'],
            run_dir = resource_inputs['resource']['jobdir']
        )

        provider = LocalProvider(
            worker_init = worker_init,
            channel = channel
        )

    if 'cores_per_worker' in resource_inputs:
        cores_per_worker = float(resource_inputs['cores_per_worker'])
    else:
        cores_per_worker = 1.0

    
    executors.append(
        HighThroughputExecutor(
	    interchange_port_range = (50000, 55500),
	    worker_port_range = (50000, 55500),
            worker_ports=((
                resource_inputs['resource']['ports'][0], 
                resource_inputs['resource']['ports'][1]
            )),
            label = label,
            worker_debug = True,             # Default False for shorter logs
            working_dir =  resource_inputs['resource']['jobdir'],
            cores_per_worker = cores_per_worker,
            worker_logdir_root = worker_logdir_root,
            address = resource_inputs['resource']['privateIp'],
            provider = provider,
            storage_access = storage_access
        )
    )
    
if 'parsl_retries' in form_inputs:
    retries = int(form_inputs['parsl_retries'])
    from . import retry_handler
    retry_handler = retry_handler.retry_handler
else:
    retries = 0
    retry_handler = None

if len(executors) > 1:
    config = Config(
        retries = retries,
        retry_handler = retry_handler,
        executors = executors
    )
else:
    from parsl.monitoring.monitoring import MonitoringHub
    executor_address = resource_inputs['resource']['privateIp']
    config = Config(
        retries = retries,
        retry_handler = retry_handler,
        executors = executors,
        monitoring = MonitoringHub(
            hub_address = executor_address,
            monitoring_debug = False,
            workflow_name = str(job_name),
            logging_endpoint = 'sqlite:////pw/.monitoring.db',
            resource_monitoring_enabled = False,
        )
    )
	
print(config)

# ,
#    monitoring = MonitoringHub(
#       hub_address = address_by_hostname(),
#       resource_monitoring_interval = 5
#   )
# )
