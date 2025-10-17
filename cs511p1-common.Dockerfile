####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################

FROM openjdk:8

RUN apt update && \
    apt upgrade --yes && \
    apt install ssh openssh-server --yes

# Setup common SSH key.
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/shared_rsa -C common && \
    cat ~/.ssh/shared_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 0600 ~/.ssh/authorized_keys

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# Setup HDFS/Spark resources here

# Set Hadoop version
ENV HADOOP_VERSION=3.3.6
ENV HADOOP_HOME=/opt/hadoop

# Install dependencies
RUN apt-get update && \
    apt-get install -y wget && \
    wget https://dlcdn.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz && \
    tar -xvzf hadoop-$HADOOP_VERSION.tar.gz -C /opt && \
    ln -s /opt/hadoop-$HADOOP_VERSION /opt/hadoop && \
    rm hadoop-$HADOOP_VERSION.tar.gz

# Set environment variables
ENV PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH
ENV HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop

# Create necessary HDFS directories and set permissions
RUN mkdir -p /tmp/hadoop-data/dfs/namenode \
           /tmp/hadoop-data/dfs/datanode \
           /tmp/hadoop-data/tmp \
           $HADOOP_HOME/logs
RUN chown -R root:root /tmp/hadoop-data $HADOOP_HOME



# ----------------- SPARK SETUP -----------------

# Define Spark version and download URL
ENV SPARK_VERSION=3.4.1
# Spark 3.x ships bundled with Hadoop 3.x dependencies
ENV SPARK_HADOOP_VERSION=3
ENV SPARK_TGZ=spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION}.tgz
ENV SPARK_URL=https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/${SPARK_TGZ}
ENV SPARK_HOME=/usr/local/spark

# Download and Extract Spark
RUN set -eux && \
    wget -q ${SPARK_URL} && \
    tar -xzf ${SPARK_TGZ} -C /usr/local/ && \
    mv /usr/local/spark-${SPARK_VERSION}-bin-hadoop${SPARK_HADOOP_VERSION} ${SPARK_HOME} && \
    rm ${SPARK_TGZ}

# Update PATH for Spark binaries (spark-shell, spark-submit)
ENV PATH=${SPARK_HOME}/bin:${PATH}


# Set the default Spark user to root
ENV SPARK_USER=root

