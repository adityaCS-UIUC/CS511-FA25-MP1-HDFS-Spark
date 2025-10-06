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
    docker compose -f cs511p1-compose.yaml cp resources/active_executors.scala \
        main:/active_executors.scala
    docker compose -f cs511p1-compose.yaml exec main bash -x -c '\
        cat /active_executors.scala | spark-shell --master spark://main:7077'
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

# --- REAL Part 3: HDFS/Spark Sorting ---
function test_terasorting() {
  docker compose -f cs511p1-compose.yaml exec main bash -lc '
    set -e

    # Ensure HDFS CLI is available
    export HADOOP_HOME=/opt/hadoop
    export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH

    # Ensure input exists in HDFS (idempotent)
    hdfs dfs -mkdir -p /data >/dev/null 2>&1 || true
    hdfs dfs -test -e /data/caps.csv || hdfs dfs -put -f /tmp/caps.csv /data/caps.csv

    # Write a tiny Scala file that TERMINATES the JVM after printing (no REPL hang)
    cat > /tmp/terasort.scala <<'"SCALA"'
import java.io._
val rdd = sc.textFile("hdfs://main:9000/data/caps.csv")
val out = rdd.map(_.trim).filter(_.nonEmpty)
             .map{s => val p=s.split(","); (p(0).toInt, p(1)) }
             .filter{case (y,_) => y <= 2025}
             .sortBy({case (y,sn) => (-y, sn)}, ascending=true)
             .map{case (y,sn) => s"$y,$sn" }
val res = out.collect()
res.foreach(println)
// Force the shell to exit so the test never hangs
System.exit(0)
SCALA

    # Run with a hard timeout so the test can never hang indefinitely
    # Filter out everything except valid result rows
    timeout 120 /opt/spark/bin/spark-shell \
      --master spark://main:7077 \
      --conf spark.ui.enabled=false \
      -i /tmp/terasort.scala -e "" 2>/dev/null \
      | egrep -x "^[0-9]{4},[0-9-]+$"
  '
}

# --- REAL Part 4: HDFS/Spark PageRank (EC) ---
function test_pagerank() {
  docker compose -f cs511p1-compose.yaml exec main bash -lc '
    set -e

    # Make hdfs resolvable
    export HADOOP_HOME=/opt/hadoop
    export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH

    # Ensure data exists in HDFS (idempotent)
    hdfs dfs -mkdir -p /graph >/dev/null 2>&1 || true
    hdfs dfs -test -e /graph/edges.csv || hdfs dfs -put -f /tmp/edges.csv /graph/edges.csv

    # Run PageRank and print ranks only
    /opt/spark/bin/spark-shell --master spark://main:7077 -e "
      val d=0.85; val eps=1e-4
      val edges = sc.textFile(\"hdfs://main:9000/graph/edges.csv\")
                    .map(_.trim).filter(_.nonEmpty)
                    .map{ l => val p=l.split(\",\"); (p(0).toInt, p(1).toInt) }
      val nodes = edges.flatMap{case (s,t)=>Seq(s,t)}.distinct().cache()
      val N = nodes.count().toDouble
      val links = edges.groupByKey().mapValues(_.toSet).cache()
      var ranks = nodes.map(n => (n, 1.0/N)).cache()
      def step(r: org.apache.spark.rdd.RDD[(Int,Double)]) = {
        val contribs = links.leftOuterJoin(r).flatMap{ case (_, (outs, ropt)) =>
          val rank = ropt.getOrElse(0.0)
          if (outs.isEmpty) Seq() else outs.toSeq.map(dst => (dst, rank/outs.size))
        }
        contribs.reduceByKey(_+_).rightOuterJoin(nodes.map((_,())))
                .map{ case (n,(s,_)) => (n, (1-d)/N + d*s.getOrElse(0.0)) }
      }
      var delta=1.0; var i=0
      while (delta>eps && i<50) {
        val nr=step(ranks).cache()
        delta=ranks.join(nr).map{case(_, (a,b))=>math.abs(a-b)}.max()
        ranks.unpersist(false); ranks=nr; i+=1
      }
      val fmt=new java.text.DecimalFormat(\"0.000\")
      ranks.collect().toSeq.sortBy{case(n,r)=>(-r,n)}.foreach{case(n,r)=> println(s\"$n,${fmt.format(r)}\")}
    " 2>/dev/null | egrep -x "^[0-9]+,[0-9]+\.[0-9]{3}$"
  '
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
