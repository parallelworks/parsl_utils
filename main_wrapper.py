import subprocess
import sys, os
from pool_info import get_master_node_ip

# FIXME: This entire script should not be needed!
#        Users need to be able to decide which python environment is needed by their workflows!
print('Wrapping command to active right python environment')
cmd = 'bash main_wrapper.sh python main.py ' + ' '.join(sys.argv[1:])

host = get_master_node_ip(pool_name = 'gcpclustergen2')

subprocess.run(cmd, shell = True, env=dict(os.environ, HOST_IP = host))
