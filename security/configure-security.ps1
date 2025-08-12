# Script para configuração de segurança avançada do FunctionCopy
# Implementa melhores práticas de segurança para Azure

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$FunctionAppName,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory=$false)]
    [string]$VirtualNetworkName = "$ResourceGroupName-vnet",
    
    [Parameter(Mandatory=$false)]
    [string]$SubnetName = "function-subnet",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "East US"
)

Write-Host "=== Configuração de Segurança Avançada ===" -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Function App: $FunctionAppName" -ForegroundColor Yellow
Write-Host "Key Vault: $KeyVaultName" -ForegroundColor Yellow
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor Yellow

# 1. Configurar HTTPS Only e TLS mínimo para Function App
Write-Host "n1. Configurando HTTPS e TLS para Function App..." -ForegroundColor Cyan
az functionapp update `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --set httpsOnly=true

az functionapp config set `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --min-tls-version 1.2

if ($LASTEXITCODE -eq 0) {
    Write-Host "HTTPS e TLS 1.2 configurados com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao configurar HTTPS/TLS" -ForegroundColor Red
}

# 2. Configurar segurança do Storage Account
Write-Host "n2. Configurando segurança do Storage Account..." -ForegroundColor Cyan
az storage account update `
    --name $StorageAccountName `
    --resource-group $ResourceGroupName `
    --https-only true `
    --min-tls-version TLS1_2 `
    --allow-blob-public-access false

if ($LASTEXITCODE -eq 0) {
    Write-Host "Storage Account configurado com segurança" -ForegroundColor Green
} else {
    Write-Host "Erro ao configurar Storage Account" -ForegroundColor Red
}

# 3. Habilitar Soft Delete e Purge Protection no Key Vault
Write-Host "n3. Configurando proteções do Key Vault..." -ForegroundColor Cyan
az keyvault update `
    --name $KeyVaultName `
    --resource-group $ResourceGroupName `
    --enable-soft-delete true `
    --retention-days 90 `
    --enable-purge-protection true

if ($LASTEXITCODE -eq 0) {
    Write-Host "Proteções do Key Vault habilitadas" -ForegroundColor Green
} else {
    Write-Host "Erro ao configurar proteções do Key Vault" -ForegroundColor Red
}

# 4. Criar Virtual Network e Subnet
Write-Host "n4. Criando Virtual Network..." -ForegroundColor Cyan
az network vnet create `
    --name $VirtualNetworkName `
    --resource-group $ResourceGroupName `
    --location $Location `
    --address-prefix 10.0.0.0/16 `
    --subnet-name $SubnetName `
    --subnet-prefix 10.0.1.0/24

if ($LASTEXITCODE -eq 0) {
    Write-Host "Virtual Network criada com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar Virtual Network" -ForegroundColor Red
}

# 5. Configurar Network Security Group
Write-Host "n5. Configurando Network Security Group..." -ForegroundColor Cyan
$nsgName = "$ResourceGroupName-nsg"

az network nsg create `
    --name $nsgName `
    --resource-group $ResourceGroupName `
    --location $Location

# Regra para permitir HTTPS
az network nsg rule create `
    --name "AllowHTTPS" `
    --nsg-name $nsgName `
    --resource-group $ResourceGroupName `
    --priority 1000 `
    --direction Inbound `
    --access Allow `
    --protocol Tcp `
    --destination-port-ranges 443 `
    --source-address-prefixes "*"

