#!/bin/bash
####################################################################################
# DO NOT MODIFY THE BELOW ##########################################################
/etc/init.d/ssh start
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/shared_rsa
# DO NOT MODIFY THE ABOVE ##########################################################
####################################################################################

export JAVA_HOME=/usr/local/openjdk-8
export HDFS_DATANODE_USER="root"

# Note: DataNode and Spark Worker are started via SSH from main node
# This script just keeps the container running

# Keep the container running
tail -f /dev/null