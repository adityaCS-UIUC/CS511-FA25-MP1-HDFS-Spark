#!/bin/bash
export JAVA_HOME=/usr/local/openjdk-8/jre
HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop

####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 0600 ~/.ssh/authorized_keys
# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Setup HDFS/Spark main here

# --- 1. core-site.xml ---
cat > ${HADOOP_CONF_DIR}/core-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
 <property>
 <name>fs.defaultFS</name>
 <value>hdfs://main:9000</value>
 </property>
 <property>
 <name>hadoop.tmp.dir</name>
 <value>/tmp/hadoop-data</value>
 </property>
</configuration>
EOF

# --- 2. hdfs-site.xml ---
cat > ${HADOOP_CONF_DIR}/hdfs-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
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
 <value>2</value>
 </property>
</configuration>
EOF

# --- 3. hadoop-env.sh ---
echo "export JAVA_HOME=/usr/local/openjdk-8/jre" >> ${HADOOP_CONF_DIR}/hadoop-env.sh

# --- 4. Configure workers file for HDFS ---
cat > ${HADOOP_CONF_DIR}/workers <<EOF
main
worker1
worker2
EOF

# --- 5. Configure Spark workers ---
cat > $SPARK_HOME/conf/workers <<EOF
main
worker1
worker2
EOF

# --- 6. Configure spark-env.sh ---
cat > $SPARK_HOME/conf/spark-env.sh <<EOF
export SPARK_MASTER_HOST=main
export SPARK_MASTER_PORT=7077
export SPARK_WORKER_CORES=1
export SPARK_WORKER_MEMORY=1g
EOF