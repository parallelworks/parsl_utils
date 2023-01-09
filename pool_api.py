import requests
import os
import json
import sys

supported_pool_types = ['gclusterv2', 'pclusterv2',
                        'azclusterv2', 'awsclusterv2', 'slurmshv2']


def get_pool_info(pool_name):

    url_resources = 'https://' + \
        os.environ['PARSL_CLIENT_HOST'] + \
        "/api/resources?key=" + os.environ['PW_API_KEY']

    res = requests.get(url_resources)
    pool_info = {}

    for pool in res.json():
        if type(pool['name']) == str:
            if pool['type'] in supported_pool_types:
                if pool['name'].lower().replace('_', '') == pool_name.lower().replace('_', ''):
                    return pool
    raise (Exception(
        'Pool {} not found. Make sure the pool type is supported!'.format(pool_name)))


def get_pool_workdir(pool_name):
    pool_info = get_pool_info(pool_name)
    coaster_properties = json.loads(pool_info['coasterproperties'])
    if 'workdir' in coaster_properties:
        return coaster_properties['workdir']
    else:
        return os.path.expanduser('~')


if __name__ == '__main__':
    pool_name = sys.argv[1]
    pool_prop = sys.argv[2]

    pool_info = get_pool_info(pool_name)
    coaster_properties = json.loads(pool_info['coasterproperties'])
    if pool_prop == "type":
        print(pool_info['type'])
    elif pool_prop == "workdir":
        if 'workdir' in coaster_properties:
            print(coaster_properties['workdir'])
        else:
            print(os.path.expanduser('~'))
    elif pool_prop == "status":
        print(pool_info['status'])
    elif pool_prop == "internalIp":
        if 'internalIp' in coaster_properties:
            print(coaster_properties['internalIp'])
    else:
        msg = 'Pool property <{}> is not supported!'.format(pool_prop)
        raise (Exception(msg))