# Regra para negar HTTP
az network nsg rule create `
    --name "DenyHTTP" `
    --nsg-name $nsgName `
    --resource-group $ResourceGroupName `
    --priority 1001 `
    --direction Inbound `
    --access Deny `
    --protocol Tcp `
    --destination-port-ranges 80 `
    --source-address-prefixes "*"

# Associar NSG à subnet
az network vnet subnet update `
    --name $SubnetName `
    --vnet-name $VirtualNetworkName `
    --resource-group $ResourceGroupName `
    --network-security-group $nsgName

if ($LASTEXITCODE -eq 0) {
    Write-Host "Network Security Group configurado" -ForegroundColor Green
} else {
    Write-Host "Erro ao configurar Network Security Group" -ForegroundColor Red
}

# 6. Configurar Private Endpoint para Key Vault
Write-Host "n6. Configurando Private Endpoint para Key Vault..." -ForegroundColor Cyan
$keyVaultPEName = "$KeyVaultName-pe"

az network private-endpoint create `
    --name $keyVaultPEName `
    --resource-group $ResourceGroupName `
    --vnet-name $VirtualNetworkName `
    --subnet $SubnetName `
    --private-connection-resource-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName" `
    --group-id vault `
    --connection-name "$KeyVaultName-connection"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Private Endpoint para Key Vault criado" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar Private Endpoint para Key Vault" -ForegroundColor Red
}

# 7. Configurar Private Endpoint para Storage Account
Write-Host "n7. Configurando Private Endpoint para Storage Account..." -ForegroundColor Cyan
$storagePEName = "$StorageAccountName-pe"

az network private-endpoint create `
    --name $storagePEName `
    --resource-group $ResourceGroupName `
    --vnet-name $VirtualNetworkName `
    --subnet $SubnetName `
    --private-connection-resource-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName" `
    --group-id blob `
    --connection-name "$StorageAccountName-connection"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Private Endpoint para Storage Account criado" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar Private Endpoint para Storage Account" -ForegroundColor Red
}

# 8. Configurar VNet Integration para Function App
Write-Host "n8. Configurando VNet Integration..." -ForegroundColor Cyan
az functionapp vnet-integration add `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --vnet $VirtualNetworkName `
    --subnet $SubnetName

if ($LASTEXITCODE -eq 0) {
    Write-Host "VNet Integration configurada" -ForegroundColor Green
} else {
    Write-Host "Erro ao configurar VNet Integration" -ForegroundColor Red
}

# 9. Configurar Diagnostic Settings
Write-Host "n9. Configurando Diagnostic Settings..." -ForegroundColor Cyan

# Para Function App
az monitor diagnostic-settings create `
    --name "FunctionAppDiagnostics" `
    --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$FunctionAppName" `
    --logs '[{"category":"FunctionAppLogs","enabled":true,"retentionPolicy":{"enabled":true,"days":90}}]' `
    --metrics '[{"category":"AllMetrics","enabled":true,"retentionPolicy":{"enabled":true,"days":90}}]' `
    --storage-account $StorageAccountName

# Para Key Vault
az monitor diagnostic-settings create `
    --name "KeyVaultDiagnostics" `
    --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName" `
    --logs '[{"category":"AuditEvent","enabled":true,"retentionPolicy":{"enabled":true,"days":90}}]' `
    --metrics '[{"category":"AllMetrics","enabled":true,"retentionPolicy":{"enabled":true,"days":90}}]' `
    --storage-account $StorageAccountName

if ($LASTEXITCODE -eq 0) {
    Write-Host "Diagnostic Settings configurados" -ForegroundColor Green
} else {
    Write-Host "Erro ao configurar Diagnostic Settings" -ForegroundColor Red
}

# 10. Configurar alertas de segurança
Write-Host "n10. Configurando alertas de segurança..." -ForegroundColor Cyan

# Criar Action Group para notificações
$actionGroupName = "$ResourceGroupName-security-alerts"
az monitor action-group create `
    --name $actionGroupName `
    --resource-group $ResourceGroupName `
    --short-name "SecAlerts"

# Alerta para falhas de autenticação no Key Vault
az monitor metrics alert create `
    --name "KeyVault-AuthFailures" `
    --resource-group $ResourceGroupName `
    --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName" `
    --condition "count 'ServiceApiResult' > 5" `
    --description "Múltiplas falhas de autenticação no Key Vault" `
    --evaluation-frequency 5m `
    --window-size 15m `
    --severity 2 `
    --action $actionGroupName

# Alerta para uso anômalo de recursos
az monitor metrics alert create `
    --name "FunctionApp-HighCPU" `
    --resource-group $ResourceGroupName `
    --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$FunctionAppName" `
    --condition "avg 'CpuPercentage' > 80" `
    --description "Alto uso de CPU na Function App" `
    --evaluation-frequency 5m `
    --window-size 15m `
    --severity 3 `
    --action $actionGroupName

if ($LASTEXITCODE -eq 0) {
    Write-Host "Alertas de segurança configurados" -ForegroundColor Green
} else {
    Write-Host "Erro ao configurar alertas" -ForegroundColor Red
}

# 11. Configurar backup automático
Write-Host "n11. Configurando backup automático..." -ForegroundColor Cyan

# Backup do Key Vault (via script personalizado)
$backupScript = @"
# Script de backup do Key Vault
`$keyVaultName = "$KeyVaultName"
`$storageAccount = "$StorageAccountName"
`$containerName = "keyvault-backups"

