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

with open(sys.argv[1], 'r') as f:
    exec_conf = json.load(f)


for exec_label, exec_conf in exec_conf.items():
    # Configuration ready to be exported to bash
    bash_export = ['LABEL=' + exec_label]
    for eck, ecv in exec_conf.items():
        bash_export.append(eck + '=' + str(ecv))
    print(' '.join(bash_export))
