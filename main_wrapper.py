import subprocess
import sys, os
from pool_info import get_master_node_ip

# FIXME: This entire script should not be needed!
#        Users need to be able to decide which python environment is needed by their workflows!
print('Wrapping command to active right python environment', flush = True)
cmd = 'bash parsl_utils/main_wrapper.sh python main.py {args}'.format(
    args = ' '.join(sys.argv[1:])
)

host = get_master_node_ip(pool_name = 'gcpclustergen2')

print(cmd, flush = True)
p = subprocess.run(cmd, shell = True, env=dict(os.environ, HOST_IP = host))

if p.returncode != 0:
    sys.exit('Command {} failed'.format(cmd))