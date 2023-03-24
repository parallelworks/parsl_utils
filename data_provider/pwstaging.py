import os
import uuid
import logging

from parsl.utils import RepresentationMixin
from parsl.data_provider.staging import Staging

formatter = logging.Formatter('%(asctime)s %(levelname)-8s %(message)s')

def get_logger(log_file, name, level = logging.INFO):
    #os.makedirs(os.path.dirname(log_file), exist_ok = True)
    handler = logging.FileHandler(log_file)
    handler.setFormatter(formatter)
    logger = logging.getLogger(name)
    logger.setLevel(level)
    logger.addHandler(handler)
    return logging.getLogger(name)


def url_to_local_path(file):
    """
    Returns the local_path using the url of a native File object since
    local_path is not working properly

    Also removes everything after # from the url
    """
    if '#' in file.url:
        local_path = file.url.split('#')[1]
        if local_path:
            file.local_path = local_path
    
    file.url = file.url.split('#')[0]
    
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
    The original staging provider was generalized to act as a parent class for PW staging providers
    """
    def __init__(self, scheme, executor_label, logging_level = logging.DEBUG):
        self.scheme = scheme
        self.executor_label = executor_label
        self.logger = get_logger(f'{executor_label}/data_provider.log', executor_label, level = logging_level)

    def _set_task_logger(self, cmd, working_dir):
        # Get unique id for each command
        cmd_id = str(uuid.uuid3(uuid.NAMESPACE_URL, cmd))
        self.logger.info(f'Replacing task for command <{cmd}> with id <{cmd_id}>')
        # FIXME: Save all these logs in the data_transfer directory
        # Uses same level as the self.logger
        return get_logger(f'{working_dir}/{cmd_id}.log', cmd_id, level = self.logger.getEffectiveLevel())

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


def in_task_stage_in_cmd_wrapper(func, file, working_dir, cmd, logger):
    def wrapper(*args, **kwargs):
        logger.info(f'Running command')
        if working_dir:
            os.makedirs(working_dir, exist_ok=True)
        
        local_path_dir = os.path.dirname(file.local_path)
        if local_path_dir:
            os.makedirs(local_path_dir, exist_ok=True)

        r = os.system(cmd)
        if r != 0:
            logger.error('Command returned {}, a {}'.format(r, type(r)))
            #raise RuntimeError("command {} returned {}, a {}".format(cmd, r, type(r)))

        logger.debug(f'Command executed successfully')
        logger.debug(f'Calling wrapped function')
        result = func(*args, **kwargs)
        logger.debug(f'Wrapped function returned')

        return result
    return wrapper


def in_task_stage_out_cmd_wrapper(func, file, working_dir, cmd, logger):
    def wrapper(*args, **kwargs):
        logger.info(f'Running command')
        logger.debug(f'Calling wrapped function')
        result = func(*args, **kwargs)
        logger.debug(f'Wrapped function returned')

        r = os.system(cmd)
        
        if r != 0:
            logger.error('Command returned {}, a {}'.format(r, type(r)))
            # raise RuntimeError("command <{}> returned {}, a {}".format(cmd, r, type(r)))

        logger.debug(f'Command executed successfully')

        return result
    return wrapper
