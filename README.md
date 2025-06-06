# WorldWideImporters Databricks Asset Bundle

This Databricks Asset Bundle (DAB) implements an ETL pipeline that extracts data from the WorldWideImporters SQL Server database and loads it into Unity Catalog's bronze layer for further analytics processing.

## 🏗️ Architecture Overview

```
SQL Server (WWI) → Databricks Jobs → Unity Catalog (Bronze Layer)
                                  ↓
                            Silver Layer (Future)
                                  ↓
                             Gold Layer (Future)
```

## 📁 Project Structure

```
datalab/
├── databricks.yml                    # Main bundle configuration
├── deploy-databricks.ps1            # Local deployment script
├── notebooks/
│   └── bronze/
│       ├── extract_customers.ipynb  # Customer data extraction
│       ├── extract_orders.py        # Orders data extraction
│       └── extract_stock_items.py   # Stock items extraction
├── resources/
│   ├── jobs.yml                     # Job definitions
│   ├── clusters.yml                 # Cluster configurations
│   └── init-scripts/
│       └── install-sql-driver.sh    # SQL Server JDBC driver setup
└── .github/
    └── workflows/
        └── deploy-databricks.yaml   # CI/CD pipeline
```

## 🎯 Features

### Data Extraction Jobs
- **Customer Data**: Extracts customer information with data quality validation
- **Orders Data**: Extracts sales orders and order lines with business metrics
- **Stock Items**: Extracts inventory data including holdings and categories

### Data Quality & Monitoring
- Comprehensive data validation checks
- Automatic data profiling and statistics
- Email notifications on job success/failure
- Detailed logging and error handling

### Infrastructure as Code
- Declarative configuration using Databricks Asset Bundles
- Environment-specific deployments (dev/prod)
- Automated cluster provisioning and management
- Version-controlled infrastructure

## 🚀 Getting Started

### Prerequisites

1. **Databricks CLI** (v0.210.0 or later)
   ```powershell
   pip install databricks-cli
   ```

2. **Environment Variables**
   ```powershell
   $env:DATABRICKS_HOST = "https://your-databricks-instance.cloud.databricks.com"
   $env:DATABRICKS_TOKEN = "your-databricks-token"
   $env:SQL_SERVER_HOST = "your-sql-server.database.windows.net"
   $env:SQL_USERNAME = "your-sql-username"
   $env:SQL_PASSWORD = "your-sql-password"
   $env:NOTIFICATION_EMAIL = "your-email@company.com"
   ```

3. **Unity Catalog Setup**
   - Ensure Unity Catalog is enabled in your Databricks workspace
   - Create the target catalog (`don_datalab_catalog` by default)

### Local Deployment

1. **Validate Configuration**
   ```powershell
   .\deploy-databricks.ps1 -Target dev -ValidateOnly
   ```

2. **Deploy to Development**
   ```powershell
   .\deploy-databricks.ps1 -Target dev
   ```

3. **Deploy to Production**
   ```powershell
   .\deploy-databricks.ps1 -Target prod
   ```

### CI/CD Deployment

The bundle includes GitHub Actions workflows for automated deployment:

- **Trigger**: Push to `develop` (dev) or `main` (prod) branches
- **Secrets Required**:
  - `DATABRICKS_HOST`
  - `DATABRICKS_TOKEN`
  - `SQL_SERVER_HOST`
  - `SQL_USERNAME`
  - `SQL_PASSWORD`
  - `NOTIFICATION_EMAIL`

## 📊 Data Pipeline Details

### Bronze Layer Tables

| Table | Source | Description | Partitioning |
|-------|--------|-------------|--------------|
| `customers` | Sales.Customers | Customer master data | CustomerID |
| `orders` | Sales.Orders | Sales order headers | OrderDate |
| `order_lines` | Sales.OrderLines | Order line items | None |
| `stock_items` | Warehouse.StockItems | Product catalog | None |
| `stock_item_holdings` | Warehouse.StockItemHoldings | Current inventory | None |
| `stock_groups` | Warehouse.StockGroups | Product categories | None |
| `stock_item_stock_groups` | Warehouse.StockItemStockGroups | Product-category mapping | None |

