#!/bin/bash
set -euo pipefail
export JAVA_HOME=/usr/local/openjdk-8

HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop

# SSH for this node
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# core-site.xml
cat > ${HADOOP_CONF_DIR}/core-site.xml <<'EOF'
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://main:9000</value>
  </property>
  <property>
    <name>io.file.buffer.size</name>
    <value>131072</value>
  </property>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/tmp/hadoop-data/tmp</value>
  </property>
</configuration>
EOF

# hdfs-site.xml
cat > ${HADOOP_CONF_DIR}/hdfs-site.xml <<'EOF'
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:///tmp/hadoop-data/dfs/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///tmp/hadoop-data/dfs/datanode</value>
  </property>
  <property>
    <name>dfs.replication</name>
    <value>3</value>
  </property>
  <property>
    <name>dfs.permissions.enabled</name>
    <value>false</value>
  </property>
</configuration>
EOF

# workers (include main so we have 3 datanodes: main, worker1, worker2)
cat > ${HADOOP_CONF_DIR}/workers <<'EOF'
main
worker1
worker2
EOF

# mapred-site.xml (local MRv2 client, required by some Hadoop tools)
cat > ${HADOOP_CONF_DIR}/mapred-site.xml <<'EOF'
<?xml version="1.0"?>
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
</configuration>
EOF

# yarn-site.xml (not strictly needed for this MP but harmless)
cat > ${HADOOP_CONF_DIR}/yarn-site.xml <<'EOF'
<?xml version="1.0"?>
<configuration>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
</configuration>
EOF

# JAVA_HOME for Hadoop
echo "export JAVA_HOME=/usr/local/openjdk-8" >> ${HADOOP_CONF_DIR}/hadoop-env.sh
