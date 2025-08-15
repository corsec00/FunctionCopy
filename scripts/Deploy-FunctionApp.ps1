#Requires -Version 7.0

<#
.SYNOPSIS
    Script para deploy automatizado da Azure Function FunctionCopy usando Azure CLI

.DESCRIPTION
    Este script automatiza o processo de deploy da Azure Function usando Azure CLI, incluindo:
    - Criação de recursos Azure necessários
    - Configuração do Key Vault
    - Deploy da função
    - Configuração de variáveis de ambiente

.PARAMETER ResourceGroupName
    Nome do Resource Group onde os recursos serão criados

.PARAMETER FunctionAppName
    Nome da Function App

.PARAMETER StorageAccountName
    Nome da Storage Account

.PARAMETER KeyVaultName
    Nome do Key Vault

.PARAMETER Location
    Região Azure onde os recursos serão criados

.PARAMETER SmbServer
    Servidor SMB para conexão

.PARAMETER SmbShare
    Nome do compartilhamento SMB

.PARAMETER SmbUsername
    Usuário para conexão SMB

.PARAMETER SmbPassword
    Senha para conexão SMB

.EXAMPLE
    .\Deploy-FunctionApp.ps1 -ResourceGroupName "rg-functioncopy" -FunctionAppName "func-logprocessor" -StorageAccountName "stlogprocessor" -KeyVaultName "kv-logprocessor" -Location "eastus" -SmbServer "server.domain.com" -SmbShare "logs" -SmbUsername "loguser" -SmbPassword "password123"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$FunctionAppName,
    
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory = $true)]
    [string]$Location,
    
    [Parameter(Mandatory = $true)]
    [string]$SmbServer,
    
    [Parameter(Mandatory = $true)]
    [string]$SmbShare,
    
    [Parameter(Mandatory = $true)]
    [string]$SmbUsername,
    
    [Parameter(Mandatory = $true)]
    [SecureString]$SmbPassword
)

# Função para escrever logs coloridos
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Função para executar comando Azure CLI e verificar resultado
function Invoke-AzCommand {
    param(
        [string]$Command,
        [string]$Description
    )
    
    Write-ColorOutput "Executando: $Description" "Yellow"
    Write-ColorOutput "Comando: az $Command" "Gray"
    
    $result = Invoke-Expression "az $Command" 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Erro ao executar comando: $Description" "Red"
        Write-ColorOutput "Detalhes: $result" "Red"
        throw "Falha na execução do comando Azure CLI"
    }
    
    return $result
}

