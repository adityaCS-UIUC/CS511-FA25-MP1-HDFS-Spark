// PageRank on directed graph with damping 0.85 until convergence (max delta < 1e-4).
// Input: HDFS "src,dst". Output: "node,rank" with 3 decimals, sorted by rank desc then node asc.

import org.apache.spark.rdd.RDD

val d   = 0.85
val eps = 1e-4
val inputPath = "hdfs://main:9000/datasets/pagerank_edges.csv"

// edges: (u, v)
val edges: RDD[(Int, Int)] = sc.textFile(inputPath)
  .map(_.trim).filter(_.nonEmpty)
  .map { s => val a = s.split(","); (a(0).toInt, a(1).toInt) }
  .cache()

// nodes & N
val nodes: RDD[Int] = edges.flatMap { case (u,v) => Seq(u,v) }.distinct().cache()
val N = nodes.count().toDouble

// adjacency + outdegree
val adj: RDD[(Int, Array[Int])] = edges.groupByKey().mapValues(_.toArray).cache()
val outDeg: RDD[(Int, Int)] = adj.mapValues(_.length).cache()

// dangling flags: true if node has no out-links
val hasOut: RDD[(Int, Int)] = outDeg.mapValues(_ => 1)
val dangling: RDD[(Int, Boolean)] =
  nodes.map(n => (n, false)).leftOuterJoin(hasOut)
       .map { case (n, (_, maybe)) => (n, maybe.isEmpty) }
       .cache()

// init uniform ranks
var ranks: RDD[(Int, Double)] = nodes.map(n => (n, 1.0 / N)).cache()

def iterateOnce(r: RDD[(Int, Double)]): RDD[(Int, Double)] = {
  // join r with adjacency; ensure every node appears
  val joined: RDD[(Int, (Array[Int], Double))] =
    nodes.leftOuterJoin(adj).leftOuterJoin(r)
         .map { case (n, ((_, maybeAdj), maybeR)) =>
           val outs = maybeAdj.getOrElse(Array.empty[Int])
           val rank = maybeR.getOrElse(1.0 / N)
           (n, (outs, rank))
         }

  // contributions
  val contribs: RDD[(Int, Double)] =
    joined.flatMap { case (_, (outs, ru)) =>
      if (outs.isEmpty) Iterator.empty else outs.iterator.map(v => (v, ru / outs.length))
    }

  // dangling mass
  val danglingMass: Double = joined.filter { case (_, (outs, _)) => outs.isEmpty }
                                   .map { case (_, (_, rnk)) => rnk }.sum()

  val base = (1.0 - d) / N + d * (danglingMass / N)

  // inbound sum for each node (ensure all nodes present)
  val inbound: RDD[(Int, Double)] =
    contribs.union(nodes.map(n => (n, 0.0))).reduceByKey(_ + _)

  inbound.mapValues(v => d * v + base)
}

// iterate to convergence
var delta = Double.MaxValue
var iters = 0
while (delta > eps && iters < 100) {
  val next = iterateOnce(ranks).cache()
  val maxDelta = ranks.join(next).map { case (_, (a, b)) => math.abs(a - b) }.max()
  delta = maxDelta
  iters += 1
  ranks.unpersist(false)
  ranks = next
}

// format & print
val formatted = ranks
  .map { case (n, v) => (n, BigDecimal(v).setScale(3, BigDecimal.RoundingMode.HALF_UP).toDouble) }
  .sortBy({ case (n, v) => (-v, n) })

formatted.collect().foreach { case (n, v) => println(s"$n,%.3f".format(v)) }
sys.exit(0)