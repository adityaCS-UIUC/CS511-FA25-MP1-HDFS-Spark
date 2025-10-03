#!/bin/bash
set -e

function test_hdfs_q1() {
  docker compose -f cs511p1-compose.yaml exec main hdfs dfsadmin -report >&2
}

function test_hdfs_q2() {
  docker compose -f cs511p1-compose.yaml cp resources/fox.txt main:/test_fox.txt
  docker compose -f cs511p1-compose.yaml exec main bash -c '\
    hdfs dfs -mkdir -p /test && \
    hdfs dfs -put -f /test_fox.txt /test/fox.txt && \
    hdfs dfs -cat /test/fox.txt'
}

function test_hdfs_q3() {
  docker compose -f cs511p1-compose.yaml exec main bash -c '\
    hadoop org.apache.hadoop.hdfs.server.namenode.NNThroughputBenchmark -fs hdfs://main:9000 -op create -threads 10 -files 1000 >/dev/null && \
    hadoop org.apache.hadoop.hdfs.server.namenode.NNThroughputBenchmark -fs hdfs://main:9000 -op open   -threads 10 -files 1000 >/dev/null && \
    hadoop org.apache.hadoop.hdfs.server.namenode.NNThroughputBenchmark -fs hdfs://main:9000 -op delete -threads 10 -files 1000 >/dev/null && \
    hadoop org.apache.hadoop.hdfs.server.namenode.NNThroughputBenchmark -fs hdfs://main:9000 -op rename -threads 10 -files 1000 >/dev/null && echo PASS'
}

function test_hdfs_q4() {
  docker compose -f cs511p1-compose.yaml cp resources/hadoop-terasort-3.3.6.jar main:/hadoop-terasort-3.3.6.jar
  docker compose -f cs511p1-compose.yaml exec main bash -c '\
    hdfs dfs -rm -r -f tera-in tera-out tera-val >/dev/null 2>&1 || true; \
    hadoop jar /hadoop-terasort-3.3.6.jar teragen 100000 tera-in && \
    hadoop jar /hadoop-terasort-3.3.6.jar terasort tera-in tera-out && \
    hadoop jar /hadoop-terasort-3.3.6.jar teravalidate tera-out tera-val && \
    hdfs dfs -count tera-in tera-out tera-val >/dev/null && echo PASS'
}

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
mkdir -p out

echo -n "Testing HDFS Q1 ..."
if test_hdfs_q1 > out/test_hdfs_q1.out 2>&1 && grep -q "Live datanodes (3)" out/test_hdfs_q1.out; then
  echo -e " ${GREEN}PASS${NC}"
else
  echo -e " ${RED}FAIL${NC}"
  exit 1
fi

echo -n "Testing HDFS Q2 ..."
if test_hdfs_q2 > out/test_hdfs_q2.out 2>&1 && grep -q 'The quick brown fox' out/test_hdfs_q2.out; then
  echo -e " ${GREEN}PASS${NC}"
else
  echo -e " ${RED}FAIL${NC}"
  exit 1
fi

echo -n "Testing HDFS Q3 ..."
if test_hdfs_q3 > out/test_hdfs_q3.out 2>&1 && grep -q 'PASS' out/test_hdfs_q3.out; then
  echo -e " ${GREEN}PASS${NC}"
else
  echo -e " ${RED}FAIL${NC}"
  exit 1
fi

echo -n "Testing HDFS Q4 ..."
if test_hdfs_q4 > out/test_hdfs_q4.out 2>&1 && grep -q 'PASS' out/test_hdfs_q4.out; then
  echo -e " ${GREEN}PASS${NC}"
else
  echo -e " ${RED}FAIL${NC}"
  exit 1
fi
