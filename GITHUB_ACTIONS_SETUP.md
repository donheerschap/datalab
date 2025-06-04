# GitHub Actions Setup Guide

## Required GitHub Secrets

You need to set up the following secrets in your GitHub repository:

### Azure Authentication (Required for OIDC)
- `ARM_CLIENT_ID` - Azure Application (client) ID
- `ARM_TENANT_ID` - Azure Directory (tenant) ID  
- `ARM_SUBSCRIPTION_ID` - Azure subscription ID

### Application Secrets (Required)
- `DATABRICKS_ACCOUNT_ID` - Your Databricks account ID (e.g., "b401b61a-73bf-457d-82a5-4aa28f824091")
- `SQL_ADMIN_USERNAME` - SQL Server admin username (e.g., "sqladmin")
- `SQL_ADMIN_PASSWORD` - SQL Server admin password (must be strong)

## Optional GitHub Variables

You can set up these variables to customize deployment settings (if not set, defaults will be used):

- `AZURE_LOCATION` - Azure region (default: "West Europe")
- `RESOURCE_GROUP_NAME` - Resource group name (default: "don-datalab-rg")
- `ENVIRONMENT` - Environment name (default: "dev")
- `PROJECT_NAME` - Project name (default: "don-datalab")

## Setting up Secrets and Variables

### In GitHub Repository:
1. Go to Settings → Secrets and variables → Actions
2. Add each secret under the "Secrets" tab
3. Add each variable under the "Variables" tab

### Setting up Azure OIDC Authentication:

1. **Create an Azure App Registration:**
   ```bash
   az ad app create --display-name "GitHub-DataLab-OIDC"
   ```

2. **Create a service principal:**
   ```bash
   az ad sp create --id <app-id-from-step-1>
   ```

3. **Add federated credentials for GitHub:**
   ```bash
   az ad app federated-credential create \
     --id <app-id> \
     --parameters '{
       "name": "GitHub-DataLab",
       "issuer": "https://token.actions.githubusercontent.com",
       "subject": "repo:<your-github-username>/<your-repo-name>:ref:refs/heads/main",
       "audiences": ["api://AzureADTokenExchange"]
     }'
   ```

4. **Assign Contributor role to the service principal:**
   ```bash
   az role assignment create \
     --assignee <service-principal-id> \
     --role Contributor \
     --scope /subscriptions/<subscription-id>
   ```

## Testing the Workflow

Once all secrets and variables are configured, push changes to the main branch to trigger the deployment workflow.

The workflow will:
1. Authenticate with Azure using OIDC
2. Create the terraform.tfvars file from secrets/variables
3. Initialize Terraform
4. Plan the deployment
5. Apply the changes

## Security Best Practices

- Never commit terraform.tfvars files to Git (they're in .gitignore)
- Use strong passwords for SQL admin accounts
- Regularly rotate secrets
- Use least-privilege access for the Azure service principal
