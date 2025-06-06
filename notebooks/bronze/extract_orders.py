# Databricks notebook source
# MAGIC %md
# MAGIC # Extract Orders Data to Bronze Layer
# MAGIC 
# MAGIC This notebook extracts orders and order lines data from the WorldWideImporters SQL Server database and loads it into the Unity Catalog bronze layer.
# MAGIC 
# MAGIC ## Tables Extracted:
# MAGIC - Sales.Orders
# MAGIC - Sales.OrderLines
# MAGIC 
# MAGIC ## Parameters:
# MAGIC - `catalog_name`: Unity Catalog name
# MAGIC - `schema_name`: Schema name (bronze)  
# MAGIC - `sql_server_host`: SQL Server hostname
# MAGIC - `sql_database_name`: SQL Database name
# MAGIC - `sql_username`: SQL Server username
# MAGIC - `sql_password`: SQL Server password

# COMMAND ----------

# Import required libraries
from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import datetime

# COMMAND ----------

# MAGIC %md
# MAGIC ## Parameters

# COMMAND ----------

# Get parameters from widget or job parameters
dbutils.widgets.text("catalog_name", "don_datalab_catalog", "Catalog Name")
dbutils.widgets.text("schema_name", "bronze", "Schema Name")
dbutils.widgets.text("sql_server_host", "", "SQL Server Host")
dbutils.widgets.text("sql_database_name", "WorldWideImporters", "SQL Database Name")
dbutils.widgets.text("sql_username", "", "SQL Username")
dbutils.widgets.text("sql_password", "", "SQL Password")

# Get parameter values
catalog_name = dbutils.widgets.get("catalog_name")
schema_name = dbutils.widgets.get("schema_name")
sql_server_host = dbutils.widgets.get("sql_server_host")
sql_database_name = dbutils.widgets.get("sql_database_name")
sql_username = dbutils.widgets.get("sql_username")
sql_password = dbutils.widgets.get("sql_password")

