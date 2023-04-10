import os
from parsl.data_provider.files import File

from . import rsync
from . import gsutil
from . import s3

def PWFile(url, local_path):
    if '://' in url:
        f = File(url + '#' + local_path)
    elif os.path.isabs(url):
        f = File('file://usercontainer' + url + '#' + local_path)
    else:
        f = File(
            'file://usercontainer' + os.path.join(
                os.getcwd(),
                url
            ) + '#' + local_path
        )
    # This information is lost along the way
    f.local_path = local_path
    return f
