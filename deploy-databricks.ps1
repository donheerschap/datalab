#!/usr/bin/env pwsh

# Databricks Asset Bundle Deployment Script
# This script deploys the WorldWideImporters ETL pipeline to Databricks

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod")]
    [string]$Target = "dev",
    
    [Parameter(Mandatory=$false)]
    [switch]$ValidateOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Colors for output
$Green = "`e[32m"
$Red = "`e[31m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Reset = "`e[0m"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = $Reset)
    Write-Host "$Color$Message$Reset"
}

function Test-Prerequisites {
    Write-ColorOutput "🔍 Checking prerequisites..." $Blue
    
    # Check if Databricks CLI is installed
    try {
        $databricksVersion = & databricks version 2>&1
        Write-ColorOutput "✅ Databricks CLI found: $databricksVersion" $Green
    }
    catch {
        Write-ColorOutput "❌ Databricks CLI not found. Please install it first." $Red
        Write-ColorOutput "   Run: pip install databricks-cli" $Yellow
        exit 1
    }
    
    # Check if databricks.yml exists
    if (-not (Test-Path "databricks.yml")) {
        Write-ColorOutput "❌ databricks.yml not found in current directory" $Red
        exit 1
    }
    
    # Check environment variables
    $requiredEnvVars = @("DATABRICKS_HOST", "DATABRICKS_TOKEN")
    foreach ($envVar in $requiredEnvVars) {
        if (-not [Environment]::GetEnvironmentVariable($envVar)) {
            Write-ColorOutput "❌ Environment variable $envVar is not set" $Red
            Write-ColorOutput "   Please set this variable before running the script" $Yellow
            exit 1
        }
    }
    
    Write-ColorOutput "✅ All prerequisites met" $Green
}

function Invoke-BundleValidation {
    Write-ColorOutput "🔍 Validating bundle configuration..." $Blue
    
    try {
        & databricks bundle validate --target $Target
        if ($LASTEXITCODE -ne 0) {
            throw "Bundle validation failed"
        }
        Write-ColorOutput "✅ Bundle validation successful" $Green
    }
    catch {
        Write-ColorOutput "❌ Bundle validation failed: $($_.Exception.Message)" $Red
        exit 1
    }
}

function Invoke-BundleDeployment {
    Write-ColorOutput "🚀 Deploying bundle to $Target environment..." $Blue
    
    # Prepare deployment variables
    $deployArgs = @(
        "bundle", "deploy", 
        "--target", $Target
    )
    
    if ($Force) {
        $deployArgs += "--force"
    }
    
    # Add environment-specific variables if they exist
    $sqlServerHost = [Environment]::GetEnvironmentVariable("SQL_SERVER_HOST")
    $sqlUsername = [Environment]::GetEnvironmentVariable("SQL_USERNAME")
    $sqlPassword = [Environment]::GetEnvironmentVariable("SQL_PASSWORD")
    $notificationEmail = [Environment]::GetEnvironmentVariable("NOTIFICATION_EMAIL")
    
    if ($sqlServerHost) {
        $deployArgs += "--var=sql_server_host=$sqlServerHost"
    }
    if ($sqlUsername) {
        $deployArgs += "--var=sql_username=$sqlUsername"
    }
    if ($sqlPassword) {
        $deployArgs += "--var=sql_password=$sqlPassword"
    }
    if ($notificationEmail) {
        $deployArgs += "--var=notification_email=$notificationEmail"
    }
    
    try {
        & databricks @deployArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Bundle deployment failed"
        }
        Write-ColorOutput "✅ Bundle deployed successfully" $Green
    }
    catch {
        Write-ColorOutput "❌ Bundle deployment failed: $($_.Exception.Message)" $Red
        exit 1
    }
}

function Install-InitScripts {
    Write-ColorOutput "📁 Uploading initialization scripts..." $Blue
    
    $initScriptPath = "resources/init-scripts/install-sql-driver.sh"
    $targetPath = "/databricks/init-scripts/install-sql-driver.sh"
    
    if (Test-Path $initScriptPath) {
        try {
            & databricks workspace upload $initScriptPath $targetPath --overwrite
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to upload init script"
            }
            Write-ColorOutput "✅ Init script uploaded successfully" $Green
        }
        catch {
            Write-ColorOutput "❌ Failed to upload init script: $($_.Exception.Message)" $Red
            exit 1
        }
    }
    else {
        Write-ColorOutput "⚠️  Init script not found at $initScriptPath" $Yellow
    }
}

function Test-Deployment {
    Write-ColorOutput "🧪 Testing deployment..." $Blue
    
    try {
        # Get job list and find our ETL job
        $jobsJson = & databricks jobs list --output json
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to list jobs"
        }
        
        $jobs = $jobsJson | ConvertFrom-Json
        $etlJob = $jobs.jobs | Where-Object { $_.settings.name -like "*WWI Bronze Layer ETL - $Target*" }
        
        if ($etlJob) {
            Write-ColorOutput "✅ ETL Job found with ID: $($etlJob.job_id)" $Green
            Write-ColorOutput "   Job name: $($etlJob.settings.name)" $Blue
            
            # Get detailed job information
            $jobDetails = & databricks jobs get --job-id $etlJob.job_id --output json | ConvertFrom-Json
            $taskCount = $jobDetails.settings.tasks.Count
            Write-ColorOutput "   Tasks: $taskCount" $Blue
            Write-ColorOutput "   Schedule: $($jobDetails.settings.schedule.quartz_cron_expression)" $Blue
        }
        else {
            Write-ColorOutput "❌ ETL Job not found after deployment" $Red
            exit 1
        }
    }
    catch {
        Write-ColorOutput "❌ Deployment test failed: $($_.Exception.Message)" $Red
        exit 1
    }
}

function Show-DeploymentSummary {
    Write-ColorOutput "`n=== DEPLOYMENT SUMMARY ===" $Blue
    Write-ColorOutput "Target Environment: $Target" $Green
    Write-ColorOutput "Deployment Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')" $Green
    Write-ColorOutput "Bundle: datalab-etl" $Green
    Write-ColorOutput "`nDeployed Resources:" $Blue
    Write-ColorOutput "  • ETL Job: WWI Bronze Layer ETL" $Green
    Write-ColorOutput "  • Notebooks: 3 (customers, orders, stock_items)" $Green
    Write-ColorOutput "  • Init Scripts: SQL Server JDBC driver" $Green
    Write-ColorOutput "  • Experiments: ML analytics workspace" $Green
    Write-ColorOutput "`n✅ Deployment completed successfully!" $Green
}

# Main execution
try {
    Write-ColorOutput "🚀 Starting Databricks Asset Bundle Deployment" $Blue
    Write-ColorOutput "Target: $Target" $Green
    Write-ColorOutput "Validate Only: $ValidateOnly" $Green
    Write-ColorOutput ""
    
    Test-Prerequisites
    Invoke-BundleValidation
    
    if (-not $ValidateOnly) {
        Invoke-BundleDeployment
        Install-InitScripts
        Test-Deployment
        Show-DeploymentSummary
    }
    else {
        Write-ColorOutput "✅ Validation completed successfully" $Green
        Write-ColorOutput "   Use without -ValidateOnly to deploy" $Yellow
    }
}
catch {
    Write-ColorOutput "❌ Deployment failed: $($_.Exception.Message)" $Red
    exit 1
}
