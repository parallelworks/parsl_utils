import json
import os

from . import logs
"""
from . import resource_info
FIXME: How do we properly display resource messages? We need to find the PW resource name
with the Parsl resource label 
print('Resource session messages:', flush = True)
rmsgs = resource_info.get_resource_messages(exec_conf[task_record['executor']]['POOL'])
[ print(msg, flush = True) for msg in rmsgs ]
"""


log_file = os.path.join('logs', os.path.basename(__file__).replace('py', 'log'))
logger = logs.get_logger(log_file, 'retry_handler')

# FIXNME: Improve logging
def fix_func_name(func_name: str, task_kwargs: dict) -> str:
    """
    These function is needed if the walltime parameter is set in the parsl app
    #        because of this issue in Parsl https://github.com/Parsl/parsl/issues/2449
    """
    if func_name == 'wrapper':
        if 'func_name' in task_kwargs:
            func_name = task_kwargs['func_name']
    return func_name


def retry_handler(exception, task_record) -> int:
    func_name = fix_func_name(task_record['func_name'], task_record['kwargs'])
    logger.info('Retrying failed task {task_record}'.format(
        task_record = json.dumps(
            task_record,
            default = str, 
            indent = 4,
            sort_keys = True
        )
    ))
    # If no retry parameters are defined --> Retry task with the same parameters
    if 'retry_parameters' not in task_record['kwargs']:
        return 1
    
    # If no more parameter replacements are defined for current retry --> Retry task with the same parameters
    if  task_record['fail_count'] > len(task_record['kwargs']['retry_parameters']):
        return 1
    
    # If retry_parameters is None or empty
    if not task_record['kwargs']['retry_parameters']:
        return 1

    if type(task_record['kwargs']['retry_parameters']) != list:
        logger.error('Parameter retry_parameters was expected to be list and is type={rhctype}'.format(
            rhctype = str(type(task_record['kwargs']['retry_parameters']))
        ), flush = True)
        return 99999
    
    retry_index = task_record['fail_count'] - 1

    # Only modify the parameters provided in the retry_parameters variable. Leave the others as is
    if 'executor' in task_record['kwargs']['retry_parameters'][retry_index]:
        task_record['executor'] = task_record['kwargs']['retry_parameters'][retry_index]['executor']

    if 'args' in task_record['kwargs']['retry_parameters'][retry_index]:
        task_record['args'] = task_record['kwargs']['retry_parameters'][retry_index]['args']
    
    if 'kwargs' in task_record['kwargs']['retry_parameters'][retry_index]:
        for aname,aval in task_record['kwargs']['retry_parameters'][retry_index]['kwargs'].items():
            task_record['kwargs'][aname] = aval

    logger.info('Updated task record {task_record}'.format(
        task_record = json.dumps(
            task_record,
            default = str, 
            indent = 4,
            sort_keys = True
        )
    ))
                
    return 1