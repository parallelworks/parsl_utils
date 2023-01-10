from parsl.data_provider.files import File

from . import rsync
from . import gsutil


def PWFile(path, local_path, scheme, netloc = None):
    # Set isdir = True if the file is a directory!
    f = File(scheme + '://' + path)
    f.local_path = local_path
    f.path = path
    if netloc:
        f.netloc = netloc
    return f