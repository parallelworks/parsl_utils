import socket
import os
import subprocess
from time import sleep
import signal

ssh = 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no {host} \'sudo bash -s\' < {script}'

def set_up_worker_ssh_tunnel(ip, ports = [], verbosity = 0):
    # These ports dont work: "77100 77101 77102 77103 77104"
    tf = open('tunnels.sh', 'w')
    for port in ports:
        cmd = "sudo -E -u {RUNUSER} bash -c \"{sshcmd} -L 0.0.0.0:{port}:{internal_ip}:{port} {u}@{s} -fNT\"".format(
            ports = ' '.join([ str(p) for p in ports]),
            internal_ip = socket.gethostbyname(socket.gethostname()),
            RUNUSER = os.environ['PW_USER'],
            u = os.environ['PW_USER'],
            sshcmd = 'setsid ssh',
            s = os.environ['PW_USER_HOST'],
            port = port
        )
        if verbosity > 0:
            print(cmd, flush = True)

        tf.write(cmd + '\n')
    tf.close()

    ssh_cmd = ssh.format(
        host = ip,
        script = 'tunnels.sh'
    )
    if verbosity > 0:
        print(ssh_cmd, flush = True)

    subprocess.run(ssh_cmd, shell = True)


if __name__ == '__main__':
    print('Internal IP: ', socket.gethostbyname(socket.gethostname()))
    print('RUNUSER:     ', os.environ['PW_USER'])
    ip = '34.66.21.15'

    set_up_worker_ssh_tunnel(ip, ports = [55233 , 55234], verbosity = 1)