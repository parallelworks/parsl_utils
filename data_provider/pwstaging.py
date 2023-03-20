import os

from parsl.utils import RepresentationMixin
from parsl.data_provider.staging import Staging


def url_to_local_path(file):
    """
    Returns the local_path using the url of a native File object since
    local_path is not working properly
    """
    if '#' in file.url:
        local_path = file.url.split('#')[1]
        if local_path:
            file.local_path = local_path
    
    return file

def add_working_dir_to_local_path(file, dm, executor):
    """
    Adds the executor's workdir as defined in the parsl config file to
    the file's local path

    Rsync remote name needs to include absolute path
    """
    if file.local_path is None:
        file.local_path = file.filename
    elif not os.path.isabs(file.local_path):
        working_dir = dm.dfk.executors[executor].working_dir
        if working_dir:
            file.local_path = os.path.join(working_dir, file.local_path)
        else:
            file.local_path = file.filename
    
    return file
    

# FIXME: Require that replace_task and replace_task_stage_out are implemented
class PWStaging(Staging, RepresentationMixin):
    """
    This is a modification of the official staging provider 
    https://parsl.readthedocs.io/en/latest/stubs/parsl.data_provider.rsync.RSyncStaging.html
    with two changes:
        1. Add -avzq option to rsync
        2. Make parent directory of file.path if it does not exist

    This staging provider will execute rsync on worker nodes
    to stage in files from a remote location.
    Worker nodes must be able to authenticate to the rsync server
    without interactive authentication - for example, worker
    initialization could include an appropriate SSH key configuration.
    The submit side will need to run an rsync-compatible server (for example,
    an ssh server with the rsync binary installed)
    """

    def __init__(self, scheme):
        self.scheme = scheme

    def can_stage_in(self, file):
        return file.scheme == self.scheme

    def can_stage_out(self, file):
        return file.scheme == self.scheme

    def stage_in(self, dm, executor, file, parent_fut):
        file = url_to_local_path(file)
        file = add_working_dir_to_local_path(file, dm, executor)        
        return None

    def stage_out(self, dm, executor, file, parent_fut):
        file = url_to_local_path(file)
        file = add_working_dir_to_local_path(file, dm, executor)        
        return None
    
    def replace_task(self, dm, executor, file, f):
        pass

    def replace_task_stage_out(self, dm, executor, file, f):
        pass

