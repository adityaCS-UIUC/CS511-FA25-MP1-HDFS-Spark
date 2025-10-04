#!/bin/bash

####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Start HDFS/Spark worker here
export JAVA_HOME="/usr/local/openjdk-8/jre"

export SPARK_LOCAL_HOSTNAME=$(hostname)
export SPARK_LOCAL_IP=$(getent hosts $(hostname) | awk '{print $1}')

/opt/spark/sbin/start-worker.sh --host "$(hostname)" spark://main:7077

export HDFS_DATANODE_USER="root"
# bash
echo "Starting DataNode..."
# Start the DataNode service
$HADOOP_HOME/sbin/hadoop-daemon.sh start datanode

# Keep the container running
tail -f /dev/null