print(f"Target: {catalog_name}.{schema_name}")
print(f"Source: {sql_server_host}/{sql_database_name}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Database Connection Configuration

# COMMAND ----------

# SQL Server connection properties
jdbc_url = f"jdbc:sqlserver://{sql_server_host}:1433;database={sql_database_name};encrypt=true;trustServerCertificate=true"

connection_properties = {
    "user": sql_username,
    "password": sql_password,
    "driver": "com.microsoft.sqlserver.jdbc.SQLServerDriver",
    "encrypt": "true",
    "trustServerCertificate": "true"
}

print(f"JDBC URL: {jdbc_url}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Create Schema if Not Exists

# COMMAND ----------

# Create catalog and schema if they don't exist
spark.sql(f"CREATE CATALOG IF NOT EXISTS {catalog_name}")
spark.sql(f"USE CATALOG {catalog_name}")
spark.sql(f"CREATE SCHEMA IF NOT EXISTS {schema_name}")
spark.sql(f"USE SCHEMA {schema_name}")

print(f"Using catalog: {catalog_name}, schema: {schema_name}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Extract Orders Data

# COMMAND ----------

try:
    # Extract Orders data with enhanced error handling and logging
    print("Starting Orders extraction...")
    
    orders_query = """
    SELECT 
        OrderID,
        CustomerID,
        SalespersonPersonID,
        PickedByPersonID,
        ContactPersonID,
        BackorderOrderID,
        OrderDate,
        ExpectedDeliveryDate,
        CustomerPurchaseOrderNumber,
        IsUndersupplyBackordered,
        Comments,
        DeliveryInstructions,
        InternalComments,
        PickingCompletedWhen,
        LastEditedBy,
        LastEditedWhen
    FROM Sales.Orders
    """
    
    orders_df = spark.read \
        .format("jdbc") \
        .option("url", jdbc_url) \
        .option("query", orders_query) \
        .option("user", sql_username) \
        .option("password", sql_password) \
        .option("driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver") \
        .load()
    
    # Add metadata columns for data lineage and quality tracking
    orders_df = orders_df \
        .withColumn("_extract_timestamp", current_timestamp()) \
        .withColumn("_source_system", lit("WorldWideImporters_SQL")) \
        .withColumn("_batch_id", lit(f"orders_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"))
    
    print(f"Orders extracted: {orders_df.count()} records")
    
    # Data quality checks
    null_order_ids = orders_df.filter(col("OrderID").isNull()).count()
    if null_order_ids > 0:
        print(f"WARNING: Found {null_order_ids} records with null OrderID")
    
    # Write to Unity Catalog bronze layer with proper partitioning
    table_name = f"{catalog_name}.{schema_name}.orders"
    print(f"Writing to table: {table_name}")
    
    orders_df.write \
        .mode("overwrite") \
        .option("mergeSchema", "true") \
        .partitionBy("OrderDate") \
        .saveAsTable(table_name)
    
    print(f"✅ Orders data successfully written to {table_name}")
    
except Exception as e:
    print(f"❌ Error extracting Orders data: {str(e)}")
    raise

# COMMAND ----------

# MAGIC %md
# MAGIC ## Extract Order Lines Data

# COMMAND ----------

try:
    # Extract OrderLines data
    print("Starting OrderLines extraction...")
    
    order_lines_query = """
    SELECT 
        OrderLineID,
        OrderID,
        StockItemID,
        Description,
        PackageTypeID,
        Quantity,
        UnitPrice,
        TaxRate,
        PickedQuantity,
        PickingCompletedWhen,
        LastEditedBy,
        LastEditedWhen
    FROM Sales.OrderLines
    """
    
    order_lines_df = spark.read \
        .format("jdbc") \
        .option("url", jdbc_url) \
        .option("query", order_lines_query) \
        .option("user", sql_username) \
        .option("password", sql_password) \
        .option("driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver") \
        .load()
    
    # Add metadata columns
    order_lines_df = order_lines_df \
        .withColumn("_extract_timestamp", current_timestamp()) \
        .withColumn("_source_system", lit("WorldWideImporters_SQL")) \
        .withColumn("_batch_id", lit(f"order_lines_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"))
    
    print(f"OrderLines extracted: {order_lines_df.count()} records")
    
    # Data quality checks
    null_order_line_ids = order_lines_df.filter(col("OrderLineID").isNull()).count()
    null_order_ids = order_lines_df.filter(col("OrderID").isNull()).count()
    
    if null_order_line_ids > 0:
        print(f"WARNING: Found {null_order_line_ids} records with null OrderLineID")
    if null_order_ids > 0:
        print(f"WARNING: Found {null_order_ids} records with null OrderID")
    
    # Calculate some basic statistics
    total_quantity = order_lines_df.agg(sum("Quantity")).collect()[0][0]
    avg_unit_price = order_lines_df.agg(avg("UnitPrice")).collect()[0][0]
    
    print(f"Total quantity across all order lines: {total_quantity}")
    print(f"Average unit price: ${avg_unit_price:.2f}")
    
    # Write to Unity Catalog bronze layer
    table_name = f"{catalog_name}.{schema_name}.order_lines"
    print(f"Writing to table: {table_name}")
    
    order_lines_df.write \
        .mode("overwrite") \
        .option("mergeSchema", "true") \
        .saveAsTable(table_name)
    
    print(f"✅ OrderLines data successfully written to {table_name}")
    
except Exception as e:
    print(f"❌ Error extracting OrderLines data: {str(e)}")
    raise

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Quality Summary Report

# COMMAND ----------

try:
    # Generate summary report
    print("=== DATA EXTRACTION SUMMARY ===")
    print(f"Extraction completed at: {datetime.datetime.now()}")
    print(f"Target catalog: {catalog_name}")
    print(f"Target schema: {schema_name}")
    print("")
    
    # Get record counts from Unity Catalog tables
    orders_count = spark.sql(f"SELECT COUNT(*) as count FROM {catalog_name}.{schema_name}.orders").collect()[0]["count"]
    order_lines_count = spark.sql(f"SELECT COUNT(*) as count FROM {catalog_name}.{schema_name}.order_lines").collect()[0]["count"]
    
    print(f"📊 RECORD COUNTS:")
    print(f"  - Orders: {orders_count:,}")
    print(f"  - Order Lines: {order_lines_count:,}")
    print("")
    
    # Data quality metrics
    print("🔍 DATA QUALITY METRICS:")
    
    # Orders metrics
    orders_with_customer = spark.sql(f"""
        SELECT COUNT(*) as count 
        FROM {catalog_name}.{schema_name}.orders 
        WHERE CustomerID IS NOT NULL
    """).collect()[0]["count"]
    
    orders_with_dates = spark.sql(f"""
        SELECT COUNT(*) as count 
        FROM {catalog_name}.{schema_name}.orders 
        WHERE OrderDate IS NOT NULL
    """).collect()[0]["count"]
    
    print(f"  - Orders with CustomerID: {orders_with_customer:,} ({orders_with_customer/orders_count*100:.1f}%)")
    print(f"  - Orders with OrderDate: {orders_with_dates:,} ({orders_with_dates/orders_count*100:.1f}%)")
    
    # Order lines metrics
    order_lines_with_stock = spark.sql(f"""
        SELECT COUNT(*) as count 
        FROM {catalog_name}.{schema_name}.order_lines 
        WHERE StockItemID IS NOT NULL
    """).collect()[0]["count"]
    
    order_lines_with_quantity = spark.sql(f"""
        SELECT COUNT(*) as count 
        FROM {catalog_name}.{schema_name}.order_lines 
        WHERE Quantity > 0
    """).collect()[0]["count"]
    
    print(f"  - Order lines with StockItemID: {order_lines_with_stock:,} ({order_lines_with_stock/order_lines_count*100:.1f}%)")
    print(f"  - Order lines with positive quantity: {order_lines_with_quantity:,} ({order_lines_with_quantity/order_lines_count*100:.1f}%)")
    
    print("")
    print("✅ Orders extraction completed successfully!")
    
except Exception as e:
    print(f"❌ Error generating summary report: {str(e)}")
    # Don't raise here as the main extraction was successful
    
# COMMAND ----------

# MAGIC %md
# MAGIC ## Cleanup

# COMMAND ----------

# Clear sensitive parameters from memory
sql_password = None
connection_properties = None

print("🧹 Cleanup completed - sensitive data cleared from memory")
