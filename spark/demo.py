from pyspark.sql import SparkSession

def create_spark_session(config = None):
    # Create SparkSession with Kubernetes and MinIO configuration
    default_config = {
        "spark.master": "local[2]",
        "spark.driver.memory": '2g',
        "spark.sql.warehouse.dir": "tests/lakehouse/spark-warehouse/",  
        "spark.sql.shuffle.partitions": "2",
        "spark.sql.extensions": "io.delta.sql.DeltaSparkSessionExtension",
        "spark.sql.catalog.spark_catalog": "org.apache.spark.sql.delta.catalog.DeltaCatalog",  
        "spark.jars.packages": "io.delta:delta-spark_2.12:3.2.0,org.xerial:sqlite-jdbc:3.45.3.0,com.databricks:spark-xml_2.12:0.18.0,org.apache.hadoop:hadoop-aws:3.3.2",  
        "spark.jars.excludes": "net.sourceforge.f2j:arpack_combined_all",
        "spark.sql.sources.parallelPartitionDiscovery.parallelism": "2",
        "spark.sql.legacy.charVarcharAsString": True,
        "spark.databricks.delta.optimizeWrite.enabled": True,
        "spark.sql.adaptive.enabled": True,
        "spark.databricks.delta.merge.enableLowShuffle": True,
        "spark.driver.extraJavaOptions": "-Xss4M -Djava.security.manager=allow -Djava.security.policy=spark.policy",
        "spark.authenticate": "false",
        "spark.network.crypto.enabled": "false",
        "spark.ui.enabled": "false",
        # MinIO Configuration
        "spark.hadoop.fs.s3a.endpoint": "http://localhost:30900",
        "spark.hadoop.fs.s3a.access.key": "minioadmin",
        "spark.hadoop.fs.s3a.secret.key": "minioadmin",
        "spark.hadoop.fs.s3a.path.style.access": "true",
        "spark.hadoop.fs.s3a.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem",
        "spark.hadoop.fs.s3a.connection.ssl.enabled": "false"
    }
    final_config: dict = {**default_config, **(config if config else {})}

    app_name = "Spark on k3d"
    session_builder = SparkSession.builder.appName(app_name)
    for k, v in final_config.items():
        session_builder.config(k, v)

    return session_builder.getOrCreate()

def run_sample_operation(spark):
    # Create a sample DataFrame
    data = [(1, "First"), (2, "Second"), (3, "Third")]
    df = spark.createDataFrame(data, ["id", "value"])
    
    # Perform some operations
    print("Sample DataFrame:")
    df.show()
    
    # Save DataFrame to MinIO
    df.write.mode("overwrite").parquet("s3a://spark-data/sample-data")
    print("\nData saved to MinIO successfully!")
    
    # Read data back from MinIO
    read_df = spark.read.parquet("s3a://spark-data/sample-data")
    print("\nData read from MinIO:")
    read_df.show()
    
    # Save DataFrame to MinIO
    df.write.mode("overwrite").parquet("s3a://spark-data/sample-data")
    print("\nData saved to MinIO successfully!")
    
    # Read data back from MinIO
    read_df = spark.read.parquet("s3a://spark-data/sample-data")
    print("\nData read from MinIO:")
    read_df.show()

def main():
    try:
        # Create Spark session
        spark = create_spark_session()
        print(spark)
        print("Successfully connected to Spark on k3d!")
        
        # Run sample operations
        run_sample_operation(spark)
        
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    main()