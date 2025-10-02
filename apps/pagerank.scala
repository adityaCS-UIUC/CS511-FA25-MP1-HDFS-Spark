// Simplified PageRank with damping d=0.85 until max delta < 1e-4
// Input edges in HDFS: "src,dst" per line. Output to stdout "node,rank" (3 decimals), sorted by rank desc then node asc.

import org.apache.spark.rdd.RDD

val d = 0.85
val eps = 1e-4
val inputPath = "hdfs://main:9000/datasets/pagerank_edges.csv"

val edges = sc.textFile(inputPath)
  .map(_.trim).filter(_.nonEmpty)
  .map{ s => val a=s.split(","); (a(0).toInt, a(1).toInt) }

val nodes: RDD[Int] = edges.flatMap{case (u,v) => Seq(u,v)}.distinct().cache()
val N = nodes.count().toDouble

val outlinks: RDD[(Int, List[Int])] =
  edges.groupByKey().mapValues(_.toList).rightOuterJoin(nodes.map(n => (n,Nil))).map{
    case (n,(maybe, _)) => (n, maybe.getOrElse(Nil))
  }.cache()

var ranks = nodes.map(n => (n, 1.0 / N)).cache()

def iterateOnce(r: RDD[(Int,Double)]): RDD[(Int,Double)] = {
  val contribs = outlinks.join(r).flatMap{ case (n,(nbrs, rank)) =>
    if (nbrs.isEmpty) Seq() else nbrs.map(v => (v, rank / nbrs.size))
  }
  val danglingMass = r.join(outlinks).filter{ case (_,(_,nbrs)) => nbrs.isEmpty }.map(_._2._1).sum()
  val danglingShare = danglingMass / N
  contribs.reduceByKey(_+_).rightOuterJoin(nodes.map(n => (n,0.0))).map{ case (n,(sumOpt,_)) =>
    val sum = sumOpt.getOrElse(0.0)
    val pr = (1-d)/N + d*(sum + danglingShare)
    (n, pr)
  }
}

var delta = Double.MaxValue
while (delta > eps) {
  val newr = iterateOnce(ranks).cache()
  val joined = ranks.join(newr).map{ case (_, (oldv, newv)) => math.abs(oldv - newv) }
  delta = joined.max()
  ranks.unpersist(false)
  ranks = newr
}

val formatted = ranks
  .map{ case (n,v) => (n, BigDecimal(v).setScale(3, BigDecimal.RoundingMode.HALF_UP).toDouble) }
  .sortBy({ case (n,v) => (-v, n) })
formatted.collect().foreach{ case (n,v) => println(s"$n,%.3f".format(v)) }