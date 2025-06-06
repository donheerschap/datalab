# GitHub Actions OIDC Setup for Databricks Deployment

This guide explains how to set up GitHub Actions with Azure OIDC authentication to deploy Databricks Asset Bundles.

## Prerequisites

1. An Azure subscription with appropriate permissions
2. A Databricks workspace in Azure
3. A GitHub repository with admin access
4. Azure CLI installed locally (for setup)

## Step 1: Create Azure Service Principal and OIDC Configuration

### 1.1 Create Service Principal

```bash
# Set variables
SUBSCRIPTION_ID="your-subscription-id"
RESOURCE_GROUP="your-databricks-resource-group"
APP_NAME="github-databricks-deployment"

# Create service principal
az ad sp create-for-rbac --name $APP_NAME --role contributor --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP --sdk-auth
```

Save the output - you'll need the `clientId`, `tenantId`, and `subscriptionId`.

### 1.2 Configure OIDC Federation

```bash
# Get your GitHub repository details
GITHUB_REPO="your-username/your-repo-name"
CLIENT_ID="client-id-from-step-1"

# Create federated credential for main branch
az ad app federated-credential create \
  --id $CLIENT_ID \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_REPO':ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for develop branch
az ad app federated-credential create \
  --id $CLIENT_ID \
  --parameters '{
    "name": "github-develop-branch", 
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:'$GITHUB_REPO':ref:refs/heads/develop",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for pull requests
az ad app federated-credential create \
  --id $CLIENT_ID \
  --parameters '{
    "name": "github-pull-requests",
    "issuer": "https://token.actions.githubusercontent.com", 
    "subject": "repo:'$GITHUB_REPO':pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

## Step 2: Grant Databricks Permissions

The service principal needs access to your Databricks workspace:

### 2.1 Add to Databricks Workspace

1. Go to your Databricks workspace
2. Navigate to **Settings** > **Identity and access**
3. Click **Service principals** > **Add service principal**
4. Enter the Application ID (Client ID) from Step 1
5. Assign appropriate permissions (e.g., **Workspace Admin** for deployment)

### 2.2 Alternative: Use Azure CLI

```bash
# Get Databricks workspace resource ID
DATABRICKS_WORKSPACE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Databricks/workspaces/your-workspace-name"

# Assign Databricks Contributor role
az role assignment create \
  --assignee $CLIENT_ID \
  --role "Contributor" \
  --scope $DATABRICKS_WORKSPACE_ID
```

## Step 3: Configure GitHub Repository Secrets

Add the following secrets to your GitHub repository:

1. Go to your GitHub repository
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Add the following repository secrets:

| Secret Name | Value | Description |
|-------------|--------|-------------|
| `ARM_CLIENT_ID` | Application (client) ID | From service principal creation |
| `ARM_TENANT_ID` | Directory (tenant) ID | From service principal creation |
| `ARM_SUBSCRIPTION_ID` | Subscription ID | Your Azure subscription ID |
| `DATABRICKS_HOST` | `https://adb-xxx.azuredatabricks.net` | Your Databricks workspace URL |

## Step 4: Configure GitHub Environments (Optional)

For additional security and approval workflows:

1. Go to **Settings** > **Environments**
2. Create environments: `development` and `production`
3. Configure protection rules:
   - **Required reviewers** for production
   - **Deployment branches** (limit to main/develop)

## Step 5: Update Databricks Configuration

Ensure your `databricks.yml` file includes the necessary variables:

```yaml
bundle:
  name: your-bundle-name

variables:
  databricks_host:
    description: "Databricks workspace hostname"
    default: "your-default-workspace.azuredatabricks.net"

targets:
  dev:
    mode: development
    workspace:
      host: https://${var.databricks_host}
      auth_type: azure-cli
    
  prod:
    mode: production
    workspace:
      host: https://${var.databricks_host}
      auth_type: azure-cli
```

## Step 6: Test the Setup

1. Push changes to your repository
2. Check the **Actions** tab for workflow execution
3. Verify deployment in your Databricks workspace

## Troubleshooting

### Common Issues

1. **"User not authorized" error**
   - Verify service principal has Databricks workspace access
   - Check that OIDC federation is configured correctly
   - Ensure the GitHub repository path in federated credentials is exact

2. **Token acquisition fails**
   - Verify all secrets are set correctly in GitHub
   - Check that the service principal exists and has appropriate permissions
   - Ensure subscription ID is correct

3. **Bundle validation fails**
   - Check `databricks.yml` syntax
   - Verify all required variables are defined
   - Ensure workspace URL is accessible

### Verification Commands

```bash
# Test Azure login
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID

# Test Databricks access
databricks workspace list

# Test bundle validation locally
databricks bundle validate --target dev
```

## Security Best Practices

1. **Least Privilege**: Grant minimum required permissions
2. **Environment Isolation**: Use separate service principals for dev/prod
3. **Regular Rotation**: Rotate credentials periodically
4. **Audit Logs**: Monitor deployment activities
5. **Branch Protection**: Require reviews for production deployments

## Additional Resources

- [Azure OIDC with GitHub Actions](https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [Databricks Asset Bundles](https://docs.databricks.com/en/dev-tools/bundles/index.html)
- [GitHub Actions Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments)
