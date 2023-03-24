import logging
from . import pwstaging

def get_stage_cmd(origin, destination):

    if origin.endswith('/') or destination.endswith('/'):
        cmd = "gsutil -m rsync -r {origin} {destination}"
    else:
        cmd = "gsutil -m cp -r {origin} {destination}"
        
    cmd = cmd.format(
        origin = origin, 
        destination = destination
    )

    return cmd


class PWGsutil(pwstaging.PWStaging):
    """
    This staging provider will execute gsutil on worker nodes
    to stage in files from a GCP bucket.
    Worker nodes must be able to authenticate with GCP

    It will not handle authentication with GCP. It assumes the nodes 
    are already authenticated.
    """

    def __init__(self, executor_label, logging_level = logging.INFO):
        self.executor_label = executor_label
        self.logging_level = logging_level
        super().__init__('gs', executor_label, logging_level = logging_level)

    def replace_task(self, dm, executor, file, f):
        working_dir = dm.dfk.executors[executor].working_dir
        cmd = get_stage_cmd(origin = file.url, destination = file.local_path)
        cmd_id = self._get_cmd_id(cmd)  
        return pwstaging.in_task_stage_in_cmd_wrapper(f, file, working_dir, cmd, cmd_id, self.logger.getEffectiveLevel())

    def replace_task_stage_out(self, dm, executor, file, f):
        working_dir = dm.dfk.executors[executor].working_dir
        cmd = get_stage_cmd(origin = file.local_path, destination = file.url)
        cmd_id = self._get_cmd_id(cmd)  
        return pwstaging.in_task_stage_out_cmd_wrapper(f, file, working_dir, cmd, cmd_id, self.logger.getEffectiveLevel())

