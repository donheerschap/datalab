#!/bin/bash

# Databricks init script to install SQL Server JDBC driver
# This script ensures the Microsoft SQL Server JDBC driver is available for all notebooks

echo "Starting SQL Server JDBC driver installation..."

# Create directory for custom drivers if it doesn't exist
mkdir -p /databricks/jars

# Download Microsoft SQL Server JDBC driver if not already present
JDBC_JAR="/databricks/jars/mssql-jdbc-12.4.2.jre8.jar"

if [ ! -f "$JDBC_JAR" ]; then
    echo "Downloading Microsoft SQL Server JDBC driver..."
    
    # Download the JDBC driver
    wget -O "$JDBC_JAR" "https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/12.4.2.jre8/mssql-jdbc-12.4.2.jre8.jar"
    
    if [ $? -eq 0 ]; then
        echo "✅ SQL Server JDBC driver downloaded successfully"
        chmod 644 "$JDBC_JAR"
    else
        echo "❌ Failed to download SQL Server JDBC driver"
        exit 1
    fi
else
    echo "✅ SQL Server JDBC driver already exists"
fi

# Verify the driver file
if [ -f "$JDBC_JAR" ]; then
    echo "JDBC driver size: $(du -h $JDBC_JAR | cut -f1)"
    echo "JDBC driver path: $JDBC_JAR"
else
    echo "❌ JDBC driver verification failed"
    exit 1
fi

# Set proper permissions
chown root:root "$JDBC_JAR"
chmod 644 "$JDBC_JAR"

echo "✅ SQL Server JDBC driver installation completed successfully"
