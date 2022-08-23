import json
import sys
import os
import requests
from time import sleep
import logging
from random import randint

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


def get_available_port_pairs(port_1, used_ports):
    port_2 = port_1 + 1
    while port_1 in used_ports or port_2 in used_ports:
        port_1 +=1
        port_2 = port_1 + 1
    return port_1, port_2

if __name__ == '__main__':
    exec_conf_json = sys.argv[1]
    used_ports_txt = sys.argv[2]

    # To minize collision chances use randint
    start_port = 55200 + randint(0, 200)

    with open(used_ports_txt) as fp:
        used_ports = [ int(port) for port in fp.readlines() ]

    logger.info('Used ports: {}'.format(' '. join([ str(p) for p in used_ports])))

    with open(exec_conf_json, 'r') as f:
        exec_conf = json.load(f)

    for exec_label, exec_conf_i in exec_conf.items():
        if 'HOST_IP' not in exec_conf[exec_label]:
            exec_conf[exec_label]['HOST_IP'] = get_master_node_ip(exec_conf_i['POOL'])

        exec_conf[exec_label]['WORKER_PORT_1'], exec_conf[exec_label]['WORKER_PORT_2'] = get_available_port_pairs(start_port, used_ports)
        used_ports += [exec_conf[exec_label]['WORKER_PORT_1'], exec_conf[exec_label]['WORKER_PORT_2']]

        if 'HOST_USER' not in exec_conf[exec_label]:
            exec_conf[exec_label]['HOST_USER'] = os.environ['PW_USER']

    with open(sys.argv[1], 'w') as fp:
        json.dump(exec_conf, fp, indent = 4)