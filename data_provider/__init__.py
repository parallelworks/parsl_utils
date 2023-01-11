from parsl.data_provider.files import File as ParslFile

from . import rsync
from . import gsutil
from . import files

def File(url, local_path):
    """
    Wrapper around Parsl native File object. The local_path (worker_path) 
    attribute is lost in the Parsl native object so here this information
    is added to the url
    """
    f = ParslFile(url + '#' + local_path)
    # This information is lost along the way
    f.local_path = local_path
    return f