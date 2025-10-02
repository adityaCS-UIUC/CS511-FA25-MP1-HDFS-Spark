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

# Setup HDFS/Spark main here
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
    <name>dfs.namenode.name.dir</name>
    <value>file:///data/nn</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///data/dn</value>
  </property>
</configuration>
XML

mkdir -p /data/nn /data/dn

# Workers file (Spark) and slaves (Hadoop 3 uses workers file too)
printf "main\nworker1\nworker2\n" | tee /opt/hadoop/etc/hadoop/workers >/dev/null
printf "main\nworker1\nworker2\n" | tee /opt/spark/conf/workers >/dev/null

# Spark config
mkdir -p /opt/spark/conf
cat > /opt/spark/conf/spark-env.sh <<'SH'
export SPARK_MASTER_HOST=main
export SPARK_MASTER_PORT=7077
export SPARK_WORKER_CORES=2
export SPARK_WORKER_MEMORY=1G
SH
chmod +x /opt/spark/conf/spark-env.sh