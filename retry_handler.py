import json
#from . import resource_info


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


def get_retry_index(fail_count: int, len_retry_parameters: int) -> int:
    """
    Use the fail count to determine the retry_index. 
    The retry_index is used to access the current retry parameters.
    """
    if  fail_count <= len_retry_parameters:
        return fail_count-1
    else:
        # Use last item in retry_parameters for the remaining retries
        return -1


def log_task_record(func_name, fail_history):
    print('\nRetrying function {}'.format(func_name), flush = True)
    print('Fail history:', fail_history,flush = True)
    """
    FIXME: How do we properly display resource messages? We need to find the PW resource name
    with the Parsl resource label 
    """
    # print('Resource session messages:', flush = True)
    #rmsgs = resource_info.get_resource_messages(exec_conf[task_record['executor']]['POOL'])
    #[ print(msg, flush = True) for msg in rmsgs ]

def retry_handler(exception, task_record) -> int:
    func_name = fix_func_name(task_record['func_name'], task_record['kwargs'])
    log_task_record(func_name, task_record['fail_history'])
    # If no retry parameters are defined --> Retry function with the same parameters
    if 'retry_parameters' not in task_record['kwargs']:
        return 1

    if type(task_record['kwargs']['retry_parameters']) != list:
        print('ERROR: parameter retry_parameters was expected to be list and is type={rhctype}'.format(
            rhctype = str(type(task_record['kwargs']['retry_parameters']))
        ), flush = True)
        return 99999
    
    retry_index = get_retry_index(
        task_record['fail_count'], 
        len(task_record['kwargs']['retry_parameters'])
    )

    print('Resubmitting task with new parameters:', flush = True)
    print(retry_index, flush=True)
    print(json.dumps(task_record['kwargs']['retry_parameters'][retry_index], indent = 4), flush = True)
    # Only modify the parameters provided in the retry_parameters variable. Leave the others as is
    if 'executor' in task_record['kwargs']['retry_parameters'][retry_index]:
        task_record['executor'] = task_record['kwargs']['retry_parameters'][retry_index]['executor']

    if 'args' in task_record['kwargs']['retry_parameters'][retry_index]:
        task_record['args'] = task_record['kwargs']['retry_parameters'][retry_index]['args']
    
    if 'kwargs' in task_record['kwargs']['retry_parameters'][retry_index]:
        for aname,aval in task_record['kwargs']['retry_parameters'][retry_index]['kwargs'].items():
            task_record['kwargs'][aname] = aval
                
    return 1