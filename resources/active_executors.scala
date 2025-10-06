import java.net.InetAddress
import org.apache.spark.SparkContext
import scala.util.Try

def currentActiveExecutors(sc: SparkContext): Seq[String] = {
  sc.parallelize(1 to 1000, 3).count()
  val endpoints = sc.getExecutorMemoryStatus.keys.toSeq
  val hosts     = endpoints.map(_.split(":")(0)).distinct
  val knownNames = Array("main","worker1","worker2")
  val nameToIp   = knownNames.flatMap(n => Try(InetAddress.getByName(n).getHostAddress).toOption.map(ip => n -> ip)).toMap
  val ipToName   = nameToIp.map(_.swap)
  val normalized = hosts.map(h => ipToName.getOrElse(h, h)).distinct
  val rawDriver  = Try(sc.getConf.get("spark.driver.host")).toOption.getOrElse("main")
  val driver     = ipToName.getOrElse(rawDriver, rawDriver)
  normalized.filterNot(_ == driver).sorted
}

// Force execution even when file is piped via stdin
try {
  currentActiveExecutors(sc).foreach(println)
} catch {
  case _: Throwable => // sc not ready yet; spin once and retry
    sc.parallelize(1 to 1, 1).count()
    currentActiveExecutors(sc).foreach(println)
}