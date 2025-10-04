import java.net.InetAddress
import scala.io.Source

// Warm up the executors so they register
sc.parallelize(1 to 1000, 3).count()

// Build IP -> name map from /etc/hosts (prefer main/worker1/worker2)
val ipToName: Map[String,String] = try {
  Source.fromFile("/etc/hosts").getLines().toSeq.flatMap { ln =>
    val t = ln.trim
    if (t.isEmpty || t.startsWith("#")) Nil
    else {
      val parts = t.split("\\s+").toList
      parts match {
        case ip :: names if names.nonEmpty =>
          val pref = names.find(n => n == "main" || n == "worker1" || n == "worker2")
          Some(ip -> pref.getOrElse(names.head))
        case _ => Nil
      }
    }
  }.toMap
} catch { case _: Throwable => Map.empty[String,String] }

// Collect executor hosts -> map IPs to names
val endpoints = sc.getExecutorMemoryStatus.keys.toSeq    // "host:port"
val hosts = endpoints.map(_.split(":")(0)).distinct
val hostnames = hosts.map { h =>
  ipToName.getOrElse(h, try InetAddress.getByName(h).getHostName catch { case _: Throwable => h })
}.distinct

// Exclude driver
val driverHost = try sc.getConf.get("spark.driver.host") catch { case _: Throwable => InetAddress.getLocalHost.getHostName }
val out = hostnames.filterNot(_ == driverHost).sorted

println(out.mkString(","))