output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "The location of the resource group"
  value       = azurerm_resource_group.main.location
}

output "databricks_workspace_id" {
  description = "The ID of the Databricks workspace"
  value       = azurerm_databricks_workspace.workspace.id
}

output "databricks_workspace_numeric_id" {
  description = "The numeric ID of the Databricks workspace"
  value       = azurerm_databricks_workspace.workspace.workspace_id
}

output "databricks_workspace_url" {
  description = "The URL of the Databricks workspace"
  value       = azurerm_databricks_workspace.workspace.workspace_url
}

output "sql_server_fqdn" {
  description = "The fully qualified domain name of the SQL server"
  value       = azurerm_mssql_server.sql_server.fully_qualified_domain_name
}

output "virtual_network_id" {
  description = "The ID of the virtual network"
  value       = azurerm_virtual_network.databricks_vnet.id
}

output "metastore_id" {
  description = "The ID of the Unity Catalog metastore"
  value       = databricks_metastore.unity_catalog.id
}
