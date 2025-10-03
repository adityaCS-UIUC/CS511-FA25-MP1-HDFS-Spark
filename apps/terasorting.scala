// Read CSV lines like: YEAR,SERIAL
// Filter out future caps (year > 2025), then sort by (year desc, serial asc).
import org.apache.spark.SparkContext
import org.apache.spark.SparkConf

val inputPath = "hdfs://main:9000/datasets/caps.csv"

val lines = sc.textFile(inputPath)
val cleaned = lines
  .map(_.trim).filter(_.nonEmpty)
  .map{ line =>
    val parts = line.split(",", 2)
    (parts(0).toInt, parts(1))
  }
  .filter{ case (year, _) => year <= 2025 }

// sort: newest first (desc year), then serial asc (lexicographic)
val out = cleaned.sortBy({ case (y,s) => (-y, s) })

// print exactly as lines "year,serial"
out.collect().foreach{ case (y,s) => println(s"$y,$s") }