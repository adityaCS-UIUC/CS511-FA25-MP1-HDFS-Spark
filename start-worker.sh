#!/bin/bash
####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa
# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

export JAVA_HOME=/usr/local/openjdk-8
export HDFS_DATANODE_USER="root"

# Wait for namenode to be ready
sleep 15

# Start DataNode - use full path and explicit logging
echo "Starting DataNode on $(hostname)..."
/opt/hadoop/bin/hdfs --daemon start datanode

# Wait for datanode to initialize
sleep 10

# Start Spark Worker (keeping your working code)
echo "Starting Spark Worker on $(hostname)..."
export SPARK_LOCAL_HOSTNAME=$(hostname)
export SPARK_LOCAL_IP=$(getent hosts $(hostname) | awk '{print $1}')
/opt/spark/sbin/start-worker.sh spark://main:7077

# Wait for worker to register
sleep 5

# Keep the container running
tail -f /dev/null