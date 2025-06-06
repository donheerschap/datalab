# Databricks notebook source
# MAGIC %md
# MAGIC # Extract Stock Items Data to Bronze Layer
# MAGIC 
# MAGIC This notebook extracts stock items and related inventory data from the WorldWideImporters SQL Server database and loads it into the Unity Catalog bronze layer.
# MAGIC 
# MAGIC ## Tables Extracted:
# MAGIC - Warehouse.StockItems
# MAGIC - Warehouse.StockItemHoldings
# MAGIC - Warehouse.StockGroups
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
# MAGIC ## Extract Stock Items Data

# COMMAND ----------

try:
    # Extract StockItems data with comprehensive fields
    print("Starting StockItems extraction...")
    
    stock_items_query = """
    SELECT 
        StockItemID,
        StockItemName,
        SupplierID,
        ColorID,
        UnitPackageID,
        OuterPackageID,
        Brand,
        Size,
        LeadTimeDays,
        QuantityPerOuter,
        IsChillerStock,
        Barcode,
        TaxRate,
        UnitPrice,
        RecommendedRetailPrice,
        TypicalWeightPerUnit,
        MarketingComments,
        InternalComments,
        Photo,
        CustomFields,
        Tags,
        SearchDetails,
        LastEditedBy,
        ValidFrom,
        ValidTo
    FROM Warehouse.StockItems
    """
    
    stock_items_df = spark.read \
        .format("jdbc") \
        .option("url", jdbc_url) \
        .option("query", stock_items_query) \
        .option("user", sql_username) \
        .option("password", sql_password) \
        .option("driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver") \
        .load()
    
    # Add metadata columns for data lineage
    stock_items_df = stock_items_df \
        .withColumn("_extract_timestamp", current_timestamp()) \
        .withColumn("_source_system", lit("WorldWideImporters_SQL")) \
        .withColumn("_batch_id", lit(f"stock_items_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"))
    
    print(f"StockItems extracted: {stock_items_df.count()} records")
    
    # Data quality checks
    null_stock_item_ids = stock_items_df.filter(col("StockItemID").isNull()).count()
    null_names = stock_items_df.filter(col("StockItemName").isNull()).count()
    zero_prices = stock_items_df.filter(col("UnitPrice") <= 0).count()
    
    if null_stock_item_ids > 0:
        print(f"WARNING: Found {null_stock_item_ids} records with null StockItemID")
    if null_names > 0:
        print(f"WARNING: Found {null_names} records with null StockItemName")
    if zero_prices > 0:
        print(f"INFO: Found {zero_prices} records with zero or negative UnitPrice")
    
    # Calculate basic statistics
    avg_unit_price = stock_items_df.agg(avg("UnitPrice")).collect()[0][0]
    max_unit_price = stock_items_df.agg(max("UnitPrice")).collect()[0][0]
    chiller_stock_count = stock_items_df.filter(col("IsChillerStock") == True).count()
    
    print(f"Average unit price: ${avg_unit_price:.2f}")
    print(f"Maximum unit price: ${max_unit_price:.2f}")
    print(f"Chiller stock items: {chiller_stock_count}")
    
    # Write to Unity Catalog bronze layer
    table_name = f"{catalog_name}.{schema_name}.stock_items"
    print(f"Writing to table: {table_name}")
    
    stock_items_df.write \
        .mode("overwrite") \
        .option("mergeSchema", "true") \
        .saveAsTable(table_name)
    
    print(f"✅ StockItems data successfully written to {table_name}")
    
except Exception as e:
    print(f"❌ Error extracting StockItems data: {str(e)}")
    raise

# COMMAND ----------

# MAGIC %md
# MAGIC ## Extract Stock Item Holdings Data

# COMMAND ----------

try:
    # Extract StockItemHoldings data (current inventory levels)
    print("Starting StockItemHoldings extraction...")
    
    stock_holdings_query = """
    SELECT 
        StockItemID,
        QuantityOnHand,
        BinLocation,
        LastStocktakeQuantity,
        LastCostPrice,
        ReorderLevel,
        TargetStockLevel,
        LastEditedBy,
        LastEditedWhen
    FROM Warehouse.StockItemHoldings
    """
    
    stock_holdings_df = spark.read \
        .format("jdbc") \
        .option("url", jdbc_url) \
        .option("query", stock_holdings_query) \
        .option("user", sql_username) \
        .option("password", sql_password) \
        .option("driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver") \
        .load()
    
    # Add metadata columns
    stock_holdings_df = stock_holdings_df \
        .withColumn("_extract_timestamp", current_timestamp()) \
        .withColumn("_source_system", lit("WorldWideImporters_SQL")) \
        .withColumn("_batch_id", lit(f"stock_holdings_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"))
    
    print(f"StockItemHoldings extracted: {stock_holdings_df.count()} records")
    
    # Data quality checks and insights
    negative_stock = stock_holdings_df.filter(col("QuantityOnHand") < 0).count()
    zero_stock = stock_holdings_df.filter(col("QuantityOnHand") == 0).count()
    below_reorder = stock_holdings_df.filter(col("QuantityOnHand") < col("ReorderLevel")).count()
    
    total_inventory_value = stock_holdings_df.agg(
        sum(col("QuantityOnHand") * col("LastCostPrice"))
    ).collect()[0][0]
    
    print(f"Items with negative stock: {negative_stock}")
    print(f"Items with zero stock: {zero_stock}")
    print(f"Items below reorder level: {below_reorder}")
    print(f"Total inventory value: ${total_inventory_value:.2f}")
    
    # Write to Unity Catalog bronze layer
    table_name = f"{catalog_name}.{schema_name}.stock_item_holdings"
    print(f"Writing to table: {table_name}")
    
    stock_holdings_df.write \
        .mode("overwrite") \
        .option("mergeSchema", "true") \
        .saveAsTable(table_name)
    
    print(f"✅ StockItemHoldings data successfully written to {table_name}")
    
