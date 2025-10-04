import java.net.InetAddress
sc.parallelize(1 to 1000,3).count()
val names = Array("main","worker1","worker2")
val nameToIp = names.flatMap(n => scala.util.Try(InetAddress.getByName(n).getHostAddress).toOption.map(ip => (n,ip))).toMap
val ipToName = nameToIp.map(_.swap)
val endpoints = sc.getExecutorMemoryStatus.keys.toSeq
val hosts = endpoints.map(_.split(":")(0)).distinct
val mapped = hosts.map(h => ipToName.getOrElse(h,h)).distinct
val drv = sc.getConf.getOption("spark.driver.host").map(h => ipToName.getOrElse(h,h)).getOrElse("main")
mapped.filterNot(_==drv).sorted.foreach(println)