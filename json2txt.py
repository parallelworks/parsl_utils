import json
import sys

# Converts executor.json to multiline file where each line has the information corresponding to an executor label
# Converts:
# {
#     "executor": {
#         "POOL": "gcpclustergen2",
#         "REMOTE_CONDA_ENV": "parsl_py39",
#         "REMOTE_CONDA_DIR": "/contrib/Alvaro.Vidal/miniconda3"
#     }
# }
# To:
# LABEL=executor POOL=gcpclustergen2 REMOTE_CONDA_ENV=parsl_py39 REMOTE_CONDA_DIR=/contrib/Alvaro.Vidal/miniconda3
# JSON data structure enforces unique labels

def json2txt(fjson):
    with open(fjson, 'r') as f:
        exec_conf = json.load(f)

    for exec_label, exec_conf in exec_conf.items():
        # Configuration ready to be exported to bash
        bash_export = ['LABEL=' + exec_label]
        for eck, ecv in exec_conf.items():
            bash_export.append(eck + '=' + str(ecv))
        print(' '.join(bash_export))


def _line2dict(line):
    d = {}
    for word in line.split(' '):
        key,val = word.split('=')
        d[key] = val

    return d


def txt2json(ftxt):
    executors = {}

    with open(ftxt) as f:
        for line in f:
            ld = _line2dict(line.rstrip())
            ename = ld['LABEL']
            del ld['LABEL']
            executors[ename] = ld

    print(json.dumps(executors, indent = 4))



if __name__ == '__main__':
    if sys.argv[1].endswith('.json'):
        json2txt(sys.argv[1])
    else:
        txt2json(sys.argv[1])