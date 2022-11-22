#!/bin/bash
job_number=__job_number__
# WARNING: kill.sh is not always called from /pw/jobs/<job_number> !!
# https://github.com/parallelworks/issues/issues/535
pudir=/pw/jobs/${job_number}/parsl_utils
cd /pw/jobs/${job_number}

##########################
# CLEAN REMOTE EXECUTORS #
##########################
bash ${pudir}/clean_resources.sh &> /pw/jobs/${job_number}/logs/clean_resources.out

#########################
# CLEAN LOCAL PROCESSES #
#########################

# Make super sure python process dies:
# - Also the monitoring is killed here!
python_pid=$(ps -x | grep  ${job_number} | grep python | awk '{print $1}')
if ! [ -z "${python_pid}" ]; then
    echo "Killing remaining python process ${python_pid}" >> /pw/jobs/${job_number}/logs/killed_pids.log
    kill ${python_pid}
fi
