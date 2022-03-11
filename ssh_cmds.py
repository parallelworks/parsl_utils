ssh = 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no '
scp = 'scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no '
ssh_shell = 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no {host} -t \'bash -l -c \"{cmd}\"\''
