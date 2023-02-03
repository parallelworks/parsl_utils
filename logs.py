import logging
formatter = logging.Formatter('%(asctime)s %(levelname)-8s %(message)s')

import os

def get_logger(log_file, name, level = logging.INFO):
    os.makedirs(os.path.dirname(log_file), exist_ok = True)
    handler = logging.FileHandler(log_file)
    handler.setFormatter(formatter)
    logger = logging.getLogger(name)
    logger.setLevel(level)
    logger.addHandler(handler)
    return logging.getLogger(name)