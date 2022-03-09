import json
from . import staging

stage_inputs = staging.stage_inputs
stage_outputs = staging.stage_outputs

# If you make it run on the remote side with Parsl App would it work with coasters too? NO, you don't know where an app runs

#def stage(data, host, io_type):
#    print(data, host, io_type)

class StageOutFuture:
    def __init__(self, future, outputs, host):
        self.future = future
        self.outputs = outputs
        self.host = host

    def result(self):
        result = self.future.result()
        stage_outputs(self.outputs, self.host)
        return result




def stage_app(host):
    def decorator(func):
        def wrapper(*args, **kwargs):
            if 'inputs_dict' in kwargs:
                stage_inputs(kwargs['inputs_dict'], host)

            fut = func(*args, **kwargs)

            if 'outputs_dict' in kwargs:
                return StageOutFuture(fut, kwargs['outputs_dict'], host)

            return fut
        return wrapper
    return decorator

def log_app(func):
    def wrapper(*args, **kwargs):
        if args:
            print("\nARGS:\n{}".format(" ".join(args)), flush = True)

        if 'inputs' in kwargs:
            print('\nINPUTS:\n' + '\n'.join([v.path for v in kwargs['inputs']]), flush = True)

        if 'inputs_dict' in kwargs:
            print('\nINPUTS DICT: \n' + json.dumps(kwargs['inputs_dict']), flush = True)

        if 'outputs' in kwargs:
            print('\nOUTPUTS:\n' + '\n'.join([v.path for v in kwargs['outputs']]), flush = True)

        if 'outputs_dict' in kwargs:
            print('\nOUTPUTS DICT: \n' + json.dumps(kwargs['outputs_dict']), flush = True)

        if 'stdout' in kwargs:
            print('\nSTDOUT: ' + kwargs['stdout'], flush = True)

        if 'stderr' in kwargs:
            print('\nSTDERR: ' + kwargs['stderr'], flush = True)

        return func(*args, **kwargs)

    return wrapper


@log_app
@stage_app('hooost')
def hello(cmd, inputs = [], outputs = [], inputs_dict = {}, outputs_dict = {}):
    print(cmd)
    print(inputs)
    print(outputs)
    return 0


#host = 'host'

if __name__ == '__main__':
    inputs_dict = {
        'type': 'file',
        'origin': 'lala',
        'destination': 'lolo'
    }

    out = hello('echo hello', inputs_dict = inputs_dict, outputs_dict = inputs_dict)
    print(out)