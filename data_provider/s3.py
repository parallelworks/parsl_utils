import logging
import os

from . import pwstaging

logger = logging.getLogger(__name__)


class PWS3(pwstaging.PWStaging):
    """
    This staging provider will execute aws s3 commands on worker nodes
    to stage in files from an AWS bucket.
    Worker nodes must be able to authenticate with AWS

    It will not handle authentication with AWS. It assumes the nodes 
    are already authenticated.
    """

    def __init__(self):
        super().__init__('gs')

    def replace_task(self, dm, executor, file, f):
        logger.debug("Replacing task for aws s3 stagein")
        working_dir = dm.dfk.executors[executor].working_dir
        return in_task_stage_in_wrapper(f, file, working_dir)

    def replace_task_stage_out(self, dm, executor, file, f):
        logger.debug("Replacing task for aws s3 stageout")
        working_dir = dm.dfk.executors[executor].working_dir
        return in_task_stage_out_wrapper(f, file, working_dir)


def in_task_stage_in_wrapper(func, file, working_dir):
    def wrapper(*args, **kwargs):
        import logging
        logger = logging.getLogger(__name__)
        logger.debug("s3 in_task_stage_in_wrapper start")
        if working_dir:
            os.makedirs(working_dir, exist_ok=True)
        
        local_path_dir = os.path.dirname(file.local_path)
        if local_path_dir:
            os.makedirs(local_path_dir, exist_ok=True)

        logger.debug("s3 in_task_stage_in_wrapper calling aws s3")
        if file.path.endswith('/'):
            cmd = "aws s3 sync s3:/{permanent_filepath} {worker_filepath}"
        else:
            cmd = "aws s3 cp s3:/{permanent_filepath} {worker_filepath}"
        
        cmd = cmd.format(
            permanent_filepath = file.path, 
            worker_filepath = file.local_path
        )
        
        logger.debug(cmd)
        
        r = os.system(cmd)

        if r != 0:
            raise RuntimeError("aws s3 command <{}> returned {}, a {}".format(cmd, r, type(r)))

        logger.debug("aws s3 in_task_stage_in_wrapper calling wrapped function")
        result = func(*args, **kwargs)
        logger.debug("aws s3 in_task_stage_in_wrapper returned from wrapped function")
        return result
    return wrapper


def in_task_stage_out_wrapper(func, file, working_dir):
    def wrapper(*args, **kwargs):
        import logging
        logger = logging.getLogger(__name__)

        logger.debug("aws s3 in_task_stage_out_wrapper calling wrapped function")
        result = func(*args, **kwargs)
        logger.debug("aws s3 in_task_stage_out_wrapper returned from wrapped function, calling aws s3")
        
        if file.path.endswith('/'):
            cmd = "aws s3 sync {worker_filepath} s3:/{permanent_filepath}"
        else:
            cmd = "aws s3 cp {worker_filepath} s3:/{permanent_filepath}"

        cmd = cmd.format(
            permanent_filepath = file.path,
            worker_filepath = file.local_path,
        )

        logger.debug(cmd)

        r = os.system(cmd)

        if r != 0:
            raise RuntimeError("aws s3 command <{}> returned {}, a {}".format(cmd, r, type(r)))
        logger.debug("aws s3 in_task_stage_out_wrapper returned from aws s3")
        return result
    return wrapper