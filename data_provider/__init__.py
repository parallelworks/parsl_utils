from parsl.data_provider.files import File

from . import rsync
from . import gsutil


def PWFile(url, local_path):
    f = File(url + '#' + local_path)
    # This information is lost along the way
    f.local_path = local_path
    return f