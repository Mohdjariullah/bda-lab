from pyspark.sql import SparkSession
from pyspark.sql.functions import explode, split, col, lower

# Initialize Spark Session
spark = SparkSession.builder \
    .appName("PySpark Execution Lab") \
    .master("local[*]") \
    .getOrCreate()

# Section A: Large Dataset RDD Processing
raw_rdd = spark.sparkContext.parallelize(range(1, 1000000))
even_sum = raw_rdd.filter(lambda x: x % 2 == 0).reduce(lambda a, b: a + b)
print(f"Sum of Evens in 1 Million Integers: {even_sum}")

# Section B: Spark Dataframe Word Count
data_df = spark.createDataFrame([
    (1, "Apache Spark handles large scale data processing efficiently."),
    (2, "Spark streaming and Spark SQL are essential components.")
], ["id", "text"])

# Tokenize and count words
words_df = data_df.select(explode(split(lower(col("text")), " ")).alias("word"))
word_counts = words_df.groupBy("word").count().orderBy(col("count").desc())

print("\nWord Count Top Results:")
word_counts.show(5)

spark.stop()
