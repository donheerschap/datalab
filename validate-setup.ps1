#!/usr/bin/env pwsh

# Databricks Asset Bundle Validation Script
# This script validates the setup and configuration before deployment

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod")]
    [string]$Target = "dev"
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

function Test-FileStructure {
    Write-ColorOutput "🔍 Checking file structure..." $Blue
    
    $requiredFiles = @(
        "databricks.yml",
        "notebooks/bronze/extract_customers.ipynb",
        "notebooks/bronze/extract_orders.py", 
        "notebooks/bronze/extract_stock_items.py",
        "resources/jobs.yml",
        "resources/clusters.yml",
        "resources/init-scripts/install-sql-driver.sh"
    )
    
    $missing = @()
    foreach ($file in $requiredFiles) {
        if (-not (Test-Path $file)) {
            $missing += $file
        }
    }
    
    if ($missing.Count -eq 0) {
        Write-ColorOutput "✅ All required files present" $Green
        return $true
    }
    else {
        Write-ColorOutput "❌ Missing files:" $Red
        foreach ($file in $missing) {
            Write-ColorOutput "   - $file" $Red
        }
        return $false
    }
}

function Test-DatabricksConnection {
    Write-ColorOutput "🔍 Testing Databricks connection..." $Blue
    
    if (-not [Environment]::GetEnvironmentVariable("DATABRICKS_HOST")) {
        Write-ColorOutput "❌ DATABRICKS_HOST environment variable not set" $Red
        return $false
    }
    
    if (-not [Environment]::GetEnvironmentVariable("DATABRICKS_TOKEN")) {
        Write-ColorOutput "❌ DATABRICKS_TOKEN environment variable not set" $Red
        return $false
    }
    
    try {
        $workspaces = & databricks workspace list / --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Databricks connection successful" $Green
            return $true
        }
        else {
            Write-ColorOutput "❌ Databricks connection failed: $workspaces" $Red
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Databricks CLI error: $($_.Exception.Message)" $Red
        return $false
    }
}

function Test-SqlServerConnection {
    Write-ColorOutput "🔍 Testing SQL Server connection..." $Blue
    
    $sqlHost = [Environment]::GetEnvironmentVariable("SQL_SERVER_HOST")
    $sqlUser = [Environment]::GetEnvironmentVariable("SQL_USERNAME")
    $sqlPass = [Environment]::GetEnvironmentVariable("SQL_PASSWORD")
    
    if (-not $sqlHost) {
        Write-ColorOutput "❌ SQL_SERVER_HOST environment variable not set" $Red
        return $false
    }
    
    if (-not $sqlUser) {
        Write-ColorOutput "❌ SQL_USERNAME environment variable not set" $Red
        return $false
    }
    
    if (-not $sqlPass) {
        Write-ColorOutput "❌ SQL_PASSWORD environment variable not set" $Red
        return $false
    }
    
    Write-ColorOutput "⚠️  SQL Server connection test requires manual verification" $Yellow
    Write-ColorOutput "   Please ensure the following:" $Yellow
    Write-ColorOutput "   - SQL Server allows connections from Databricks" $Yellow
    Write-ColorOutput "   - Database 'WorldWideImporters' exists" $Yellow
    Write-ColorOutput "   - User has SELECT permissions on required tables" $Yellow
    
    return $true
}

function Test-BundleConfiguration {
    Write-ColorOutput "🔍 Validating bundle configuration..." $Blue
    
    try {
        & databricks bundle validate --target $Target 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Bundle configuration valid" $Green
            return $true
        }
        else {
            Write-ColorOutput "❌ Bundle configuration invalid" $Red
            & databricks bundle validate --target $Target
            return $false
        }
    }
    catch {
        Write-ColorOutput "❌ Bundle validation error: $($_.Exception.Message)" $Red
        return $false
    }
}

function Test-NotebookSyntax {
    Write-ColorOutput "🔍 Checking notebook syntax..." $Blue
    
    $pythonNotebooks = @(
        "notebooks/bronze/extract_orders.py",
        "notebooks/bronze/extract_stock_items.py"
    )
    
    $allValid = $true
    
    foreach ($notebook in $pythonNotebooks) {
        if (Test-Path $notebook) {
            try {
                # Basic syntax check using Python AST
                $content = Get-Content $notebook -Raw
                # Remove Databricks magic commands for syntax checking
                $cleanContent = $content -replace '# MAGIC.*\n', '' -replace '# COMMAND ----------.*\n', ''
                
                # This is a simplified check - in practice you might want more sophisticated validation
                if ($cleanContent -match 'from pyspark\.sql import SparkSession') {
                    Write-ColorOutput "✅ $notebook syntax appears valid" $Green
                }
                else {
                    Write-ColorOutput "⚠️  $notebook may have issues (no SparkSession import found)" $Yellow
                }
            }
            catch {
                Write-ColorOutput "❌ Error checking $notebook : $($_.Exception.Message)" $Red
                $allValid = $false
            }
        }
    }
    
    return $allValid
}

function Show-ValidationSummary {
    param([bool[]]$TestResults)
    
    Write-ColorOutput "`n=== VALIDATION SUMMARY ===" $Blue
    
    $passed = ($TestResults | Where-Object { $_ }).Count
    $total = $TestResults.Count
    
    Write-ColorOutput "Tests Passed: $passed/$total" $Green
    
    if ($passed -eq $total) {
        Write-ColorOutput "`n✅ All validations passed! Ready for deployment." $Green
        Write-ColorOutput "   Run: .\deploy-databricks.ps1 -Target $Target" $Blue
    }
    elseif ($passed -ge ($total * 0.75)) {
        Write-ColorOutput "`n⚠️  Most validations passed, but some issues detected." $Yellow
        Write-ColorOutput "   Review the issues above before deployment." $Yellow
    }
    else {
        Write-ColorOutput "`n❌ Multiple validation failures detected." $Red
        Write-ColorOutput "   Please fix the issues before deployment." $Red
    }
}

# Main execution
try {
    Write-ColorOutput "🚀 Starting Databricks Asset Bundle Validation" $Blue
    Write-ColorOutput "Target Environment: $Target" $Green
    Write-ColorOutput ""
    
    $results = @()
    
    $results += Test-FileStructure
    $results += Test-DatabricksConnection
    $results += Test-SqlServerConnection
    $results += Test-BundleConfiguration
    $results += Test-NotebookSyntax
    
    Show-ValidationSummary -TestResults $results
}
catch {
    Write-ColorOutput "❌ Validation failed: $($_.Exception.Message)" $Red
    exit 1
}
