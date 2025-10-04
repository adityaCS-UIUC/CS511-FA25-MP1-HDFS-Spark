import java.net.InetAddress
import scala.io.Source

// Warm the executors so they register
sc.parallelize(1 to 1000, 3).count()

// Build IP -> name map from /etc/hosts (prefers main/worker1/worker2 if present)
val ipToName: Map[String,String] = try {
  val lines = Source.fromFile("/etc/hosts").getLines().toSeq
  lines.flatMap { t =>
    val ln = t.trim
    if (ln.isEmpty || ln.startsWith("#")) Nil
    else {
      val parts = ln.split("\\s+").toList
      parts match {
        case ip :: names if names.nonEmpty =>
          val pref = names.find(Set("main","worker1","worker2"))
          Some(ip -> pref.getOrElse(names.head))
        case _ => Nil
      }
    }
  }.toMap
} catch { case _ : Throwable => Map.empty[String,String] }

// Map executor endpoints -> IPs -> hostnames
val endpoints = sc.getExecutorMemoryStatus.keys.toSeq              // "host:port"
val hosts = endpoints.map(_.split(":")(0)).distinct
val hostnames = hosts.map { h =>
  ipToName.getOrElse(h, try InetAddress.getByName(h).getHostName catch { case _ : Throwable => h })
}.distinct

// Exclude the driver
val driverHost = try sc.getConf.get("spark.driver.host") catch { case _ : Throwable => InetAddress.getLocalHost.getHostName }
val out = hostnames.filterNot(_ == driverHost).sorted

println(out.mkString(","))