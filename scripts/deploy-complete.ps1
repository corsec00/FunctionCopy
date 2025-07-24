# Script completo para deploy da solução Azure Log Processor
# Autor: Leo Santos
# Data: $(Get-Date)

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-log-processor",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory=$false)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory=$false)]
    [string]$FunctionAppName,
    
    [Parameter(Mandatory=$true)]
    [string]$SmbServer,
    
    [Parameter(Mandatory=$true)]
    [string]$SmbShare,
    
    [Parameter(Mandatory=$true)]
    [string]$SmbUsername,
    
    [Parameter(Mandatory=$true)]
    [string]$SmbPassword
)

# Gerar nomes únicos se não fornecidos
if (-not $StorageAccountName) {
    $suffix = Get-Random -Minimum 1000 -Maximum 9999
    $StorageAccountName = "stlogprocessor$suffix"
}

if (-not $FunctionAppName) {
    $suffix = Get-Random -Minimum 1000 -Maximum 9999
    $FunctionAppName = "func-log-processor-$suffix"
}

Write-Host "=== Deploy Completo da Solução Azure Log Processor ===" -ForegroundColor Green
Write-Host "Este script irá:" -ForegroundColor Yellow
Write-Host "1. Criar toda a infraestrutura necessária" -ForegroundColor White
Write-Host "2. Fazer o deploy da Azure Function" -ForegroundColor White
Write-Host "3. Configurar todas as variáveis de ambiente" -ForegroundColor White

Write-Host "`nParâmetros:" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "Location: $Location" -ForegroundColor White
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor White
Write-Host "Function App: $FunctionAppName" -ForegroundColor White
Write-Host "SMB Server: $SmbServer" -ForegroundColor White
Write-Host "SMB Share: $SmbShare" -ForegroundColor White
Write-Host "SMB Username: $SmbUsername" -ForegroundColor White

# Verificar pré-requisitos
Write-Host "`n=== Verificando Pré-requisitos ===" -ForegroundColor Cyan

# Verificar Azure CLI
try {
    $azVersion = az --version | Select-String "azure-cli" | Select-Object -First 1
    Write-Host "✓ Azure CLI: $azVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Azure CLI não encontrado. Instale em: https://docs.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Red
    exit 1
}

# Verificar Azure Functions Core Tools
try {
    $funcVersion = func --version
    Write-Host "✓ Azure Functions Core Tools: $funcVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Azure Functions Core Tools não encontrado!" -ForegroundColor Red
    Write-Host "Instale usando: npm install -g azure-functions-core-tools@4 --unsafe-perm true" -ForegroundColor Yellow
    exit 1
}

# Verificar login no Azure
Write-Host "`nVerificando login no Azure..." -ForegroundColor Cyan
try {
    $account = az account show --query user.name --output tsv
    Write-Host "✓ Logado como: $account" -ForegroundColor Green
} catch {
    Write-Host "✗ Não logado no Azure. Execute 'az login' primeiro." -ForegroundColor Red
    exit 1
}

# Configurar subscription se fornecida
if ($SubscriptionId) {
    Write-Host "Configurando subscription: $SubscriptionId" -ForegroundColor Cyan
    az account set --subscription $SubscriptionId
}

$currentSub = az account show --query name --output tsv
Write-Host "✓ Subscription ativa: $currentSub" -ForegroundColor Green

# Confirmar antes de prosseguir
Write-Host "`n=== Confirmação ===" -ForegroundColor Yellow
Write-Host "Os recursos serão criados na subscription: $currentSub" -ForegroundColor White
$confirm = Read-Host "Deseja continuar? (s/N)"

if ($confirm -ne "s" -and $confirm -ne "S") {
    Write-Host "Operação cancelada pelo usuário" -ForegroundColor Yellow
    exit 0
}

# Executar script de criação da infraestrutura
Write-Host "`n=== Fase 1: Criando Infraestrutura ===" -ForegroundColor Green
$infraScript = Join-Path $PSScriptRoot "01-create-infrastructure.ps1"

if (-not (Test-Path $infraScript)) {
    Write-Host "Script de infraestrutura não encontrado: $infraScript" -ForegroundColor Red
    exit 1
}

& $infraScript -SubscriptionId $SubscriptionId -ResourceGroupName $ResourceGroupName -Location $Location -StorageAccountName $StorageAccountName -FunctionAppName $FunctionAppName -SmbServer $SmbServer -SmbShare $SmbShare -SmbUsername $SmbUsername -SmbPassword $SmbPassword

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro na criação da infraestrutura" -ForegroundColor Red
    exit 1
}

# Aguardar um pouco para a infraestrutura estar pronta
Write-Host "`nAguardando infraestrutura ficar pronta..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

# Executar script de deploy da função
Write-Host "`n=== Fase 2: Deploy da Function ===" -ForegroundColor Green
$deployScript = Join-Path $PSScriptRoot "02-deploy-function.ps1"

if (-not (Test-Path $deployScript)) {
    Write-Host "Script de deploy não encontrado: $deployScript" -ForegroundColor Red
    exit 1
}

$projectPath = Split-Path $PSScriptRoot -Parent
& $deployScript -FunctionAppName $FunctionAppName -ResourceGroupName $ResourceGroupName -ProjectPath $projectPath

if ($LASTEXITCODE -ne 0) {
    Write-Host "Erro no deploy da função" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Deploy Completo Finalizado! ===" -ForegroundColor Green
Write-Host "`nRecursos criados:" -ForegroundColor Yellow
Write-Host "- Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "- Storage Account: $StorageAccountName" -ForegroundColor White
Write-Host "- Function App: $FunctionAppName" -ForegroundColor White
Write-Host "- Container: processed-logs" -ForegroundColor White

Write-Host "`nA função está configurada para executar a cada 15 minutos." -ForegroundColor Cyan
Write-Host "Monitore a execução no portal Azure ou Application Insights." -ForegroundColor Cyan

Write-Host "`nURLs importantes:" -ForegroundColor Yellow
Write-Host "- Portal Azure: https://portal.azure.com" -ForegroundColor White
Write-Host "- Function App: https://$FunctionAppName.azurewebsites.net" -ForegroundColor White
Write-Host "- Storage Account: https://$StorageAccountName.blob.core.windows.net" -ForegroundColor White

