Clear-Host
$SubscriptionId = ""
$ResourceGroupName = "RG-Log-Processor-03"
$Location = "Central US"
$StorageAccountName = "stalogprocessorlss003" # Lembrete: Storage account name must be between 3 and 24 characters in length and use numbers and lower-case letters only
$FunctionAppName = "func-log-processor-lss003"
$KeyVaultName = "akv-log-processor-lss003"
$AppServicePlanName = "$FunctionAppName-plan"
$ApplicationInsightName = "$FunctionAppName-insights"
$ContainerName = "processed-logs"

$SmbServer = "Server001"
$SmbShare = "logs"
$SmbUsername = "leo"
$SmbPassword = "123Meu_"
##############################
#
# Etapas 7, 8 e 14 com erros (Possível problemas na interceptação do SSL Netskope)
#
##############################

# 1. Login e seleção da subscription
Write-Host "n1. Configurando Azure CLI..." -ForegroundColor Cyan
try {
    az account set --subscription $SubscriptionId
    Write-Host "Subscription configurada com sucesso" -ForegroundColor Green
} catch {
    Write-Host "Erro ao configurar subscription. Execute 'az login' primeiro." -ForegroundColor Red
    exit 1
}

# 2. Criar Resource Group
Write-Host "n2. Criando Resource Group..." -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location

if ($LASTEXITCODE -eq 0) {
    Write-Host "Resource Group criado com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar Resource Group" -ForegroundColor Red
    exit 1
}


# 3. Criar Storage Account
Write-Host "n3. Criando Storage Account..." -ForegroundColor Cyan
az storage account create --name $StorageAccountName --resource-group $ResourceGroupName --location $Location --sku Standard_LRS --kind StorageV2

if ($LASTEXITCODE -eq 0) {
    Write-Host "Storage Account criado com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar Storage Account" -ForegroundColor Red
    exit 1
}

# 4. Criar container no Blob Storage
Write-Host "n4. Criando container no Blob Storage..." -ForegroundColor Cyan
az storage container create --name $ContainerName --account-name $StorageAccountName

if ($LASTEXITCODE -eq 0) {
    Write-Host "Container criado com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar container" -ForegroundColor Red
    exit 1
}

# 5. Obter connection string do Storage Account
Write-Host "n5. Obtendo connection string do Storage Account..." -ForegroundColor Cyan
$StorageConnectionString = az storage account show-connection-string --name $StorageAccountName --resource-group $ResourceGroupName --query connectionString --output tsv

if ($LASTEXITCODE -eq 0) {
    Write-Host "Connection string obtida com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao obter connection string" -ForegroundColor Red
    exit 1
}

# 6. Criar Azure Key Vault
Write-Host "n6. Criando Azure Key Vault..." -ForegroundColor Cyan
az keyvault create --name $KeyVaultName --resource-group $ResourceGroupName --location $Location --sku standard --enable-rbac-authorization true

if ($LASTEXITCODE -eq 0) {
    Write-Host "Key Vault criado com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar Key Vault" -ForegroundColor Red
    exit 1
}

# 7. Criar Application Insights (ERRO)
Write-Host "n7. Criando Application Insights..." -ForegroundColor Cyan
az monitor application-insights component create --app $ApplicationInsightName --location $Location --resource-group $ResourceGroupName --kind web --application-type web
az monitor app-insights component show --app $ApplicationInsightName --resource-group $ResourceGroupName

if ($LASTEXITCODE -eq 0) {
    Write-Host "Application Insights criado com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar Application Insights" -ForegroundColor Red
    exit 1
}


# 8. Obter Instrumentation Key do Application Insights (ERRO por causa do #7)
Write-Host "n8. Obtendo Instrumentation Key..." -ForegroundColor Cyan
$InstrumentationKey = az monitor app-insights component show --app $ApplicationInsightName --resource-group $ResourceGroupName --query instrumentationKey --output tsv

if ($LASTEXITCODE -eq 0) {
    Write-Host "Instrumentation Key obtida com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao obter Instrumentation Key" -ForegroundColor Red
    exit 1
}

