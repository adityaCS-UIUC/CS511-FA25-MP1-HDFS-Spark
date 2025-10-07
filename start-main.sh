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

echo "Starting NameNode..."
$HADOOP_HOME/bin/hdfs --daemon start namenode

# Wait for namenode to be ready
sleep 5

echo "Starting DataNode on main..."
$HADOOP_HOME/bin/hdfs --daemon start datanode

echo "Starting DataNodes on workers via SSH..."
ssh worker1 "$HADOOP_HOME/bin/hdfs --daemon start datanode"
ssh worker2 "$HADOOP_HOME/bin/hdfs --daemon start datanode"

# Wait for datanodes to register
sleep 5

export SPARK_LOCAL_HOSTNAME=main
export SPARK_LOCAL_IP=$(getent hosts main | awk '{print $1}')

echo "Starting Spark Master on main..."
$SPARK_HOME/sbin/start-master.sh

# Wait for master to be ready
sleep 3

echo "Starting Spark Worker on main..."
$SPARK_HOME/sbin/start-worker.sh spark://main:7077

echo "Starting Spark Workers on worker1 and worker2..."
ssh worker1 "$SPARK_HOME/sbin/start-worker.sh spark://main:7077"
ssh worker2 "$SPARK_HOME/sbin/start-worker.sh spark://main:7077"

# Wait for workers to register
sleep 5

# Keep the container running
tail -f /dev/null