# Script para criação da infraestrutura Azure para Log Processor Function com Azure Key Vault
# Autor: Leo Santos
# Data: $(Get-Date)
# Exemplo de execução:
# .\01-create-infrastructure.ps1 -SubscriptionId "sua-subscription-id" -ResourceGroupName "rg-log-processor" -Location "East US" -StorageAccountName "stlogprocessor$(Get-Random)" -FunctionAppName "func-log-processor-$(Get-Random)" -KeyVaultName "kv-log-processor-$(Get-Random)" -SmbServer "servidor-01" -SmbShare "Shared02" -SmbUsername "seu_usuario" -SmbPassword "sua_senha"

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory=$true)]
    [string]$FunctionAppName,
    
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$true)]
    [string]$SmbServer,
    
    [Parameter(Mandatory=$true)]
    [string]$SmbShare,
    
    [Parameter(Mandatory=$true)]
    [string]$SmbUsername,
    
    [Parameter(Mandatory=$true)]
    [SecureString]$SmbPassword
)

# Configurações
$AppServicePlanName = "$FunctionAppName-plan"
$ApplicationInsightName = "$FunctionAppName-insights"
$ContainerName = "processed-logs"

Write-Host "=== Iniciando criação da infraestrutura Azure ===" -ForegroundColor Green
Write-Host "Subscription: $SubscriptionId" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor Yellow
Write-Host "Function App: $FunctionAppName" -ForegroundColor Yellow
Write-Host "Key Vault: $KeyVaultName" -ForegroundColor Yellow


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

# 7. Criar Application Insights
Write-Host "n7. Criando Application Insights..." -ForegroundColor Cyan
az monitor app-insights component create --app $ApplicationInsightName --location $Location --resource-group $ResourceGroupName --kind web --application-type web

if ($LASTEXITCODE -eq 0) {
    Write-Host "Application Insights criado com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar Application Insights" -ForegroundColor Red
    exit 1
}


# 8. Obter Instrumentation Key do Application Insights 
Write-Host "n8. Obtendo Instrumentation Key..." -ForegroundColor Cyan
$InstrumentationKey = az monitor app-insights component show --app $ApplicationInsightName --resource-group $ResourceGroupName --query instrumentationKey --output tsv

if ($LASTEXITCODE -eq 0) {
    Write-Host "Instrumentation Key obtida com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao obter Instrumentation Key" -ForegroundColor Red
    exit 1
}

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
az functionapp create --name $FunctionAppName --resource-group $ResourceGroupName --plan $AppServicePlanName --storage-account $StorageAccountName --runtime powershell --runtime-version 7.4 --functions-version 4 --os-type Windows --app-insights $ApplicationInsightName

if ($LASTEXITCODE -eq 0) {
    Write-Host "Function App criada com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao criar Function App" -ForegroundColor Red
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
az role assignment create --role "Key Vault Secrets Officer" --assignee $UPNKeyVault --scope $(az keyvault show --name $KeyVaultName --query id -o tsv)

if ($LASTEXITCODE -eq 0) {
    Write-Host "Permissões concedidas com sucesso" -ForegroundColor Green
} else {
    Write-Host "Erro ao conceder permissões" -ForegroundColor Red
    exit 1
}

# 14. Armazenar segredos no Key Vault
Write-Host "n14. Armazenando segredos no Key Vault..." -ForegroundColor Cyan

# Armazenar credenciais SMB
# 
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


# 16. Verificar se o Azure Functions Core Tools está instalado
Write-Host "n16. Verificando Azure Functions Core Tools..." -ForegroundColor Cyan
try {
    $funcVersion = func --version
    Write-Host "Azure Functions Core Tools: $funcVersion" -ForegroundColor Green
} catch {
    Write-Host "Azure Functions Core Tools não encontrado!" -ForegroundColor Red
    Write-Host "Instale usando: npm install -g azure-functions-core-tools@4 --unsafe-perm true" -ForegroundColor Yellow
    exit 1
}

# 17. Verificar se está logado no Azure
Write-Host "n17. Verificando login no Azure..." -ForegroundColor Cyan
try {
    $account = az account show --query user.name --output tsv
    Write-Host "Logado como: $account" -ForegroundColor Green
} catch {
    Write-Host "Não logado no Azure. Execute 'az login' primeiro." -ForegroundColor Red
    exit 1
}
## Deploy da Function App
# 18. Verificar se os arquivos necessários existem
Write-Host "n18. Verificando arquivos do projeto..." -ForegroundColor Cyan
$requiredFiles = @(
    "host.json",
    "local.settings.json",
    "LogProcessorFunction/run.ps1"
)

foreach ($file in $requiredFiles) {
    $filePath = Join-Path $ProjectPath $file
    if (-not (Test-Path $filePath)) {
        Write-Host "Arquivo obrigatório não encontrado: $file" -ForegroundColor Red
        exit 1
    }
}
Write-Host "Todos os arquivos necessários encontrados" -ForegroundColor Green


# 19. Navegar para o diretório do projeto
Write-Host "n19. Navegando para o diretório do projeto e fazendo o deploy..." -ForegroundColor Cyan
$originalLocation = Get-Location
Set-Location $ProjectPath

    if (Test-Path $projectPath) {
        Set-Location $projectPath
        
        # Verificar se func está instalado
        try {
            $funcVersion = func --version 2>$null
            if ($funcVersion) {
                Write-ColorOutput "Azure Functions Core Tools encontrado: $funcVersion" "Green"
                
                # Fazer deploy usando func
                $deployResult = func azure functionapp publish $FunctionAppName --powershell 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-ColorOutput "Deploy do código concluído com sucesso!" "Green"
                } else {
                    Write-ColorOutput "Erro no deploy do código: $deployResult" "Red"
                    Write-ColorOutput "Você pode fazer o deploy manualmente usando: func azure functionapp publish $FunctionAppName --powershell" "Yellow"
                }
            } else {
                Write-ColorOutput "Azure Functions Core Tools não encontrado." "Yellow"
                Write-ColorOutput "Instale o Azure Functions Core Tools para fazer deploy do código automaticamente." "Yellow"
                Write-ColorOutput "Download: https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local" "Yellow"
                Write-ColorOutput "Comando manual: func azure functionapp publish $FunctionAppName --powershell" "Yellow"
            }
        }
        catch {
            Write-ColorOutput "Erro ao verificar Azure Functions Core Tools: $($_.Exception.Message)" "Yellow"
            Write-ColorOutput "Comando manual: func azure functionapp publish $FunctionAppName --powershell" "Yellow"
        }
        
        Set-Location $currentPath
    } else {
        Write-ColorOutput "Diretório do projeto não encontrado: $projectPath" "Yellow"
        Write-ColorOutput "Faça o deploy manualmente do diretório do projeto usando: func azure functionapp publish $FunctionAppName --powershell" "Yellow"
    }

