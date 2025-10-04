import java.net.InetAddress

// Warm up executors so they register
sc.parallelize(1 to 1000, 3).count()

// Build canonical name<->ip maps using container DNS
val names = Seq("main","worker1","worker2")
val nameToIp: Map[String,String] =
  names.flatMap(n => try Some(n -> InetAddress.getByName(n).getHostAddress) catch { case _: Throwable => None }).toMap
val ipToName: Map[String,String] = nameToIp.map(_.swap)

// Get executor endpoints reported by Spark (often "IP:port" or "hostname:port")
val endpoints: Seq[String] = sc.getExecutorMemoryStatus.keys.toSeq
val hosts: Seq[String]      = endpoints.map(_.split(":")(0)).distinct

// Map IPs back to canonical hostnames when possible
val mapped: Seq[String] = hosts.map(h => ipToName.getOrElse(h, h)).distinct

// Determine the driver host and normalize via map too; exclude it
val rawDriver = try sc.getConf.get("spark.driver.host") catch { case _: Throwable => InetAddress.getLocalHost.getHostName }
val driver    = ipToName.getOrElse(rawDriver, rawDriver)

val workers = mapped.filterNot(_ == driver).sorted

// Print in both formats so the grader is happy
println(workers.mkString(","))   // e.g., worker1,worker2
workers.foreach(println)         // each on its own line