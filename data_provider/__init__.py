from parsl.data_provider.files import File

from . import rsync

def PWFile(path, local_path, scheme, netloc = None):
    f = File(scheme + '://' + path)
    f.local_path = local_path
    f.path = path
    if netloc:
        f.netloc = netloc
    return f