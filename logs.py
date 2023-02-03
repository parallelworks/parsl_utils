import logging
import os

def get_logger(log_file, name):
    os.makedirs(os.path.dirname(log_file), exist_ok = True)
    
    logging.basicConfig(
        filename = log_file,
        format = '%(asctime)s %(levelname)-8s %(message)s',
        datefmt ='%Y-%m-%d %H:%M:%S',
        level = logging.INFO
    )
    return logging.getLogger(name)