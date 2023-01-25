import sys
import json
import errno
import os
import signal
import functools
import traceback


def log_app(func):
    def wrapper(*args, **kwargs):
        if args:
            args_str = [str(arg) for arg in args]
            print("\nARGS:\n{}".format(" ".join(args_str)), flush = True)

        if 'inputs' in kwargs:
            print('\nINPUTS:\n' + '\n'.join([str(v) for v in kwargs['inputs']]), flush = True)

        if 'inputs_dict' in kwargs:
            print('\nINPUTS DICT: \n' + json.dumps(kwargs['inputs_dict']), flush = True)

        if 'outputs' in kwargs:
            print('\nOUTPUTS:\n' + '\n'.join([str(v) for v in kwargs['outputs']]), flush = True)

        if 'outputs_dict' in kwargs:
            print('\nOUTPUTS DICT: \n' + json.dumps(kwargs['outputs_dict']), flush = True)

        if 'stdout' in kwargs:
            print('\nSTDOUT: ' + kwargs['stdout'], flush = True)

        if 'stderr' in kwargs:
            print('\nSTDERR: ' + kwargs['stderr'], flush = True)

        return func(*args, **kwargs)

    return wrapper


class RetryFuture:
    def __init__(self, app_wrapper, executors):
        self.executors = executors
        self.app_wrapper = app_wrapper

        # Submit app (initialize):
        print('\n\nRunning in executor {}'.format(self.executors[0]), flush = True)
        self.fut = self.app_wrapper(
            executor_name = self.executors[0]['executor']
        )(
            *self.executors[0]['args'],
            **self.executors[0]['kwargs']
        )

    def result(self):
        try:
            return self.fut.result()
        except:
            print(traceback.format_exc(), flush = True)
            for executor in self.executors[1:]:
                try:
                    print('\n\nRunning in executor {}'.format(executor), flush = True)
                    self.fut = self.app_wrapper(executor_name = executor['executor'])(
                        *executor['args'],
                        **executor['kwargs']
                    )
                    return self.fut.result()
                except Exception:
                    print(traceback.format_exc(), flush = True)

        raise Exception('App wrapper {} failed in all the executors'.format(self.app_wrapper))


# THESE DECORATORS ARE NOT NEEDED SINCE THE WALLTIME SPECIAL PARAMETER CAN BE USED IN THE PARSL APP DEFINITION
class TimeoutError(Exception):
    pass

def timeout(seconds_attr = None, error_message = os.strerror(errno.ETIME)):
    def decorator(func):
        def _handle_timeout(signum, frame):
            raise TimeoutError(error_message)

        @functools.wraps(func)
        def wrapper(*args, **kwargs):

            try:
                seconds = getattr(args[0], seconds_attr)
            except:
                raise(Exception('Attribute {} not found in {}'.format(seconds_attr, args[0])))

            signal.signal(signal.SIGALRM, _handle_timeout)
            signal.alarm(seconds)
            try:
                result = func(*args, **kwargs)
            finally:
                signal.alarm(0)
            return result

        return wrapper

    return decorator



class TimeoutFuture:
    def __init__(self, future, seconds):
        self.future = future
        self.seconds = seconds

    @timeout(seconds_attr = 'seconds')
    def result(self):
        return self.future.result()


def timeout_app(seconds = 57):
    def decorator(func):
        def wrapper(*args, **kwargs):
            fut = func(*args, **kwargs)
            return TimeoutFuture(fut, seconds)
        return wrapper
    return decorator
