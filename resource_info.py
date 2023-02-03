import json
import os
import requests
from time import sleep
import logging
import glob

log_file = os.path.join('logs', os.path.basename(__file__).replace('py', 'log'))
logger = logs.get_logger(log_file, 'resource_info')

## NOTES:
# NO PRINT STATEMENTS ALLOWED!!
# PARSL WONT WORK WITH POOLNAME.CLUSTERS.PW!!

# URLs
url_resources = 'https://' + os.environ['PARSL_CLIENT_HOST'] +"/api/resources?key=" + os.environ['PW_API_KEY']

def get_pool_info(pool_name, url_resources = url_resources, retries = 3):
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
def get_master_node_ip(pool_name, url_resources = url_resources):


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



def get_resource_messages(pool_name):
    session_number = get_latest_session(pool_name)
    pool_info = get_pool_info(pool_name)
    pool_id = pool_info['id']
    url_msg = 'https://' + os.environ['PARSL_CLIENT_HOST'] +'/api/v2/resources/' + pool_id + '/sessions/' + str(session_number) + '/messages'
    logger.info('Messages URL=<{}>'.format(url_msg))
    res = requests.get(url_msg)
    print(res.json())
    return [ i['message'] for i in res.json() if 'message' in i]


if __name__ == '__main__':
    pool_name = 'gcpslurmv2fail'
    a = get_resource_messages(pool_name)
    [ print(i) for i in a ]