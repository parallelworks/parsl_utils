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
        self.logger.debug("Replacing task for aws s3 stagein")
        working_dir = dm.dfk.executors[executor].working_dir
        cmd = get_stage_cmd(origin = file.url, destination = file.local_path)
        return pwstaging.in_task_stage_in_cmd_wrapper(f, file, working_dir, cmd, self.logger)

    def replace_task_stage_out(self, dm, executor, file, f):
        self.logger.debug("Replacing task for aws s3 stageout")
        working_dir = dm.dfk.executors[executor].working_dir
        cmd = get_stage_cmd(origin = file.local_path, destination = file.url)
        return pwstaging.in_task_stage_out_cmd_wrapper(f, file, working_dir, cmd, self.logger)
    