except Exception as e:
    print(f"❌ Error extracting StockItemHoldings data: {str(e)}")
    raise

# COMMAND ----------

# MAGIC %md
# MAGIC ## Extract Stock Groups Data

# COMMAND ----------

try:
    # Extract StockGroups data (product categories)
    print("Starting StockGroups extraction...")
    
    stock_groups_query = """
    SELECT 
        StockGroupID,
        StockGroupName,
        LastEditedBy,
        ValidFrom,
        ValidTo
    FROM Warehouse.StockGroups
    """
    
    stock_groups_df = spark.read \
        .format("jdbc") \
        .option("url", jdbc_url) \
        .option("query", stock_groups_query) \
        .option("user", sql_username) \
        .option("password", sql_password) \
        .option("driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver") \
        .load()
    
    # Add metadata columns
    stock_groups_df = stock_groups_df \
        .withColumn("_extract_timestamp", current_timestamp()) \
        .withColumn("_source_system", lit("WorldWideImporters_SQL")) \
        .withColumn("_batch_id", lit(f"stock_groups_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"))
    
    print(f"StockGroups extracted: {stock_groups_df.count()} records")
    
    # Show stock group names for reference
    print("Stock Groups found:")
    stock_groups_df.select("StockGroupName").distinct().show(truncate=False)
    
    # Write to Unity Catalog bronze layer
    table_name = f"{catalog_name}.{schema_name}.stock_groups"
    print(f"Writing to table: {table_name}")
    
    stock_groups_df.write \
        .mode("overwrite") \
        .option("mergeSchema", "true") \
        .saveAsTable(table_name)
    
    print(f"✅ StockGroups data successfully written to {table_name}")
    
except Exception as e:
    print(f"❌ Error extracting StockGroups data: {str(e)}")
    raise

# COMMAND ----------

# MAGIC %md
# MAGIC ## Extract Stock Item Stock Groups (Many-to-Many Relationship)

# COMMAND ----------

try:
    # Extract StockItemStockGroups junction table
    print("Starting StockItemStockGroups extraction...")
    
    stock_item_groups_query = """
    SELECT 
        StockItemStockGroupID,
        StockItemID,
        StockGroupID,
        LastEditedBy,
        LastEditedWhen
    FROM Warehouse.StockItemStockGroups
    """
    
    stock_item_groups_df = spark.read \
        .format("jdbc") \
        .option("url", jdbc_url) \
        .option("query", stock_item_groups_query) \
        .option("user", sql_username) \
        .option("password", sql_password) \
        .option("driver", "com.microsoft.sqlserver.jdbc.SQLServerDriver") \
        .load()
    
    # Add metadata columns
    stock_item_groups_df = stock_item_groups_df \
        .withColumn("_extract_timestamp", current_timestamp()) \
        .withColumn("_source_system", lit("WorldWideImporters_SQL")) \
        .withColumn("_batch_id", lit(f"stock_item_groups_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"))
    
    print(f"StockItemStockGroups extracted: {stock_item_groups_df.count()} records")
    
    # Data insights
    unique_stock_items = stock_item_groups_df.select("StockItemID").distinct().count()
    unique_stock_groups = stock_item_groups_df.select("StockGroupID").distinct().count()
    
    print(f"Stock items with group assignments: {unique_stock_items}")
    print(f"Stock groups with item assignments: {unique_stock_groups}")
    
    # Write to Unity Catalog bronze layer
    table_name = f"{catalog_name}.{schema_name}.stock_item_stock_groups"
    print(f"Writing to table: {table_name}")
    
    stock_item_groups_df.write \
        .mode("overwrite") \
        .option("mergeSchema", "true") \
        .saveAsTable(table_name)
    
    print(f"✅ StockItemStockGroups data successfully written to {table_name}")
    
except Exception as e:
    print(f"❌ Error extracting StockItemStockGroups data: {str(e)}")
    raise

# COMMAND ----------

# MAGIC %md
# MAGIC ## Data Quality Summary Report

# COMMAND ----------

