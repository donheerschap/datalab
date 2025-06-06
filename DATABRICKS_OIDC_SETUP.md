# Databricks OIDC Setup Guide

## Overview

The updated GitHub Actions workflow (`deploy-databricks.yaml`) now uses Azure Entra ID (OIDC) authentication instead of long-lived Databricks tokens. This is a more secure approach that leverages federated identity credentials.

## Authentication Flow

1. **GitHub OIDC Token**: GitHub generates a short-lived OIDC token
2. **Azure Login**: Uses OIDC token to authenticate with Azure
3. **AAD Token**: Gets Azure Active Directory token for Databricks resource
4. **Databricks Authentication**: Uses AAD token to authenticate with Databricks

## Required Setup

### 1. Azure App Registration

Create an Azure App Registration with the following configuration:

```bash
# Create App Registration
az ad app create --display-name "GitHub-Databricks-OIDC" --sign-in-audience AzureADMyOrg

# Get the Application ID
APP_ID=$(az ad app list --display-name "GitHub-Databricks-OIDC" --query "[0].appId" -o tsv)

# Create Service Principal
az ad sp create --id $APP_ID

# Get Service Principal Object ID
SP_OBJECT_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv)
```

### 2. Federated Identity Credentials

Add federated identity credentials for your GitHub repository:

```bash
# For main branch deployments
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_GITHUB_ORG/YOUR_REPO_NAME:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# For develop branch deployments  
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-develop-branch", 
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:YOUR_GITHUB_ORG/YOUR_REPO_NAME:ref:refs/heads/develop",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# For workflow_dispatch (manual runs)
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-workflow-dispatch",
    "issuer": "https://token.actions.githubusercontent.com", 
    "subject": "repo:YOUR_GITHUB_ORG/YOUR_REPO_NAME:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### 3. Azure Permissions

Grant the Service Principal necessary permissions:

```bash
# Get your subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Get your resource group name (where Databricks workspace is deployed)
RESOURCE_GROUP="your-resource-group-name"

# Get Databricks workspace name
DATABRICKS_WORKSPACE="your-databricks-workspace-name"

# Assign Contributor role to the resource group (for managing Databricks resources)
az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"

# Assign Databricks Workspace Contributor role (if using Azure RBAC for Databricks)
az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role "Databricks Workspace Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Databricks/workspaces/$DATABRICKS_WORKSPACE"
```

### 4. GitHub Repository Secrets

Add the following secrets to your GitHub repository:

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `ARM_CLIENT_ID` | Application (client) ID of the App Registration | `12345678-1234-1234-1234-123456789012` |
| `ARM_TENANT_ID` | Directory (tenant) ID of your Azure AD | `87654321-4321-4321-4321-210987654321` |
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID | `11111111-2222-3333-4444-555555555555` |
| `DATABRICKS_HOST` | Databricks workspace URL | `https://adb-1234567890123456.7.azuredatabricks.net` |

#### Environment-Specific Secrets

For **Development** environment:
- `SQL_SERVER_HOST` - SQL Server hostname for dev
- `SQL_USERNAME` - SQL Server username for dev  
- `SQL_PASSWORD` - SQL Server password for dev
- `NOTIFICATION_EMAIL` - Email for dev notifications

For **Production** environment:
- `SQL_SERVER_HOST_PROD` - SQL Server hostname for prod
- `SQL_USERNAME_PROD` - SQL Server username for prod
- `SQL_PASSWORD_PROD` - SQL Server password for prod  
- `NOTIFICATION_EMAIL_PROD` - Email for prod notifications

### 5. GitHub Environments

Create GitHub environments to add approval workflows:

1. Go to your repository Settings → Environments
2. Create `development` environment
3. Create `production` environment
4. Configure protection rules (optional):
   - Required reviewers for production
   - Wait timer before deployment
   - Restrict to specific branches

## Workflow Features

### Security Benefits

✅ **No long-lived tokens** - Uses short-lived AAD tokens  
✅ **Federated identity** - No secrets stored in GitHub for authentication  
✅ **Environment-specific secrets** - Different credentials per environment  
✅ **Approval workflows** - Protection for production deployments  

### Deployment Process

1. **Validation Job**: Validates bundle configuration
2. **Authentication**: Gets AAD token using OIDC
3. **Deployment**: Deploys to appropriate environment based on branch
4. **Verification**: Validates successful deployment
5. **Summary**: Creates deployment summary with details

### Branch Strategy

- **`develop` branch** → Development environment
- **`main` branch** → Production environment  
- **Manual dispatch** → Choose environment

## Troubleshooting

### Common Issues

1. **"AADSTS70021: No matching federated identity record found"**
   - Check federated identity credential subject matches exactly
   - Ensure credential is for the correct repository

2. **"Insufficient privileges to complete the operation"**
   - Verify Service Principal has correct role assignments
   - Check if Azure RBAC is enabled for Databricks workspace

3. **"databricks bundle validate failed"**
   - Ensure all required variables are passed to the bundle
   - Check `databricks.yml` syntax and variable references

4. **"Job creation failed"**
   - Verify Unity Catalog permissions
   - Check if cluster configuration is valid

### Validation Commands

Test the setup locally:

```bash
# Login with Service Principal
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID

# Get AAD token for Databricks
export DATABRICKS_AAD_TOKEN=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --query accessToken --output tsv)

# Test Databricks authentication
databricks workspace list

# Validate bundle
databricks bundle validate --target dev --var="databricks_host=https://your-workspace.azuredatabricks.net"
```

## Next Steps

1. Set up Azure App Registration and federated credentials
2. Configure GitHub repository secrets and environments  
3. Test deployment workflow with a small change
4. Monitor deployment logs and adjust as needed
5. Set up production approval workflows if required

The workflow is now ready to deploy your Databricks Asset Bundle securely using Azure Entra ID authentication!