### Data Quality Checks

Each extraction job includes:
- **Null Value Detection**: Identifies missing required fields
- **Data Type Validation**: Ensures proper data types
- **Business Rule Validation**: Validates business constraints
- **Statistical Profiling**: Generates data distribution metrics
- **Completeness Metrics**: Tracks data completeness percentages

### Metadata Columns

All tables include these metadata columns for data lineage:
- `_extract_timestamp`: When the data was extracted
- `_source_system`: Source system identifier
- `_batch_id`: Unique batch identifier

## ⚙️ Configuration

### Bundle Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `catalog_name` | Unity Catalog name | `don_datalab_catalog` |
| `schema_name` | Bronze layer schema | `bronze` |
| `sql_server_host` | SQL Server hostname | Required |
| `sql_database_name` | Database name | `WorldWideImporters` |
| `sql_username` | SQL Server username | Required |
| `sql_password` | SQL Server password | Required |
| `notification_email` | Alert email address | `admin@example.com` |

### Job Schedule

- **Frequency**: Daily at 2:00 AM UTC
- **Cron Expression**: `0 0 2 * * ?`
- **Status**: Paused by default (enable after testing)
- **Timeout**: 2 hours maximum
- **Concurrency**: 1 (prevents overlapping runs)

## 🔧 Troubleshooting

### Common Issues

1. **SQL Server Connection Failed**
   - Verify firewall rules allow Databricks IP ranges
   - Check SQL Server authentication settings
   - Ensure database exists and user has permissions

2. **Unity Catalog Access Denied**
   - Verify catalog exists and user has CREATE TABLE permissions
   - Check workspace Unity Catalog configuration
   - Ensure proper RBAC assignments

3. **Job Timeout**
   - Check network connectivity to SQL Server
   - Monitor cluster resource utilization
   - Consider increasing timeout or cluster size

### Monitoring & Debugging

1. **Job Logs**: Check Databricks job run logs for detailed error messages
2. **Cluster Logs**: Review cluster event logs for infrastructure issues
3. **SQL Server Logs**: Monitor SQL Server for connection and query issues
4. **Email Alerts**: Configure notification email for job failures

## 🔐 Security Best Practices

### Credentials Management
- Store sensitive values in Databricks secrets or Azure Key Vault
- Use service principals for production deployments
- Rotate credentials regularly

### Network Security
- Configure VNet peering between Databricks and SQL Server
- Use private endpoints where possible
- Implement network security groups

### Data Access Control
- Implement row-level security where needed
- Use Unity Catalog's built-in RBAC
- Audit data access regularly

## 📈 Performance Optimization

### Cluster Configuration
- Use node types appropriate for workload (Standard_DS3_v2 recommended)
- Enable auto-scaling for variable workloads
- Configure appropriate auto-termination

### Query Optimization
- Use column pruning and predicate pushdown
- Implement incremental loading for large tables
- Consider partitioning strategies for large datasets

### Cost Management
- Use Spot instances for non-critical workloads
- Monitor cluster utilization and right-size
- Implement auto-termination policies

## 🚦 Next Steps

1. **Silver Layer Development**: Create transformations for cleaned/enriched data
2. **Gold Layer Analytics**: Build aggregated tables for reporting
3. **Delta Live Tables**: Consider migrating to DLT for complex pipelines
4. **ML Integration**: Add machine learning workflows
5. **Real-time Processing**: Implement streaming for real-time data

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Databricks job logs and error messages
3. Contact your Databricks administrator
4. Refer to [Databricks Asset Bundles documentation](https://docs.databricks.com/dev-tools/bundles/index.html)
