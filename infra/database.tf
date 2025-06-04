resource "azurerm_mssql_server" "sql_server" {
  name                         = "${var.project_name}-${var.environment}-sqlserver"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Firewall rule to allow Azure services
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Firewall rule for Databricks subnet
resource "azurerm_mssql_firewall_rule" "allow_databricks" {
  name             = "AllowDatabricks"
  server_id        = azurerm_mssql_server.sql_server.id
  start_ip_address = "10.0.0.0"
  end_ip_address   = "10.0.255.255"
}

resource "azurerm_mssql_database" "wwi_database" {
  name           = "WorldWideImporters"
  server_id      = azurerm_mssql_server.sql_server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 32
  read_scale     = false
  sku_name       = "S0"
  zone_redundant = false

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Improved null resource with better error handling
resource "null_resource" "import_wwi" {
  triggers = {
    database_id = azurerm_mssql_database.wwi_database.id
  }

  provisioner "local-exec" {
    command = <<EOT
      if (Test-Path "import_script.sql") {
        sqlcmd -S ${azurerm_mssql_server.sql_server.fully_qualified_domain_name} -U ${var.sql_admin_username} -P ${var.sql_admin_password} -d WorldWideImporters -i import_script.sql
      } else {
        Write-Host "Warning: import_script.sql not found. Skipping database import."
      }
    EOT
    interpreter = ["pwsh", "-Command"]
  }

  depends_on = [
    azurerm_mssql_database.wwi_database,
    azurerm_mssql_firewall_rule.allow_azure_services
  ]
}