################################

# 9. Criar App Service Plan (Consumption)
Write-Host "n9. Criando App Service Plan..." -ForegroundColor Cyan
az functionapp plan create --name $AppServicePlanName --resource-group $ResourceGroupName --location $Location --sku B1 --is-linux

if ($LASTEXITCODE -eq 0) {
    Write-Host "App Service Plan criado com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar App Service Plan" -ForegroundColor Red
    exit 1
}

# 10. Criar Function App
Write-Host "n10. Criando Function App..." -ForegroundColor Cyan
az functionapp create --name $FunctionAppName --resource-group $ResourceGroupName --plan $AppServicePlanName --storage-account $StorageAccountName --runtime python --runtime-version 3.9 --functions-version 3 --os-type Linux # --app-insights $ApplicationInsightName

if ($LASTEXITCODE -eq 0) {
    Write-Host "Function App criada com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar Function App" -ForegroundColor Red
    exit 1
}

# 10a. Obter Instrumentation Key do Application Insights (ERRO por causa do #7)
Write-Host "n8. Obtendo Instrumentation Key..." -ForegroundColor Cyan
$InstrumentationKey = az monitor app-insights component show --app $FunctionAppName --resource-group $ResourceGroupName --query instrumentationKey --output tsv

if ($LASTEXITCODE -eq 0) {
    Write-Host "Instrumentation Key obtida com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao obter Instrumentation Key" -ForegroundColor Red
    exit 1
}

# 11. Habilitar System Assigned Managed Identity
Write-Host "n11. Habilitando Managed Identity..." -ForegroundColor Cyan
$PrincipalId = az functionapp identity assign --name $FunctionAppName --resource-group $ResourceGroupName --query principalId --output tsv

if ($LASTEXITCODE -eq 0) {
    Write-Host "Managed Identity habilitada com sucesso. Principal ID: $PrincipalId" -ForegroundColor Green
} else {
    Write-Host "Erro ao habilitar Managed Identity" -ForegroundColor Red
    exit 1
}

# 12. Aguardar propagação da Managed Identity
Write-Host "n12. Aguardando propagação da Managed Identity..." -ForegroundColor Cyan
Start-Sleep -Seconds 30

# 13. Conceder permissões ao Key Vault para a Managed Identity
Write-Host "n13. Concedendo permissões ao Key Vault..." -ForegroundColor Cyan
az role assignment create --role "Key Vault Secrets User" --assignee $PrincipalId --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Permissões concedidas com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao conceder permissões" -ForegroundColor Red
    exit 1
}

# 14. Armazenar segredos no Key Vault
Write-Host "n14. Armazenando segredos no Key Vault..." -ForegroundColor Cyan

# Armazenar credenciais SMB
az keyvault secret set --vault-name $KeyVaultName --name "smb-server" --value $SmbServer
az keyvault secret set --vault-name $KeyVaultName --name "smb-share" --value $SmbShare
az keyvault secret set --vault-name $KeyVaultName --name "smb-username" --value $SmbUsername
az keyvault secret set --vault-name $KeyVaultName --name "smb-password" --value $SmbPassword
az keyvault secret set --vault-name $KeyVaultName --name "storage-connection-string" --value $StorageConnectionString

if ($LASTEXITCODE -eq 0) {
    Write-Host "Segredos armazenados com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao armazenar segredos" -ForegroundColor Red
    exit 1
}


# 15. Configurar Application Settings (apenas configurações não sensíveis)
Write-Host "n15. Configurando Application Settings..." -ForegroundColor Cyan
az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings `
        "KEY_VAULT_URL=https://$KeyVaultName.vault.azure.net/" `
        "BLOB_CONTAINER_NAME=$ContainerName" `
        "APPINSIGHTS_INSTRUMENTATIONKEY=$InstrumentationKey" `
        "APPLICATIONINSIGHTS_CONNECTION_STRING=InstrumentationKey=$InstrumentationKey"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Application Settings configuradas com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao configurar Application Settings" -ForegroundColor Red
    exit 1
}
