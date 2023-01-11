
def fix_local_path(f):
    """
    Returns the local_path using the url of a native File object since
    local_path is not working properly
    """

    if '#' in f.url:
        local_path = f.url.split('#')[1]
        if local_path:
            f.local_path = local_path
    return f
    