#!/bin/bash

####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

# Exchange SSH keys.
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa
ssh-copy-id -i ~/.ssh/id_rsa -o 'IdentityFile ~/.ssh/shared_rsa' -o StrictHostKeyChecking=no -f worker1
ssh-copy-id -i ~/.ssh/id_rsa -o 'IdentityFile ~/.ssh/shared_rsa' -o StrictHostKeyChecking=no -f worker2

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Start HDFS/Spark main here

# bash
export JAVA_HOME="/usr/local/openjdk-8/jre"

export HDFS_NAMENODE_USER="root"
export HDFS_DATANODE_USER="root"
export HDFS_SECONDARYNAMENODE_USER="root"

# Check if NameNode is formatted. Format only if it's the first time.
if [ ! -d "/tmp/hadoop-data/dfs/namenode/current" ]; then
    echo "Formatting NameNode..."
    hdfs namenode -format -force -nonInteractive
fi

echo "Starting HDFS cluster (NameNode on main, DataNodes on workers)..."
# Start NameNode on main and DataNodes on worker1 and worker2 via SSH
$HADOOP_HOME/sbin/start-dfs.sh

echo "Starting Spark Master on main..."
${SPARK_HOME}/sbin/start-master.sh

echo "Starting Spark Worker on main..."
# The SPARK_MASTER_URL is read from spark-env.sh
${SPARK_HOME}/sbin/start-worker.sh spark://main:7077

# Keep the container running
tail -f /dev/null