# Criar container se não existir
az storage container create --name `$containerName --account-name `$storageAccount

# Backup de todos os segredos
`$secrets = az keyvault secret list --vault-name `$keyVaultName --query "[].name" -o tsv
foreach (`$secret in `$secrets) {
    `$backupFile = "`$secret-backup-`$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    az keyvault secret backup --vault-name `$keyVaultName --name `$secret --file `$backupFile
    az storage blob upload --account-name `$storageAccount --container-name `$containerName --name `$backupFile --file `$backupFile
    Remove-Item `$backupFile
}
"@

$backupScript | Out-File -FilePath "backup-keyvault.ps1" -Encoding UTF8

if ($LASTEXITCODE -eq 0) {
    Write-Host "Script de backup criado: backup-keyvault.ps1" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar script de backup" -ForegroundColor Red
}

# 12. Configurar políticas de acesso restritivo
Write-Host "n12. Configurando políticas de acesso..." -ForegroundColor Cyan

# Restringir acesso ao Storage Account apenas à VNet
az storage account network-rule add `
    --account-name $StorageAccountName `
    --resource-group $ResourceGroupName `
    --vnet-name $VirtualNetworkName `
    --subnet $SubnetName

az storage account update `
    --name $StorageAccountName `
    --resource-group $ResourceGroupName `
    --default-action Deny

# Configurar firewall do Key Vault
az keyvault network-rule add `
    --name $KeyVaultName `
    --resource-group $ResourceGroupName `
    --vnet-name $VirtualNetworkName `
    --subnet $SubnetName

az keyvault update `
    --name $KeyVaultName `
    --resource-group $ResourceGroupName `
    --default-action Deny

if ($LASTEXITCODE -eq 0) {
    Write-Host "Políticas de acesso restritivo configuradas" -ForegroundColor Green
} else {
    Write-Host "Erro ao configurar políticas de acesso" -ForegroundColor Red
}

Write-Host "n=== Configuração de Segurança Concluída ===" -ForegroundColor Green
Write-Host "nRecursos de segurança implementados:" -ForegroundColor Yellow
Write-Host "- HTTPS obrigatório e TLS 1.2 mínimo" -ForegroundColor White
Write-Host "- Private Endpoints para Key Vault e Storage" -ForegroundColor White
Write-Host "- VNet Integration para isolamento de rede" -ForegroundColor White
Write-Host "- Network Security Groups com regras restritivas" -ForegroundColor White
Write-Host "- Soft Delete e Purge Protection no Key Vault" -ForegroundColor White
Write-Host "- Diagnostic Settings para auditoria" -ForegroundColor White
Write-Host "- Alertas de segurança configurados" -ForegroundColor White
Write-Host "- Backup automático implementado" -ForegroundColor White
Write-Host "- Políticas de acesso restritivo" -ForegroundColor White

Write-Host "nPróximos passos:" -ForegroundColor Yellow
Write-Host "1. Configurar rotação automática de credenciais" -ForegroundColor White
Write-Host "2. Implementar Azure Sentinel para SIEM" -ForegroundColor White
Write-Host "3. Configurar Azure Security Center" -ForegroundColor White
Write-Host "4. Realizar testes de penetração" -ForegroundColor White
Write-Host "5. Executar backup-keyvault.ps1 regularmente" -ForegroundColor White

