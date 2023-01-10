import logging
import os

from parsl.utils import RepresentationMixin
from parsl.data_provider.staging import Staging

logger = logging.getLogger(__name__)


class PWGsutil(Staging, RepresentationMixin):
    """
    This staging provider will execute gsutil on worker nodes
    to stage in files from a GCP bucket.
    Worker nodes must be able to authenticate with GCP
    """

    def __init__(self):
        pass

    def can_stage_in(self, file):

        return file.scheme == 'gs' or file.scheme == 'gs-dir'

    def can_stage_out(self, file):
        return file.scheme == 'gs' or file.scheme == 'gs-dir'

    def stage_in(self, dm, executor, file, parent_fut):

        working_dir = dm.dfk.executors[executor].working_dir

        if working_dir:
            file.local_path = os.path.join(working_dir, file.filename)
        else:
            file.local_path = file.filename

        return None

    def stage_out(self, dm, executor, file, parent_fut):

        working_dir = dm.dfk.executors[executor].working_dir

        if working_dir:
            file.local_path = os.path.join(working_dir, file.filename)
        else:
            file.local_path = file.filename

        return None

    def replace_task(self, dm, executor, file, f):
        logger.debug("Replacing task for gsutil stagein")
        working_dir = dm.dfk.executors[executor].working_dir
        return in_task_stage_in_wrapper(f, file, working_dir)

    def replace_task_stage_out(self, dm, executor, file, f):
        logger.debug("Replacing task for gsutil stageout")
        working_dir = dm.dfk.executors[executor].working_dir
        return in_task_stage_out_wrapper(f, file, working_dir)


def in_task_stage_in_wrapper(func, file, working_dir):
    def wrapper(*args, **kwargs):
        import logging
        logger = logging.getLogger(__name__)
        logger.debug("gsutil in_task_stage_in_wrapper start")
        if working_dir:
            os.makedirs(working_dir, exist_ok=True)

        logger.debug("gsutil in_task_stage_in_wrapper calling gsutil")
        if file.scheme == 'gs-dir':
            cmd = "gsutil -m rsync -r gs://{permanent_filepath} {worker_filepath}"
        else:
            cmd = "gsutil -m cp -r gs://{permanent_filepath} {worker_filepath}"
        
        cmd.format(
            permanent_filepath = file.path, 
            worker_filepath = file.local_path
        )
        
        logger.debug(cmd)
        
        r = os.system(cmd)

        if r != 0:
            raise RuntimeError("gsutil command <{}> returned {}, a {}".format(cmd, r, type(r)))

        logger.debug("gsutil in_task_stage_in_wrapper calling wrapped function")
        result = func(*args, **kwargs)
        logger.debug("gsutil in_task_stage_in_wrapper returned from wrapped function")
        return result
    return wrapper


def in_task_stage_out_wrapper(func, file, working_dir):
    def wrapper(*args, **kwargs):
        import logging
        logger = logging.getLogger(__name__)
        logger.debug("gsutil in_task_stage_out_wrapper start")

        logger.debug("gsutil in_task_stage_out_wrapper calling wrapped function")
        result = func(*args, **kwargs)
        logger.debug("gsutil in_task_stage_out_wrapper returned from wrapped function, calling gsutil")
        
        if file.scheme == 'gs-dir':
            cmd = "gsutil -m rsync -r {worker_filepath} gs://{permanent_filepath}"
        else:
            cmd = "gsutil -m cp -r {worker_filepath} gs://{permanent_filepath}"

        cmd.format(
            permanent_filepath = file.path,
            worker_filepath = file.local_path,
        )

        logger.debug(cmd)

        r = os.system(cmd)

        if r != 0:
            raise RuntimeError("gsutil command <{}> returned {}, a {}".format(cmd, r, type(r)))
        logger.debug("gsutil in_task_stage_out_wrapper returned from gsutil")
        return result
    return wrapper