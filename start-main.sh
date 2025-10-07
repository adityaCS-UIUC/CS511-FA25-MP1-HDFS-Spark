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

export SPARK_LOCAL_HOSTNAME=main
export SPARK_LOCAL_IP=$(getent hosts main | awk '{print $1}')

echo "Starting HDFS cluster (NameNode on main, DataNodes on workers)..."
# Start NameNode on main and DataNodes on worker1 and worker2 via SSH
$HADOOP_HOME/sbin/start-dfs.sh

echo "Starting Spark cluster (Master on main, Workers on workers)..."
# Start Spark Master on main and Workers on worker1 and worker2
$SPARK_HOME/sbin/start-master.sh
$SPARK_HOME/sbin/start-workers.sh 

# Start datanode on main as well
$HADOOP_HOME/bin/hdfs datanode &

# Keep the container running
tail -f /dev/null