# Função para verificar se o usuário está logado no Azure CLI
function Test-AzureCliLogin {
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        if ($account) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# Início do script
Write-ColorOutput "=== Deploy da Azure Function FunctionCopy usando Azure CLI ===" "Cyan"
Write-ColorOutput "Iniciando processo de deploy..." "Green"

# Verificar se Azure CLI está instalado
try {
    $azVersion = az version 2>$null
    if (-not $azVersion) {
        throw "Azure CLI não encontrado"
    }
    Write-ColorOutput "Azure CLI encontrado e funcionando" "Green"
}
catch {
    Write-ColorOutput "Azure CLI não está instalado ou não está funcionando corretamente" "Red"
    Write-ColorOutput "Instale o Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" "Yellow"
    throw
}

# Verificar login no Azure CLI
if (-not (Test-AzureCliLogin)) {
    Write-ColorOutput "Você não está logado no Azure CLI. Fazendo login..." "Yellow"
    az login
    
    if (-not (Test-AzureCliLogin)) {
        throw "Falha no login do Azure CLI"
    }
}

$account = az account show | ConvertFrom-Json
Write-ColorOutput "Logado como: $($account.user.name)" "Green"
Write-ColorOutput "Subscription: $($account.name) ($($account.id))" "Green"

try {
    # 1. Criar Resource Group
    Write-ColorOutput "`n1. Criando Resource Group: $ResourceGroupName" "Yellow"
    $rgExists = az group exists --name $ResourceGroupName
    if ($rgExists -eq "false") {
        Invoke-AzCommand "group create --name $ResourceGroupName --location $Location" "Criação do Resource Group"
        Write-ColorOutput "Resource Group criado com sucesso!" "Green"
    } else {
        Write-ColorOutput "Resource Group já existe." "Green"
    }

    # 2. Criar Storage Account
    Write-ColorOutput "`n2. Criando Storage Account: $StorageAccountName" "Yellow"
    $storageExists = az storage account check-name --name $StorageAccountName | ConvertFrom-Json
    if ($storageExists.nameAvailable) {
        Invoke-AzCommand "storage account create --name $StorageAccountName --resource-group $ResourceGroupName --location $Location --sku Standard_LRS --kind StorageV2" "Criação da Storage Account"
        Write-ColorOutput "Storage Account criada com sucesso!" "Green"
    } else {
        Write-ColorOutput "Storage Account já existe ou nome não disponível." "Green"
    }

    # 3. Criar container de blob
    Write-ColorOutput "`n3. Criando container 'processed-logs'" "Yellow"
    $containerExists = az storage container exists --name "processed-logs" --account-name $StorageAccountName --auth-mode login | ConvertFrom-Json
    if (-not $containerExists.exists) {
        Invoke-AzCommand "storage container create --name processed-logs --account-name $StorageAccountName --auth-mode login" "Criação do container de blob"
        Write-ColorOutput "Container criado com sucesso!" "Green"
    } else {
        Write-ColorOutput "Container já existe." "Green"
    }

    # 4. Criar Key Vault
    Write-ColorOutput "`n4. Criando Key Vault: $KeyVaultName" "Yellow"
    $kvExists = az keyvault list --resource-group $ResourceGroupName --query "[?name=='$KeyVaultName']" | ConvertFrom-Json
    if ($kvExists.Count -eq 0) {
        Invoke-AzCommand "keyvault create --name $KeyVaultName --resource-group $ResourceGroupName --location $Location --enabled-for-deployment --enabled-for-template-deployment --enabled-for-disk-encryption" "Criação do Key Vault"
        Write-ColorOutput "Key Vault criado com sucesso!" "Green"
    } else {
        Write-ColorOutput "Key Vault já existe." "Green"
    }

    # 5. Criar Function App
    Write-ColorOutput "`n5. Criando Function App: $FunctionAppName" "Yellow"
    $funcExists = az functionapp list --resource-group $ResourceGroupName --query "[?name=='$FunctionAppName']" | ConvertFrom-Json
    if ($funcExists.Count -eq 0) {
        Invoke-AzCommand "az functionapp create --name $FunctionAppName --resource-group $ResourceGroupName --plan $AppServicePlanName --storage-account $StorageAccountName --runtime powershell --runtime-version 7.4 --functions-version 4 --os-type Windows --app-insights $ApplicationInsightName" "Criação da Function App"
        Write-ColorOutput "Function App criada com sucesso!" "Green"
    } else {
        Write-ColorOutput "Function App já existe." "Green"
    }

    # 6. Habilitar Managed Identity
    Write-ColorOutput "`n6. Habilitando Managed Identity" "Yellow"
    $identity = az functionapp identity assign --name $FunctionAppName --resource-group $ResourceGroupName | ConvertFrom-Json
    $principalId = $identity.principalId
    Write-ColorOutput "Managed Identity habilitada. Principal ID: $principalId" "Green"

    # 7. Conceder acesso ao Key Vault
    Write-ColorOutput "`n7. Configurando acesso ao Key Vault" "Yellow"
    Invoke-AzCommand "keyvault set-policy --name $KeyVaultName --object-id $principalId --secret-permissions get list" "Configuração de acesso ao Key Vault"
    Write-ColorOutput "Acesso ao Key Vault configurado!" "Green"

    # 8. Armazenar secrets no Key Vault
    Write-ColorOutput "`n8. Armazenando credenciais no Key Vault" "Yellow"
    
    Invoke-AzCommand "keyvault secret set --vault-name $KeyVaultName --name smb-server --value `"$SmbServer`"" "Armazenamento do secret smb-server"
    Invoke-AzCommand "keyvault secret set --vault-name $KeyVaultName --name smb-share --value `"$SmbShare`"" "Armazenamento do secret smb-share"
    Invoke-AzCommand "keyvault secret set --vault-name $KeyVaultName --name smb-username --value `"$SmbUsername`"" "Armazenamento do secret smb-username"
    Invoke-AzCommand "keyvault secret set --vault-name $KeyVaultName --name smb-password --value `"$SmbPassword`"" "Armazenamento do secret smb-password"
    
    # Obter connection string da storage account
    $connectionString = az storage account show-connection-string --name $StorageAccountName --resource-group $ResourceGroupName --query connectionString --output tsv
    Invoke-AzCommand "keyvault secret set --vault-name $KeyVaultName --name storage-connection-string --value `"$connectionString`"" "Armazenamento do secret storage-connection-string"
    
    Write-ColorOutput "Credenciais armazenadas com sucesso!" "Green"

    # 9. Configurar variáveis de ambiente da Function App
    Write-ColorOutput "`n9. Configurando variáveis de ambiente" "Yellow"
    
    Invoke-AzCommand "functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings KEY_VAULT_NAME=$KeyVaultName" "Configuração da variável KEY_VAULT_NAME"
    Invoke-AzCommand "functionapp config appsettings set --name $FunctionAppName --resource-group $ResourceGroupName --settings BLOB_CONTAINER_NAME=processed-logs" "Configuração da variável BLOB_CONTAINER_NAME"
    
    Write-ColorOutput "Variáveis de ambiente configuradas!" "Green"

    # 10. Deploy do código (usando Azure Functions Core Tools)
    Write-ColorOutput "`n10. Fazendo deploy do código da função" "Yellow"
    $currentPath = Get-Location
    $projectPath = Split-Path $PSScriptRoot -Parent
    
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

    # 11. Verificar status da Function App
    Write-ColorOutput "`n11. Verificando status da Function App" "Yellow"
    $funcApp = az functionapp show --name $FunctionAppName --resource-group $ResourceGroupName | ConvertFrom-Json
    Write-ColorOutput "Status da Function App: $($funcApp.state)" "Green"
    Write-ColorOutput "URL da Function App: https://$($funcApp.defaultHostName)" "Green"

    # Resumo final
    Write-ColorOutput "`n=== DEPLOY CONCLUÍDO COM SUCESSO ===" "Cyan"
    Write-ColorOutput "Resource Group: $ResourceGroupName" "White"
    Write-ColorOutput "Function App: $FunctionAppName" "White"
    Write-ColorOutput "Storage Account: $StorageAccountName" "White"
    Write-ColorOutput "Key Vault: $KeyVaultName" "White"
    Write-ColorOutput "Location: $Location" "White"
    Write-ColorOutput "URL: https://$($funcApp.defaultHostName)" "White"
    Write-ColorOutput "`nA função está configurada para executar a cada 15 minutos." "Green"
    Write-ColorOutput "Monitore os logs no Application Insights do Azure Portal." "Green"
    Write-ColorOutput "`nComandos úteis para monitoramento:" "Yellow"
    Write-ColorOutput "- Ver logs: az functionapp log tail --name $FunctionAppName --resource-group $ResourceGroupName" "Gray"
    Write-ColorOutput "- Ver configurações: az functionapp config appsettings list --name $FunctionAppName --resource-group $ResourceGroupName" "Gray"
    Write-ColorOutput "- Restart: az functionapp restart --name $FunctionAppName --resource-group $ResourceGroupName" "Gray"

} catch {
    Write-ColorOutput "Erro durante o deploy: $($_.Exception.Message)" "Red"
    Write-ColorOutput "`nPara troubleshooting, verifique:" "Yellow"
    Write-ColorOutput "1. Se você tem permissões adequadas na subscription" "Gray"
    Write-ColorOutput "2. Se os nomes dos recursos são únicos globalmente" "Gray"
    Write-ColorOutput "3. Se a região especificada suporta todos os serviços" "Gray"
    Write-ColorOutput "4. Se há cotas disponíveis na subscription" "Gray"
    throw
}

