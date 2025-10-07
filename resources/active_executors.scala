import java.net.InetAddress
import org.apache.spark.SparkContext
import scala.util.Try

def currentActiveExecutors(sc: SparkContext): Seq[String] = {
  // ensure executors spin up
  sc.parallelize(1 to 1000, 3).count()

  // hostnames for executors
  val endpoints = sc.getExecutorMemoryStatus.keys.toSeq
  val hosts     = endpoints.map(_.split(":")(0)).distinct

  // map IP<->name for canonicalization
  val known = Array("main","worker1","worker2")
  val nameToIp = known.flatMap(n => Try(InetAddress.getByName(n).getHostAddress).toOption.map(ip => n -> ip)).toMap
  val ipToName = nameToIp.map(_.swap)

  // normalize (ip -> name if known)
  val normalized = hosts.map(h => ipToName.getOrElse(h, h)).distinct

  // driver host (exclude)
  val rawDriver = Try(sc.getConf.get("spark.driver.host")).toOption.getOrElse("main")
  val driver    = ipToName.getOrElse(rawDriver, rawDriver)

  normalized.filterNot(_ == driver).sorted
}

val _ = Try {
  currentActiveExecutors(sc).foreach(println)
}.recover { case _ =>
  sc.parallelize(1 to 1).count()
  currentActiveExecutors(sc).foreach(println)
}

System.exit(0)