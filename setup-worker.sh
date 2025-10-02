#!/bin/bash
set -euo pipefail
export JAVA_HOME=/usr/local/openjdk-8

####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Setup HDFS/Spark worker here
# Hadoop config mirrors main (fs.defaultFS points to main)
cat > /opt/hadoop/etc/hadoop/core-site.xml <<'XML'
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://main:9000</value>
  </property>
</configuration>
XML

cat > /opt/hadoop/etc/hadoop/hdfs-site.xml <<'XML'
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>3</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///data/dn</value>
  </property>
</configuration>
XML

mkdir -p /data/dn

# Spark worker config
mkdir -p /opt/spark/conf
cat > /opt/spark/conf/spark-env.sh <<'SH'
export SPARK_WORKER_CORES=2
export SPARK_WORKER_MEMORY=1G
SH
chmod +x /opt/spark/conf/spark-env.sh