variable "location" {
  description = "The Azure region where resources will be deployed"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "databricks_account_id" {
  description = "The Databricks account ID"
  type        = string
}

variable "azure_client_id" {
  description = "The Azure Client ID for Databricks authentication"
  type        = string
  default     = ""
}

variable "azure_tenant_id" {
  description = "The Azure Tenant ID for Databricks authentication"
  type        = string
  default     = ""
}

variable "sql_admin_username" {
  description = "The administrator username for the SQL server"
  type        = string
}

variable "sql_admin_password" {
  description = "The administrator password for the SQL server"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "The environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "datalab"
}
