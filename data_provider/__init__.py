from parsl.data_provider.files import File

from . import rsync
from . import gsutil
from . import files


def PWFile(path, local_path, scheme, netloc):
    if netloc.startswith('/'):
        raise Exception('ERROR: netloc cannot start with /')

    url = scheme + '://' + netloc + '/' + path
    f = File(url)
    f.local_path = local_path
    return f