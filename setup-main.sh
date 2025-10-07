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

# --- 3. workers file ---
cat > ${HADOOP_CONF_DIR}/workers <<EOF
main
worker1
worker2
EOF


JAVA_PATH="/usr/local/openjdk-8/jre"
# --- 4. hadoop-env.sh (Set JAVA_HOME inside Hadoop config) ---
# Use sed to replace the default JAVA_HOME placeholder
# --- 4. hadoop-env.sh (Set JAVA_HOME inside Hadoop config) ---
# Use sed to replace the default JAVA_HOME placeholder
echo "export JAVA_HOME=/usr/local/openjdk-8/jre" >> ${HADOOP_CONF_DIR}/hadoop-env.sh



# ----------------- SPARK CONFIGURATION -----------------
echo "Setting up Spark configuration..."

# 1. Copy template files
cp ${SPARK_HOME}/conf/spark-env.sh.template ${SPARK_HOME}/conf/spark-env.sh
cp ${SPARK_HOME}/conf/workers.template ${SPARK_HOME}/conf/workers

# 2. Configure SPARK_MASTER_HOST and SPARK_MASTER_PORT
# We must use 'main' and '7077' as per the requirement
echo "SPARK_MASTER_HOST=main" >> ${SPARK_HOME}/conf/spark-env.sh
echo "SPARK_MASTER_PORT=7077" >> ${SPARK_HOME}/conf/spark-env.sh

echo "export SPARK_DIST_CLASSPATH=\$(/opt/hadoop/bin/hadoop classpath)" >> ${SPARK_HOME}/conf/spark-env.sh

# 3. Add all nodes to the 'workers' file (for master to know where to launch)
# Add main, worker1, and worker2
cat > ${SPARK_HOME}/conf/workers <<EOF
main
worker1
worker2
EOF

# 4. Configure Spark logs directory
mkdir -p /opt/spark/logs