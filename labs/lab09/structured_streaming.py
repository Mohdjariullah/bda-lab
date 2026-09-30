from pyspark.sql import SparkSession
from pyspark.sql.functions import expr
from pyspark.sql.types import DoubleType, IntegerType, StringType, StructType

spark = SparkSession.builder \
    .appName("RetailStructuredStreaming") \
    .master("local[*]") \
    .getOrCreate()

# Define schema for retail transactions
schema = StructType() \
    .add("InvoiceNo", StringType()) \
    .add("StockCode", StringType()) \
    .add("Quantity", IntegerType()) \
    .add("UnitPrice", DoubleType()) \
    .add("Country", StringType())

# Read streaming JSON files placed in a directory
streaming_df = spark.readStream \
    .schema(schema) \
    .option("maxFilesPerTrigger", 1) \
    .json("/tmp/retail_stream_input")

# Compute Total Spend
processed_df = streaming_df \
    .withColumn("TotalSpend", expr("Quantity * UnitPrice")) \
    .groupBy("Country") \
    .sum("TotalSpend")

# Output to console sink
query = processed_df.writeStream \
    .outputMode("complete") \
    .format("console") \
    .start()

# Process stream for 10 seconds and stop
query.awaitTermination(10)
