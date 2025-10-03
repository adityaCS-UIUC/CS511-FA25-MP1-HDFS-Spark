// PageRank on directed graph with damping 0.85 until convergence (max delta < 1e-4).
// Input: HDFS file with lines "src,dst". Output to stdout: "node,rank" with 3 decimals,
// sorted by rank desc, then node asc.

import org.apache.spark.rdd.RDD

val d = 0.85
val eps = 1e-4
val inputPath = "hdfs://main:9000/datasets/pagerank_edges.csv"

val edges: RDD[(Int, Int)] = sc.textFile(inputPath)
  .map(_.trim).filter(_.nonEmpty)
  .map{ s => val a = s.split(","); (a(0).toInt, a(1).toInt) }

val nodes: RDD[Int] = edges.flatMap{ case (u,v) => Seq(u,v) }.distinct().cache()
val N = nodes.count().toDouble

val outlinks: RDD[(Int, Array[Int])] =
  edges.groupByKey().mapValues(_.toArray)
       .rightOuterJoin(nodes.map(n => (n, Array[Int]())))
       .map{ case (n,(maybe,_)) => (n, maybe.getOrElse(Array.empty[Int])) }
       .cache()

var ranks: RDD[(Int, Double)] = nodes.map(n => (n, 1.0 / N)).cache()

def iterateOnce(r: RDD[(Int,Double)]): RDD[(Int,Double)] = {
  val joined = outlinks.join(r) // (n, (nbrs, rank))

  val contribs = joined.flatMap{ case (_, (nbrs, rank)) =>
    if (nbrs.isEmpty) Seq.empty[(Int, Double)] else nbrs.map(v => (v, rank / nbrs.length))
  }

  val danglingMass = joined.filter{ case (_, (nbrs, _)) => nbrs.isEmpty }
                           .map{ case (_, (_, rank)) => rank }.sum()
  val danglingShare = danglingMass / N

  contribs.reduceByKey(_ + _)
          .rightOuterJoin(nodes.map(n => (n, 0.0)))
          .map{ case (n, (sumOpt, _)) =>
            val sum = sumOpt.getOrElse(0.0)
            val pr = (1 - d) / N + d * (sum + danglingShare)
            (n, pr)
          }
}

var delta = Double.MaxValue
while (delta > eps) {
  val newRanks = iterateOnce(ranks).cache()
  val maxDelta = ranks.join(newRanks).map{ case (_, (a,b)) => math.abs(a - b) }.max()
  delta = maxDelta
  ranks.unpersist(false)
  ranks = newRanks
}

val formatted = ranks
  .map{ case (n,v) => (n, BigDecimal(v).setScale(3, BigDecimal.RoundingMode.HALF_UP).toDouble) }
  .sortBy({ case (n,v) => (-v, n) })

formatted.collect().foreach{ case (n,v) => println(s"$n,%.3f".format(v)) }