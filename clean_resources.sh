pudir=$(dirname $0)
. ${pudir}/utils.sh

# This file is created by ${pudir}/prepare_resources.sh
if ! [ -f "exec_conf.export" ]; then
    python ${pudir}/loop_exec_conf.py executors.json > exec_conf.export
fi

# Cancel tunnel on the remote side only
while IFS= read -r exec_conf; do
    export ${exec_conf}
    ssh_cancel_tunnel_to_head_node ${HOST_IP} ${WORKER_PORT_1} ${WORKER_PORT_2}
done <   exec_conf.export
