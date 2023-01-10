import os 
from . import parsl_wrappers
from . import data_provider
from . import pool_api

if os.path.isfile('executors.json'):
    from . import config

if 'PARSL_CLIENT_HOST' in os.environ:
    # Only works if we are running parsl_utils in the user container
    from . import resource_info