# 20. Verificar status da Function App
    Write-ColorOutput "`n20. Verificando status da Function App" "Yellow"
    $funcApp = az functionapp show --name $FunctionAppName --resource-group $ResourceGroupName | ConvertFrom-Json
    
# 21. Configurando o CORS para a Function
Write-Host "n20. Realizando as configurações finais na Function..." -ForegroundColor Cyan
az functionapp cors add --name $FunctionAppName --resource-group $ResourceGroupName --allowed-origins "https://portal.azure.com"
az functionapp cors add --name $FunctionAppName --resource-group $ResourceGroupName --allowed-origins "https://functions.azure.com"
az functionapp restart --name $FunctionAppName --resource-group $ResourceGroupName

# Verificar e configurar Managed Identity
az functionapp identity assign --name $FunctionAppName --resource-group $ResourceGroupName
# Configurar permissões Key Vault
$identity = az functionapp identity show --name $FunctionAppName --resource-group $ResourceGroupName | ConvertFrom-Json
# Role: Key Vault Secrets User (para ler segredos)
az role assignment create --assignee $identity.principalId --role "Key Vault Secrets User" --scope $(az keyvault show --name $KeyVaultName --resource-group $ResourceGroupName --query id -o tsv)
# 401
az functionapp function keys set --name $FunctionAppName --resource-group $ResourceGroupName --function-name "LogProcessorFunction" --key-name default
# 403
az functionapp keys set --name $FunctionAppName --resource-group $ResourceGroupName --key-type masterKey --key-name masterKey
az functionapp function invoke --name $FunctionAppName --resource-group $ResourceGroupName --function-name "LogProcessorFunction"
# Acesso AKV via Run.ps1
az functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings "KEY_VAULT_NAME=$KeyVaultName"



Write-Host "=== Deploy Completo Finalizado! ===" -ForegroundColor Green
Write-Host "Recursos criados:" -ForegroundColor Yellow
Write-Host "- Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "- Storage Account: $StorageAccountName" -ForegroundColor White
Write-Host "- Key Vault: $KeyVaultName" -ForegroundColor White
Write-Host "- Function App: $FunctionAppName" -ForegroundColor White
Write-Host "- Application Insights: $ApplicationInsightName" -ForegroundColor White
Write-Host "- Status da Function App: $($funcApp.state)"  -ForegroundColor Green
Write-Host "- URL da Function App: https://$($funcApp.defaultHostName)"  -ForegroundColor Green


Write-Host "Próximos passos:" -ForegroundColor Yellow
Write-Host "2. Monitore a execução através do Application Insights" -ForegroundColor Yellow
Write-Host "3. Verifique os arquivos processados no Blob Storage" -ForegroundColor Yellow

