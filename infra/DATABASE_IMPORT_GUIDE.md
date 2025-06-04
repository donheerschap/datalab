# WorldWideImporters Database Import Guide

This guide provides two methods to get WorldWideImporters data into your Azure SQL Database.

## Method 1: Sample Data (Recommended for Testing) ✅

Use the **Azure SQL Database compatible sample data** in `worldwideimporters_azure_sample.sql`:

```bash
# After your Terraform deployment is complete:
# 1. Connect to your Azure SQL Database using Azure Data Studio, SSMS, or Azure portal Query Editor
# 2. Run the worldwideimporters_azure_sample.sql script
```

**Advantages:**
- ✅ Works directly with Azure SQL Database
- ✅ No additional downloads required  
- ✅ Creates proper schema and relationships
- ✅ Includes representative sample data
- ✅ Perfect for development and testing

## Method 2: Full WorldWideImporters Database (Production-like Data) 📊

For the complete WorldWideImporters database with full datasets:

### Option A: Azure Portal Import (Easiest)

1. **Download the BACPAC file:**
   ```bash
   # Download from Microsoft's official releases
   https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Standard.bacpac
   ```

2. **Import via Azure Portal:**
   - Go to Azure Portal → SQL databases → Your database
   - Click "Import database" 
   - Upload the BACPAC file
   - Configure import settings
   - Wait for import completion (15-30 minutes)

### Option B: Azure CLI Import

```bash
# Upload BACPAC to storage account first
az storage blob upload \
  --account-name <storage-account> \
  --container-name imports \
  --name WideWorldImporters.bacpac \
  --file ./WideWorldImporters-Standard.bacpac

# Import from storage
az sql db import \
  --resource-group <resource-group> \
  --server <server-name> \
  --name <database-name> \
  --storage-key-type StorageAccessKey \
  --storage-key <storage-key> \
  --storage-uri https://<storage-account>.blob.core.windows.net/imports/WideWorldImporters.bacpac \
  --admin-user <admin-username> \
  --admin-password <admin-password>
```

### Option C: SQL Server Management Studio (SSMS)

1. Connect to your Azure SQL Database
2. Right-click database → Tasks → Import Data-tier Application
3. Select the BACPAC file
4. Follow the import wizard

## Integration with Your Terraform Deployment

After your Terraform deployment completes, you can run either script:

### For Sample Data (Method 1):
```bash
# Get connection details from Terraform output
terraform output database_connection_string

# Connect and run the sample script
sqlcmd -S <server-name>.database.windows.net -d <database-name> -U <admin-user> -P <password> -i worldwideimporters_azure_sample.sql
```

### Database Connection Details
Your Terraform deployment creates:
- **Server:** `${var.project_name}-${var.environment}-sql-server.database.windows.net`
- **Database:** `${var.project_name}-${var.environment}-sql-db`
- **Admin User:** As specified in `terraform.tfvars`
- **Password:** As specified in `terraform.tfvars` (consider using Key Vault)

## File Structure Overview

```
infra/
├── worldwideimporters_azure_sample.sql    # ✅ Azure SQL Database compatible sample data
├── main.tf                                # Terraform main configuration  
├── database.tf                            # Azure SQL Database resources
└── terraform.tfvars.example              # Configuration template
```

## Important Notes

⚠️ **Azure SQL Database vs SQL Server Differences:**
- Azure SQL Database is a **managed PaaS service**
- Does NOT support: `xp_cmdshell`, `RESTORE DATABASE`, local file system access
- DOES support: BACPAC import/export, T-SQL queries, stored procedures

✅ **Recommendations:**
- Use **Method 1** (sample data) for development/testing
- Use **Method 2** (BACPAC import) for production-like scenarios
- Always test with sample data first before importing large datasets

## Troubleshooting

**Connection Issues:**
- Verify firewall rules allow your IP
- Check admin credentials in `terraform.tfvars`
- Ensure database is in "Online" state

**Import Issues:**
- BACPAC files must be compatible with Azure SQL Database version
- Check file size limits (Azure SQL Database has size constraints)
- Monitor import progress in Azure portal

**Performance:**
- Consider scaling up database tier during large imports
- Scale back down after import completes to save costs
