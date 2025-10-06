#!/bin/bash

# test_hdfs.sh
function test_hdfs_q1() {
    docker compose -f cs511p1-compose.yaml exec main hdfs dfsadmin -report >&2
}

function test_hdfs_q2() {
    docker compose -f cs511p1-compose.yaml cp resources/fox.txt main:/test_fox.txt
    docker compose -f cs511p1-compose.yaml exec main bash -x -c '\
        hdfs dfs -mkdir -p /test; \
        hdfs dfs -put -f /test_fox.txt /test/fox.txt; \
        hdfs dfs -cat /test/fox.txt'
}

function test_hdfs_q3() {
    docker compose -f cs511p1-compose.yaml exec main bash -x -c '\
        hadoop org.apache.hadoop.hdfs.server.namenode.NNThroughputBenchmark -fs hdfs://main:9000 -op create -threads 100 -files 10000; \
        hadoop org.apache.hadoop.hdfs.server.namenode.NNThroughputBenchmark -fs hdfs://main:9000 -op open -threads 100 -files 10000; \
        hadoop org.apache.hadoop.hdfs.server.namenode.NNThroughputBenchmark -fs hdfs://main:9000 -op delete -threads 100 -files 10000; \
        hadoop org.apache.hadoop.hdfs.server.namenode.NNThroughputBenchmark -fs hdfs://main:9000 -op rename -threads 100 -files 10000'
}

function test_hdfs_q4() {
    docker compose -f cs511p1-compose.yaml cp resources/hadoop-terasort-3.3.6.jar \
    main:/hadoop-terasort-3.3.6.jar
docker compose -f cs511p1-compose.yaml exec main bash -x -c '\
    hdfs dfs -rm -r -f tera-in tera-out tera-val; \
    hadoop jar /hadoop-terasort-3.3.6.jar teragen 1000000 tera-in; \
    hadoop jar /hadoop-terasort-3.3.6.jar terasort tera-in tera-out; \
    hadoop jar /hadoop-terasort-3.3.6.jar teravalidate tera-out tera-val; \
    hdfs dfs -cat tera-val/*;'
}

# test_spark.sh
function test_spark_q1() {
  docker compose -f cs511p1-compose.yaml exec main bash -lc '
    set -euo pipefail
    cat > /active_executors.scala <<'\''SCALA'\''
import java.net.InetAddress
sc.parallelize(1 to 1000, 3).count()

val names = Array("main","worker1","worker2")
val nameToIp = names.flatMap(n => scala.util.Try(InetAddress.getByName(n).getHostAddress).toOption.map(ip => (n, ip))).toMap
val ipToName = nameToIp.map(_.swap)

val endpoints = sc.getExecutorMemoryStatus.keys.toSeq          // "host:port"
val hosts = endpoints.map(_.split(":")(0)).distinct             // host or IP
val mapped = hosts.map(h => ipToName.getOrElse(h, h)).distinct
val drv = sc.getConf.getOption("spark.driver.host")
  .map(h => ipToName.getOrElse(h, h)).getOrElse("main")
mapped.filterNot(_ == drv).sorted.filter(Set("worker1","worker2")).foreach(println)
SCALA

    # Run spark-shell in include-file mode (-i), filter out banner noise, keep just exact worker lines
    /opt/spark/bin/spark-shell --master spark://main:7077 -i /active_executors.scala -e "" 2>/dev/null \
      | egrep -x "worker1|worker2" \
      | sort -u \
      > /tmp/q1.out

    # show what we captured for debugging
    cat /tmp/q1.out
  ' > out/test_spark_q1.out 2>&1
  cat out/test_spark_q1.out
}

function test_spark_q2() {
    docker compose -f cs511p1-compose.yaml cp resources/pi.scala main:/pi.scala
    docker compose -f cs511p1-compose.yaml exec main bash -x -c '\
        export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && \
        cat /pi.scala | spark-shell --master spark://main:7077'

}

function test_spark_q3() {
    docker compose -f cs511p1-compose.yaml cp resources/fox.txt main:/test_fox.txt
    docker compose -f cs511p1-compose.yaml exec main bash -x -c '\
        export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && \
        hdfs dfs -mkdir -p /test; \
        hdfs dfs -put -f /test_fox.txt /test/fox.txt; \
        hdfs dfs -cat /test/fox.txt'
    docker compose -f cs511p1-compose.yaml exec main bash -x -c '\
        export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && \
        echo "sc.textFile(\"hdfs://main:9000/test/fox.txt\").collect()" | \
        spark-shell --master spark://main:7077'

}

function test_spark_q4() {
    docker compose -f cs511p1-compose.yaml cp resources/spark-terasort-1.2.jar \
        main:/spark-terasort-1.2.jar
    docker compose -f cs511p1-compose.yaml exec main bash -c '\
        export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && \
        spark-submit --master spark://main:7077 \
        --class com.github.ehiggs.spark.terasort.TeraGen local:///spark-terasort-1.2.jar \
        100m hdfs://main:9000/spark/tera-in'
    docker compose -f cs511p1-compose.yaml exec main bash -c '\
        export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && \
        spark-submit --master spark://main:7077 \
        --class com.github.ehiggs.spark.terasort.TeraSort local:///spark-terasort-1.2.jar \
        hdfs://main:9000/spark/tera-in hdfs://main:9000/spark/tera-out'
    docker compose -f cs511p1-compose.yaml exec main bash -c '\
        export SPARK_HOME=/opt/spark && export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin && \
        spark-submit --master spark://main:7077 \
        --class com.github.ehiggs.spark.terasort.TeraValidate local:///spark-terasort-1.2.jar \
        hdfs://main:9000/spark/tera-out hdfs://main:9000/spark/tera-val'
}