try:
    # Generate comprehensive summary report
    print("=== STOCK DATA EXTRACTION SUMMARY ===")
    print(f"Extraction completed at: {datetime.datetime.now()}")
    print(f"Target catalog: {catalog_name}")
    print(f"Target schema: {schema_name}")
    print("")
    
    # Get record counts from Unity Catalog tables
    stock_items_count = spark.sql(f"SELECT COUNT(*) as count FROM {catalog_name}.{schema_name}.stock_items").collect()[0]["count"]
    stock_holdings_count = spark.sql(f"SELECT COUNT(*) as count FROM {catalog_name}.{schema_name}.stock_item_holdings").collect()[0]["count"]
    stock_groups_count = spark.sql(f"SELECT COUNT(*) as count FROM {catalog_name}.{schema_name}.stock_groups").collect()[0]["count"]
    stock_item_groups_count = spark.sql(f"SELECT COUNT(*) as count FROM {catalog_name}.{schema_name}.stock_item_stock_groups").collect()[0]["count"]
    
    print(f"📊 RECORD COUNTS:")
    print(f"  - Stock Items: {stock_items_count:,}")
    print(f"  - Stock Holdings: {stock_holdings_count:,}")
    print(f"  - Stock Groups: {stock_groups_count:,}")
    print(f"  - Stock Item-Group Relationships: {stock_item_groups_count:,}")
    print("")
    
    # Advanced analytics and insights
    print("📈 BUSINESS INSIGHTS:")
    
    # Price analysis
    price_stats = spark.sql(f"""
        SELECT 
            AVG(UnitPrice) as avg_price,
            MIN(UnitPrice) as min_price,
            MAX(UnitPrice) as max_price,
            STDDEV(UnitPrice) as price_stddev
        FROM {catalog_name}.{schema_name}.stock_items
        WHERE UnitPrice > 0
    """).collect()[0]
    
    print(f"  - Average unit price: ${price_stats['avg_price']:.2f}")
    print(f"  - Price range: ${price_stats['min_price']:.2f} - ${price_stats['max_price']:.2f}")
    print(f"  - Price standard deviation: ${price_stats['price_stddev']:.2f}")
    
    # Inventory analysis
    inventory_stats = spark.sql(f"""
        SELECT 
            SUM(QuantityOnHand) as total_quantity,
            AVG(QuantityOnHand) as avg_quantity,
            COUNT(CASE WHEN QuantityOnHand = 0 THEN 1 END) as zero_stock_items,
            COUNT(CASE WHEN QuantityOnHand < ReorderLevel THEN 1 END) as below_reorder_items
        FROM {catalog_name}.{schema_name}.stock_item_holdings
    """).collect()[0]
    
    print(f"  - Total inventory quantity: {inventory_stats['total_quantity']:,}")
    print(f"  - Average quantity per item: {inventory_stats['avg_quantity']:.1f}")
    print(f"  - Items out of stock: {inventory_stats['zero_stock_items']:,}")
    print(f"  - Items below reorder level: {inventory_stats['below_reorder_items']:,}")
    
    # Category distribution
    category_distribution = spark.sql(f"""
        SELECT sg.StockGroupName, COUNT(DISTINCT sisg.StockItemID) as item_count
        FROM {catalog_name}.{schema_name}.stock_groups sg
        JOIN {catalog_name}.{schema_name}.stock_item_stock_groups sisg ON sg.StockGroupID = sisg.StockGroupID
        GROUP BY sg.StockGroupName
        ORDER BY item_count DESC
        LIMIT 5
    """).collect()
    
    print(f"  - Top 5 stock group categories:")
    for row in category_distribution:
        print(f"    * {row['StockGroupName']}: {row['item_count']} items")
    
    print("")
    print("🔍 DATA QUALITY METRICS:")
    
    # Data completeness checks
    completeness_check = spark.sql(f"""
        SELECT 
            COUNT(*) as total_items,
            COUNT(CASE WHEN StockItemName IS NOT NULL THEN 1 END) as items_with_name,
            COUNT(CASE WHEN UnitPrice > 0 THEN 1 END) as items_with_price,
            COUNT(CASE WHEN Brand IS NOT NULL THEN 1 END) as items_with_brand,
            COUNT(CASE WHEN Size IS NOT NULL THEN 1 END) as items_with_size
        FROM {catalog_name}.{schema_name}.stock_items
    """).collect()[0]
    
    total = completeness_check['total_items']
    print(f"  - Items with name: {completeness_check['items_with_name']:,} ({completeness_check['items_with_name']/total*100:.1f}%)")
    print(f"  - Items with price: {completeness_check['items_with_price']:,} ({completeness_check['items_with_price']/total*100:.1f}%)")
    print(f"  - Items with brand: {completeness_check['items_with_brand']:,} ({completeness_check['items_with_brand']/total*100:.1f}%)")
    print(f"  - Items with size: {completeness_check['items_with_size']:,} ({completeness_check['items_with_size']/total*100:.1f}%)")
    
    print("")
    print("✅ Stock data extraction completed successfully!")
    
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
