####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################
FROM openjdk:8

RUN apt update &&     apt upgrade --yes &&     apt install -y ssh openssh-server curl tar bash procps coreutils python3 scala

# Setup common SSH key.
RUN ssh-keygen -t rsa -P '' -f ~/.ssh/shared_rsa -C common &&     cat ~/.ssh/shared_rsa.pub >> ~/.ssh/authorized_keys &&     chmod 0600 ~/.ssh/authorized_keys

# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

# ---------- Hadoop & Spark ----------
ENV JAVA_HOME=/usr/local/openjdk-8
ENV HADOOP_VERSION=3.3.6
ENV SPARK_VERSION=3.4.1
ENV HADOOP_HOME=/opt/hadoop
ENV SPARK_HOME=/opt/spark
ENV PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$PATH

# Hadoop (use archive to avoid 404s)
RUN curl -fsSL https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz   | tar -xz -C /opt && ln -s /opt/hadoop-${HADOOP_VERSION} ${HADOOP_HOME}

# Spark prebuilt for Hadoop3 (use archive to avoid 404s)
RUN curl -fsSL https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz   | tar -xz -C /opt && ln -s /opt/spark-${SPARK_VERSION}-bin-hadoop3 ${SPARK_HOME}

# Hadoop needs JAVA_HOME in env file
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh
