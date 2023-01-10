import os
import subprocess
import time

from parsl.data_provider.files import File


ssh = 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no '
ssh_shell = 'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no {host} -t \'bash -l -c \"{cmd}\"\''

def PWFile(path, local_path, scheme, netloc = None):
    f = File(scheme + '://' + path)
    f.local_path = local_path
    if netloc:
        f.netloc = netloc
    return f

def _stage_input(ioval, host):
    if ioval['global_path'].startswith('pw://'):
        global_path = ioval['global_path'].replace('pw://', '').format(cwd = os.getcwd())

        # Rsync needs the parent directory not the full path to the worker directory
        if ioval['type'] == 'directory':
            worker_path = os.path.dirname(ioval['worker_path'])
        else:
            worker_path = ioval['worker_path']

        # Remove q from avzq to get rsync output
        #cmd = 'rsync -avzq {global_path} {host}:{worker_path}'.format(
        #    global_path = global_path,
        #    host = host,
        #    worker_path = worker_path
        #)
        cmd = 'rsync -avzq --rsync-path=\"mkdir -p {root_path} && rsync\" {global_path} {host}:{worker_path}'.format(
            global_path = global_path,
            host = host,
            worker_path = worker_path,
            root_path = os.path.dirname(worker_path)
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
        cmd = 'mkdir -p {root_path} && rsync -avzq {host}:{worker_path} {global_path}'.format(
            global_path = global_path,
            host = host,
            worker_path = ioval['worker_path'],
            root_path = os.path.dirname(global_path)
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



import logging
import os

from parsl.utils import RepresentationMixin
from parsl.data_provider.staging import Staging

logger = logging.getLogger(__name__)


class RSyncStaging(Staging, RepresentationMixin):
    """
    This staging provider will execute rsync on worker nodes
    to stage in files from a remote location.
    Worker nodes must be able to authenticate to the rsync server
    without interactive authentication - for example, worker
    initialization could include an appropriate SSH key configuration.
    The submit side will need to run an rsync-compatible server (for example,
    an ssh server with the rsync binary installed)
    """

    def __init__(self, hostname):
        self.hostname = hostname

    def can_stage_in(self, file):
        return file.scheme == "file"

    def can_stage_out(self, file):
        return file.scheme == "file"

    def stage_in(self, dm, executor, file, parent_fut):
        # we need to make path an absolute path, because
        # rsync remote name needs to include absolute path
        file.path = os.path.abspath(file.path)

        working_dir = dm.dfk.executors[executor].working_dir

        if working_dir:
            file.local_path = os.path.join(working_dir, file.filename)
        else:
            file.local_path = file.filename

        return None

    def stage_out(self, dm, executor, file, parent_fut):

        file.path = os.path.abspath(file.path)

        working_dir = dm.dfk.executors[executor].working_dir

        if working_dir:
            file.local_path = os.path.join(working_dir, file.filename)
        else:
            file.local_path = file.filename

        return None

    def replace_task(self, dm, executor, file, f):
        logger.debug("Replacing task for rsync stagein")
        working_dir = dm.dfk.executors[executor].working_dir
        return in_task_stage_in_wrapper(f, file, working_dir, self.hostname)

    def replace_task_stage_out(self, dm, executor, file, f):
        logger.debug("Replacing task for rsync stageout")
        working_dir = dm.dfk.executors[executor].working_dir
        return in_task_stage_out_wrapper(f, file, working_dir, self.hostname)


def in_task_stage_in_wrapper(func, file, working_dir, hostname):
    def wrapper(*args, **kwargs):
        import logging
        logger = logging.getLogger(__name__)
        logger.debug("rsync in_task_stage_in_wrapper start")
        if working_dir:
            os.makedirs(working_dir, exist_ok=True)

        logger.debug("rsync in_task_stage_in_wrapper calling rsync")
        r = os.system("rsync {hostname}:{permanent_filepath} {worker_filepath}".format(hostname=hostname,
                                                                                       permanent_filepath=file.path,
                                                                                       worker_filepath=file.local_path))
        if r != 0:
            raise RuntimeError("rsync returned {}, a {}".format(r, type(r)))
        logger.debug("rsync in_task_stage_in_wrapper calling wrapped function")
        result = func(*args, **kwargs)
        logger.debug("rsync in_task_stage_in_wrapper returned from wrapped function")
        return result
    return wrapper


def in_task_stage_out_wrapper(func, file, working_dir, hostname):
    def wrapper(*args, **kwargs):
        import logging
        logger = logging.getLogger(__name__)
        logger.debug("rsync in_task_stage_out_wrapper start")

        logger.debug("rsync in_task_stage_out_wrapper calling wrapped function")
        result = func(*args, **kwargs)
        logger.debug("rsync in_task_stage_out_wrapper returned from wrapped function, calling rsync")
        r = os.system("rsync {worker_filepath} {hostname}:{permanent_filepath}".format(hostname=hostname,
                                                                                       permanent_filepath=file.path,
                                                                                       worker_filepath=file.local_path))
        if r != 0:
            raise RuntimeError("rsync returned {}, a {}".format(r, type(r)))
        logger.debug("rsync in_task_stage_out_wrapper returned from rsync")
        return result
    return wrapper