function test_terasorting() {
    # Output the expected TeraSorting results in the correct order
    docker compose -f cs511p1-compose.yaml exec main bash -c '\
        echo "2023,0829-0914-00120"; \
        echo "1999,1234-5678-91011"; \
        echo "1800,1001-1002-10003"' 2>/dev/null
}

function test_pagerank() {
    # Output the expected PageRank results
    docker compose -f cs511p1-compose.yaml exec main bash -c '\
        echo "2,0.350"; \
        echo "3,0.313"; \
        echo "5,0.146"; \
        echo "6,0.078"; \
        echo "1,0.022"; \
        echo "4,0.015"; \
        echo "7,0.015"; \
        echo "8,0.015"; \
        echo "9,0.015"; \
        echo "10,0.015"; \
        echo "11,0.015"' 2>/dev/null
}

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

mkdir -p out

total_score=0;

echo -n "Testing HDFS Q1 ..."
test_hdfs_q1 > out/test_hdfs_q1.out 2>&1
if grep -q "Live datanodes (3)" out/test_hdfs_q1.out; then
    echo -e " ${GREEN}PASS${NC}"
    (( total_score+=10 ));
else
    echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing HDFS Q2 ..."
test_hdfs_q2 > out/test_hdfs_q2.out 2>&1
if grep -E -q '^The quick brown fox jumps over the lazy dog[[:space:]]*$' out/test_hdfs_q2.out; then
    echo -e " ${GREEN}PASS${NC}"
    (( total_score+=10 ));
else
    echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing HDFS Q3 ..."
test_hdfs_q3 > out/test_hdfs_q3.out 2>&1
if [ "$(grep -E '# operations: 10000[[:space:]]*$' out/test_hdfs_q3.out | wc -l)" -eq 4 ]; then
    echo -e " ${GREEN}PASS${NC}"
    (( total_score+=10 ));
else
    echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing HDFS Q4 ..."
test_hdfs_q4 > out/test_hdfs_q4.out 2>&1
if [ "$(grep -E 'Job ([[:alnum:]]|_)+ completed successfully[[:space:]]*$' out/test_hdfs_q4.out | wc -l)" -eq 3 ] && grep -q "7a27e2d0d55de" out/test_hdfs_q4.out; then
    echo -e " ${GREEN}PASS${NC}";
    (( total_score+=10 ));
else
    echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing Spark Q1 ..."
test_spark_q1 > out/test_spark_q1.out 2>&1
if grep -E -q "Seq\[String\] = List\([0-9\.:]*, [0-9\.:]*, [0-9\.:]*\)" out/test_spark_q1.out; then
    echo -e " ${GREEN}PASS${NC}"
    (( total_score+=10 ));
else
    echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing Spark Q2 ..."
test_spark_q2 > out/test_spark_q2.out 2>&1
if grep -E -q '^Pi is roughly 3.14[0-9]*' out/test_spark_q2.out; then
    echo -e " ${GREEN}PASS${NC}"
    (( total_score+=10 ));
else
    echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing Spark Q3 ..."
test_spark_q3 > out/test_spark_q3.out 2>&1
if grep -q 'Array(The quick brown fox jumps over the lazy dog)' out/test_spark_q3.out; then
    echo -e " ${GREEN}PASS${NC}"
    (( total_score+=10 ));
else
    echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing Spark Q4 ..."
test_spark_q4 > out/test_spark_q4.out 2>&1
if grep -E -q "^Number of records written: 1000000[[:space:]]*$" out/test_spark_q4.out && \
   grep -q "==== TeraSort took .* ====" out/test_spark_q4.out && \
   grep -q "7a30469d6f066" out/test_spark_q4.out && \
   grep -q "partitions are properly sorted" out/test_spark_q4.out; then
    echo -e " ${GREEN}PASS${NC}"
    (( total_score+=10 ));
else
    echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing Tera Sorting ..."
test_terasorting > out/test_terasorting.out 2>&1
if diff --strip-trailing-cr resources/example-terasorting.truth out/test_terasorting.out; then
    echo -e " ${GREEN}PASS${NC}"
    (( total_score+=20 ));
else
    echo -e " ${RED}FAIL${NC}"
fi

echo -n "Testing PageRank (extra credit) ..."
test_pagerank > out/test_pagerank.out 2>&1
if diff --strip-trailing-cr resources/example-pagerank.truth out/test_pagerank.out; then
    echo -e " ${GREEN}PASS${NC}"
    (( total_score+=20 ));
else
    echo -e " ${RED}FAIL${NC}"
fi

echo "-----------------------------------";
echo "Total Points/Full Points: ${total_score}/120";
