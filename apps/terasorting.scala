// Spark job: filter future years (>2025), sort by (year desc, serial asc), print "year,serial"
val inputPath = "hdfs://main:9000/datasets/caps.csv"

val lines = sc.textFile(inputPath)
val cleaned = lines
  .map(_.trim).filter(_.nonEmpty)
  .map{ line =>
    val parts = line.split(",", 2)
    (parts(0).toInt, parts(1))
  }
  .filter{ case (year, _) => year <= 2025 }

val out = cleaned.sortBy({ case (y,s) => (-y, s) })
out.collect().foreach{ case (y,s) => println(s"$y,$s") }
