# Native Parsl Utils
This repo contains helper scripts for running native/official Parsl in cluster pools on the PW platform. These scripts are considered temporary ad-hoc code that should be better integrated on the platform and were develeped to temporarily address the issues below:

### 1. Conda Environment:
Workflows needs to run in a specific conda environment which needs to be installed and accessible on the user container and on the head node of the cluster. The scripts `main_wrapper.py` and `main_wrapper.sh` are used to activate the environment on the PW platform before running the workflow. The `workflow.xml` executes the python wrapper `<command interpreter='parsl'>main_wrapper.py</command>` using the parsl interpreter that executes python in the default conda environment. The `main_wrapper.py` script redirects the arguments to the `main_wrapper.sh` script that activates the right conda environment and checks that it is installed and available on the user container and on the head node of the cluster. The `main_wrapper.py` could be avoided with a `bash` workflow interpreter. I think we should support either one native parsl environment or a bring your own conda environment(s) approach.

### 2. Tunnels:

### 3. Staging: