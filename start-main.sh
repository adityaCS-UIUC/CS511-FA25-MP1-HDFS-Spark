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
export JAVA_HOME="/usr/local/openjdk-8/jre"
export HDFS_NAMENODE_USER="root"
export HDFS_DATANODE_USER="root"
export HDFS_SECONDARYNAMENODE_USER="root"

# Check if NameNode is formatted. Format only if it's the first time.
if [ ! -d "/tmp/hadoop-data/dfs/namenode/current" ]; then
    echo "Formatting NameNode..."
    hdfs namenode -format -force -nonInteractive
fi

echo "Starting NameNode on main..."
$HADOOP_HOME/bin/hdfs --daemon start namenode

# Wait for namenode to be ready
echo "Waiting for NameNode to be fully ready..."
sleep 10

echo "Starting DataNode on main..."
$HADOOP_HOME/bin/hdfs --daemon start datanode

# Wait for datanode to register
sleep 5

export SPARK_LOCAL_HOSTNAME=main
export SPARK_LOCAL_IP=$(getent hosts main | awk '{print $1}')

echo "Starting Spark Master on main..."
$SPARK_HOME/sbin/start-master.sh

# Wait for master to be ready
echo "Waiting for Spark Master to be fully ready..."
sleep 5

echo "Starting Spark Worker on main..."
$SPARK_HOME/sbin/start-worker.sh spark://main:7077

# Wait for worker to register
sleep 5

echo "HDFS and Spark services started on main."
echo "Workers will start their own DataNodes and Spark Workers."

# Give workers time to start their services
sleep 10

echo "Checking cluster status..."
echo "HDFS DataNodes:"
$HADOOP_HOME/bin/hdfs dfsadmin -report 2>&1 | grep -A 1 "Live datanodes"

# Keep the container running
tail -f /dev/null