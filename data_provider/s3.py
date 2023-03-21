import logging
import os

from . import pwstaging

logger = logging.getLogger(__name__)

def get_stage_in_cmd(file):
    if file.path.endswith('/'):
        cmd = "aws s3 sync s3:/{permanent_filepath} {worker_filepath}"
    else:
        cmd = "aws s3 cp s3:/{permanent_filepath} {worker_filepath}"
        
    cmd = cmd.format(
        permanent_filepath = file.path, 
        worker_filepath = file.local_path
    )
    return cmd


def get_stage_out_cmd(file):
    if file.path.endswith('/'):
        cmd = "aws s3 sync {worker_filepath} s3:/{permanent_filepath}"
    else:
        cmd = "aws s3 cp {worker_filepath} s3:/{permanent_filepath}"

    cmd = cmd.format(
        permanent_filepath = file.path,
        worker_filepath = file.local_path,
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
        logger.debug("Replacing task for aws s3 stagein")
        working_dir = dm.dfk.executors[executor].working_dir
        return pwstaging.in_task_stage_in_wrapper(f, file, working_dir, get_stage_in_cmd)

    def replace_task_stage_out(self, dm, executor, file, f):
        logger.debug("Replacing task for aws s3 stageout")
        working_dir = dm.dfk.executors[executor].working_dir
        return pwstaging.in_task_stage_out_wrapper(f, file, working_dir, get_stage_out_cmd)
    