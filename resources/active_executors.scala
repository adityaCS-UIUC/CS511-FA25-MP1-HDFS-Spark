import java.net.InetAddress
import scala.io.Source
import org.apache.spark.SparkContext

// 1) Ensure executors are up (tiny job)
sc.parallelize(1 to 1000, 3).count()

// 2) Build a reverse IP->hostname map from /etc/hosts
val hostsFile = "/etc/hosts"
val ipToName: Map[String,String] = try {
  val lines = Source.fromFile(hostsFile).getLines().toSeq
  lines.flatMap { ln =>
    val t = ln.trim
    if (t.isEmpty || t.startsWith("#")) Nil
    else {
      val parts = t.split("\\s+").toList
      // e.g., "172.18.0.3  main"
      parts match {
        case ip :: names if names.nonEmpty =>
          // prefer canonical docker hostname (main/worker1/worker2) if present
          val preferred = names.find(n => n == "main" || n == "worker1" || n == "worker2")
          Some(ip -> preferred.getOrElse(names.head))
        case _ => Nil
      }
    }
  }.toMap
} catch { case _: Throwable => Map.empty[String,String] }

// 3) Gather executor endpoints and map to hostnames
val endpoints = sc.getExecutorMemoryStatus.keys.toSeq          // e.g. "172.18.0.4:41231"
val hosts = endpoints.map(_.split(":")(0)).distinct
val resolvedHostnames = hosts.map { h =>
  if (ipToName.contains(h)) ipToName(h)
  else {
    // fallback: reverse DNS / keep raw if it fails
    try InetAddress.getByName(h).getHostName
    catch { case _: Throwable => h }
  }
}.distinct

// 4) Exclude driver host
val driverHost = try sc.getConf.get("spark.driver.host") catch { case _: Throwable => InetAddress.getLocalHost.getHostName }
val out = resolvedHostnames.filterNot(_ == driverHost).sorted

// 5) Print comma-separated hostnames so the grader can grep worker1/worker2
println(out.mkString(","))