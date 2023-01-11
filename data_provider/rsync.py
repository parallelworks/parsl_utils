import logging
import os

from parsl.utils import RepresentationMixin
from parsl.data_provider.staging import Staging

from . import utils

logger = logging.getLogger(__name__)


class PWRSyncStaging(Staging, RepresentationMixin):
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
        file = utils.fix_local_path(f)

        if file.local_path is None:
            file.local_path = file.filename
        elif not os.path.isabs(file.local_path):
            working_dir = dm.dfk.executors[executor].working_dir
            if working_dir:
                file.local_path = os.path.join(working_dir, file.local_path)
            else:
                file.local_path = file.filename
        
        return None

    def stage_out(self, dm, executor, file, parent_fut):

        file.path = os.path.abspath(file.path)
        file = utils.fix_local_path(f)

        if file.local_path is None:
            file.local_path = file.filename
        elif not os.path.isabs(file.local_path):
            working_dir = dm.dfk.executors[executor].working_dir
            if working_dir:
                file.local_path = os.path.join(working_dir, file.local_path)
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
        cmd = "rsync -avzq {hostname}:{permanent_filepath} {worker_filepath}".format(
            hostname=hostname,
            permanent_filepath=file.path,
            worker_filepath=file.local_path
        )
        r = os.system(cmd)
        if r != 0:
            # raise RuntimeError("rsync command {} returned {}, a {}".format(cmd, r, type(r)))
            logger.info("rsync command <{}> returned {}, a {}".format(cmd, r, type(r)))
            
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
        cmd = "rsync -avzq --rsync-path=\"mkdir -p {root_path} && rsync\" {worker_filepath} {hostname}:{permanent_filepath}".format(
            hostname=hostname,
            permanent_filepath=file.path,
            worker_filepath=file.local_path,
            root_path = os.path.dirname(file.path)
        )

        r = os.system(cmd)
        if r != 0:
            # raise RuntimeError("rsync command <{}> returned {}, a {}".format(cmd, r, type(r)))
            logger.info("rsync command <{}> returned {}, a {}".format(cmd, r, type(r)))
            
        logger.debug("rsync in_task_stage_out_wrapper returned from rsync")
        return result
    return wrapper
