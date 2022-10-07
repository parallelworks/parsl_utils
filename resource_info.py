import json
import os
import requests
from time import sleep
import logging
import glob


# NO PRINT STATEMENTS ALLOWED!!

# PARSL WONT WORK WITH POOLNAME.CLUSTERS.PW!!

logging.basicConfig(
    filename = os.path.join('logs', os.path.basename(__file__).replace('py', 'log')),
    format = '%(asctime)s %(levelname)-8s %(message)s',
    datefmt ='%Y-%m-%d %H:%M:%S',
    level = logging.INFO
)
logger = logging.getLogger()


def get_pool_info(pool_name, url_resources, retries = 3):
    while retries >= 0:
        res = requests.get(url_resources)
        for pool in res.json():
            # FIXME: BUG sometimes pool['name'] is None when you just started the pool
            if type(pool['name']) == str:
                if pool['name'].replace('_','') == pool_name.replace('_',''):
                    return pool
        logger.info('Retrying get_pool_info({}, {}, retries = {})'.format(pool_name, url_resources, str(retries)))
        sleep(3)
        retries += -1
    error_msg = 'Pool name not found response: ' + pool_name
    logger.error(error_msg)
    raise(Exception(error_msg))

# Get the IP of the master node in the pool
def get_master_node_ip(pool_name):

    url_resources = 'https://' + os.environ['PARSL_CLIENT_HOST'] +"/api/resources?key=" + os.environ['PW_API_KEY']

    while True:
        cluster = get_pool_info(pool_name, url_resources)

        if cluster['status'] == 'on':
            if 'masterNode' in cluster['state']:
                ip = cluster['state']['masterNode']
            else:
                ip = None

            if ip is None:
                logger.info('Waiting for cluster {} to get an IP'.format(pool_name))
            else:
                logger.info('Cluster {} IP: {}'.format(pool_name, ip))
                return ip
        else:
            logger.info('Waiting for cluster {} status to be on'.format(pool_name))
            logger.info('Cluster status: ' + cluster['status'])

        sleep(20)

def get_latest_session(pool_name):
    rdir = os.path.join('/pw/.pools/', os.environ['PW_USER'], pool_name, '[0-9][0-9][0-9][0-9][0-9]')
    return max([int(os.path.basename(i)) for i in glob.glob(rdir) if os.path.basename(i).isdigit() ])
