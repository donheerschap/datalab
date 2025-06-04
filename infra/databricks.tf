resource "azurerm_databricks_workspace" "workspace" {
  name                = "${var.project_name}-${var.environment}-databricks"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "premium"

  custom_parameters {
    virtual_network_id  = azurerm_virtual_network.databricks_vnet.id
    public_subnet_name  = azurerm_subnet.public_subnet.name
    private_subnet_name = azurerm_subnet.private_subnet.name
    
    # Additional security configurations
    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.public_subnet_nsg.id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.private_subnet_nsg.id
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.public_subnet_nsg,
    azurerm_subnet_network_security_group_association.private_subnet_nsg
  ]
}

resource "databricks_metastore" "unity_catalog" {
  name          = "${var.project_name}-${var.environment}-unity-catalog"
  region        = azurerm_resource_group.main.location
  force_destroy = true

  depends_on = [azurerm_databricks_workspace.workspace]
}

resource "databricks_metastore_assignment" "assignment" {
  workspace_id = azurerm_databricks_workspace.workspace.id
  metastore_id = databricks_metastore.unity_catalog.id

  depends_on = [
    azurerm_databricks_workspace.workspace,
    databricks_metastore.unity_catalog
  ]
}
