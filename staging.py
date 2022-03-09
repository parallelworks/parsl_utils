import os
import subprocess
import time

ssh = 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no '
ssh_shell = 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no {host} -t \'bash -l -c \"{cmd}\"\''

def _stage_input(ioval, host):
    if ioval['global_path'].startswith('pw://'):
        global_path = ioval['global_path'].replace('pw://', '').format(cwd = os.getcwd())

        # Rsync needs the parent directory not the full path to the worker directory
        if ioval['type'] == 'directory':
            worker_path = os.path.dirname(ioval['worker_path'])
        else:
            worker_path = ioval['worker_path']

        # Remove q from avzq to get rsync output
        cmd = 'rsync -avzq {global_path} {host}:{worker_path}'.format(
            global_path = global_path,
            host = host,
            worker_path = worker_path
        )

    if ioval['global_path'].startswith('gs://'):
        if ioval['type'] == 'file':
            cmd = ssh + host + ' gsutil -m cp -r ' + ioval['global_path'] + ' ' + ioval['worker_path']
        elif ioval['type'] == 'directory':
            cmd = ssh + host + ' gsutil -m rsync -r ' + ioval['global_path'] + ' ' + ioval['worker_path']


    if ioval['global_path'].startswith('s3://'):
        if ioval['type'] == 'file':
            cmd = ssh_shell.format(
                host = host,
                cmd = ' aws s3 cp ' + ioval['global_path'] + ' ' + ioval['worker_path']
            )
        elif ioval['type'] == 'directory':
            cmd = ssh_shell.format(
                host = host,
                cmd = ' aws s3 sync ' + ioval['global_path'] + ' ' + ioval['worker_path']
            )

    print(cmd, flush = True)
    subprocess.run(cmd, shell = True)


def stage_inputs(io, host):
    print('\nSTAGING INPUTS:', flush = True)
    for ioval in io.values():
        _stage_input(ioval, host)



def _stage_output(ioval, host):
    if ioval['global_path'].startswith('pw://'):
        global_path = ioval['global_path'].replace('pw://', '').format(cwd = os.getcwd())

        # Rsync needs the parent directory not the full path to the worker directory
        if ioval['type'] == 'directory':
            global_path = os.path.dirname(global_path)

        # Remove q from avzq to get rsync output
        cmd = 'rsync -avzq {host}:{worker_path} {global_path}'.format(
            global_path = global_path,
            host = host,
            worker_path = ioval['worker_path']
        )

    if ioval['global_path'].startswith('gs://'):
        if ioval['type'] == 'file':
            cmd = ssh + host + ' gsutil -m cp -r ' + ioval['worker_path'] + ' ' + ioval['global_path']
        elif ioval['type'] == 'directory':
            cmd = ssh + host + ' gsutil -m rsync -r ' + ioval['worker_path'] + ' ' + ioval['global_path']

    if ioval['global_path'].startswith('s3://'):
        if ioval['type'] == 'file':
            cmd = ssh_shell.format(
                host = host,
                cmd = ' aws s3 cp ' + ioval['worker_path'] + ' ' + ioval['global_path']
            )
        elif ioval['type'] == 'directory':
            cmd = ssh_shell.format(
                host = host,
                cmd = '  aws s3 sync ' + ioval['worker_path'] + ' ' + ioval['global_path']
            )

    print(cmd, flush = True)
    subprocess.run(cmd, shell = True)



def stage_outputs(io, host):
    print('\nSTAGING OUTPUTS:', flush = True)
    for ioval in io.values():
        _stage_output(ioval, host)

