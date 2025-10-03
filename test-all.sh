#!/bin/bash
# Resolve spark-shell inside the "main" container, no assumptions.
SPARK_WRAPPER='
set -e
resolve() {
  for p in $(command -v spark-shell 2>/dev/null || true) /opt/spark/bin/spark-shell /spark/bin/spark-shell; do
    if [ -x "$p" ]; then echo "$p"; return 0; fi
  done
  echo "__NO_SPARK__"
}
SPARK=$(resolve)
if [ "$SPARK" = "__NO_SPARK__" ]; then
  echo "__ERR__:spark-shell not found in container PATH or /opt/spark/bin or /spark/bin"
  exit 127
fi
"$SPARK" --master spark://main:7077 --conf spark.ui.showConsoleProgress=false
'
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
        cat /pi.scala | spark-shell --master spark://main:7077'

}

function test_spark_q3() {
    docker compose -f cs511p1-compose.yaml cp resources/fox.txt main:/test_fox.txt
    docker compose -f cs511p1-compose.yaml exec main bash -x -c '\
        hdfs dfs -mkdir -p /test; \
        hdfs dfs -put -f /test_fox.txt /test/fox.txt; \
        hdfs dfs -cat /test/fox.txt'
    docker compose -f cs511p1-compose.yaml exec main bash -x -c '\
        echo "sc.textFile(\"hdfs://main:9000/test/fox.txt\").collect()" | \
        spark-shell --master spark://main:7077'

}

function test_spark_q4() {
    docker compose -f cs511p1-compose.yaml cp resources/spark-terasort-1.2.jar \
        main:/spark-terasort-1.2.jar
    docker compose -f cs511p1-compose.yaml exec main spark-submit \
        --master spark://main:7077 \
        --class com.github.ehiggs.spark.terasort.TeraGen local:///spark-terasort-1.2.jar \
        100m hdfs://main:9000/spark/tera-in
    docker compose -f cs511p1-compose.yaml exec main spark-submit \
        --master spark://main:7077 \
        --class com.github.ehiggs.spark.terasort.TeraSort local:///spark-terasort-1.2.jar \
        hdfs://main:9000/spark/tera-in hdfs://main:9000/spark/tera-out
    docker compose -f cs511p1-compose.yaml exec main spark-submit \
        --master spark://main:7077 \
        --class com.github.ehiggs.spark.terasort.TeraValidate local:///spark-terasort-1.2.jar \
        hdfs://main:9000/spark/tera-out hdfs://main:9000/spark/tera-val
}

# --- Part 3: Tera Sorting demo (20 pts) ---
function test_terasorting() {
  # 1) Stage /datasets/caps.csv using Spark (no hdfs CLI)
  docker compose -f cs511p1-compose.yaml exec -T main bash -lc "$SPARK_WRAPPER" << "EOF" >/dev/null 2>/dev/null
val spark = org.apache.spark.sql.SparkSession.builder.getOrCreate()
val sc = spark.sparkContext
val data = Seq(
  "1999,1234-5678-91011",
  "1800,1001-1002-10003",
  "2023,0829-0914-00120",
  "2050,9999-9999-99999"
)
import org.apache.hadoop.fs.{FileSystem, Path}
val fs  = FileSystem.get(sc.hadoopConfiguration)
val tmp = new Path("hdfs://main:9000/datasets/caps.csv.tmp")
val fin = new Path("hdfs://main:9000/datasets/caps.csv")
sc.parallelize(data).repartition(1).saveAsTextFile(tmp.toString)
if (fs.exists(fin)) fs.delete(fin, true)
fs.rename(tmp, fin)
sys.exit(0)
EOF

  # 2) Run your Scala app by piping it to spark-shell; print only clean lines
  docker compose -f cs511p1-compose.yaml exec -T main bash -lc "$SPARK_WRAPPER" \
    < apps/terasorting.scala 2>/dev/null | grep -E "^[0-9]+,.*$"
}

# --- Part 4: PageRank extra credit (20 pts) ---
function test_pagerank() {
  # 1) Stage /datasets/pagerank_edges.csv using Spark
  docker compose -f cs511p1-compose.yaml exec -T main bash -lc "$SPARK_WRAPPER" << "EOF" >/dev/null 2>/dev/null
val spark = org.apache.spark.sql.SparkSession.builder.getOrCreate()
val sc = spark.sparkContext
val edges = Seq(
  "2,3","3,2","4,2","5,2","5,6","6,5",
  "7,5","8,5","9,5","10,5","11,5","4,1"
)
import org.apache.hadoop.fs.{FileSystem, Path}
val fs  = FileSystem.get(sc.hadoopConfiguration)
val tmp = new Path("hdfs://main:9000/datasets/pagerank_edges.csv.tmp")
val fin = new Path("hdfs://main:9000/datasets/pagerank_edges.csv")
sc.parallelize(edges).repartition(1).saveAsTextFile(tmp.toString)
if (fs.exists(fin)) fs.delete(fin, true)
fs.rename(tmp, fin)
sys.exit(0)
EOF

  # 2) Run your PageRank; only emit "node,rank" like 2,0.350
  docker compose -f cs511p1-compose.yaml exec -T main bash -lc "$SPARK_WRAPPER" \
    < apps/pagerank.scala 2>/dev/null | grep -E "^[0-9]+,[0-9]+\.[0-9]{3}$"
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
