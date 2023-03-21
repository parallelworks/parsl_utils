import uuid
from . import pwstaging

def get_stage_cmd(origin, destination):
    if origin.endswith('/') or destination.endswith('/'):
        cmd = "aws s3 sync {origin} {destination}"
    else:
        cmd = "aws s3 cp {origin} {destination}"
        
    cmd = cmd.format(
        origin = origin, 
        destination = destination
    )
    return cmd


class PWS3(pwstaging.PWStaging):
    """
    This staging provider will execute aws s3 commands on worker nodes
    to stage in files from an AWS bucket.
    Worker nodes must be able to authenticate with AWS

    It will not handle authentication with AWS. It assumes the nodes 
    are already authenticated.
    """

    def __init__(self):
        super().__init__('s3')

    def replace_task(self, dm, executor, file, f):
        working_dir = dm.dfk.executors[executor].working_dir
        cmd = get_stage_cmd(origin = file.url, destination = file.local_path)
        short_id = str(uuid.uuid3(uuid.NAMESPACE_URL, cmd))[:8]
        self.logger.debug(f'{short_id} Replacing task for command <{cmd}>')
        return pwstaging.in_task_stage_in_cmd_wrapper(f, file, working_dir, cmd, self.logger)

    def replace_task_stage_out(self, dm, executor, file, f):
        working_dir = dm.dfk.executors[executor].working_dir
        cmd = get_stage_cmd(origin = file.local_path, destination = file.url)
        short_id = str(uuid.uuid3(uuid.NAMESPACE_URL, cmd))[:8]
        self.logger.debug(f'{short_id} Replacing task for command <{cmd}>')
        return pwstaging.in_task_stage_out_cmd_wrapper(f, file, working_dir, cmd, self.logger)
    