# Azure Functions profile.ps1 - Versão Azure CLI
#
# Este profile.ps1 será executado a cada "cold start" da Function App.
# "cold start" ocorre quando:
#
# * Uma Function App inicia pela primeira vez
# * Uma Function App inicia após ser desalocada devido à inatividade
#
# Você pode definir métodos auxiliares, executar comandos ou especificar variáveis de ambiente
# NOTA: qualquer variável definida que não seja variável de ambiente será resetada após a primeira execução

# Função para escrever logs com timestamp
function Write-ProfileLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

Write-ProfileLog "Iniciando profile.ps1 - Versão Azure CLI"

try {
    # Verificar se Azure CLI está disponível no ambiente
    Write-ProfileLog "Verificando disponibilidade do Azure CLI..."
    
    $azVersion = $null
    try {
        $azVersion = az version 2>$null | ConvertFrom-Json
        if ($azVersion) {
            Write-ProfileLog "Azure CLI encontrado - Versão: $($azVersion.'azure-cli')"
        } else {
            throw "Azure CLI não retornou versão válida"
        }
    }
    catch {
        Write-ProfileLog "Azure CLI não está disponível ou não está funcionando corretamente" "ERROR"
        Write-ProfileLog "Erro: $($_.Exception.Message)" "ERROR"
        # Não falhar completamente, pois pode estar em ambiente onde Azure CLI não é necessário
    }

    # Autenticar com Azure usando Managed Service Identity (MSI)
    # Remove autenticação automática se não estiver planejando usar MSI ou Azure CLI
    if ($env:MSI_SECRET -and $azVersion) {
        Write-ProfileLog "Detectado ambiente MSI. Configurando autenticação..."
        
        try {
            # Fazer login usando Managed Identity
            $loginResult = az login --identity 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-ProfileLog "Autenticação MSI bem-sucedida"
                
                # Obter informações da conta atual
                $account = az account show 2>$null | ConvertFrom-Json
                if ($account) {
                    Write-ProfileLog "Logado como: $($account.user.name)"
                    Write-ProfileLog "Subscription: $($account.name) ($($account.id))"
                    
                    # Definir variáveis globais com informações da conta
                    $global:AzureSubscriptionId = $account.id
                    $global:AzureSubscriptionName = $account.name
                    $global:AzureTenantId = $account.tenantId
                } else {
                    Write-ProfileLog "Não foi possível obter informações da conta" "WARNING"
                }
            } else {
                Write-ProfileLog "Falha na autenticação MSI: $loginResult" "ERROR"
            }
        }
        catch {
            Write-ProfileLog "Erro durante autenticação MSI: $($_.Exception.Message)" "ERROR"
        }
    } else {
        if (-not $env:MSI_SECRET) {
            Write-ProfileLog "Ambiente MSI não detectado (MSI_SECRET não definido)"
        }
        if (-not $azVersion) {
            Write-ProfileLog "Azure CLI não disponível para autenticação"
        }
    }

    # Configurar variáveis globais para a aplicação
    Write-ProfileLog "Configurando variáveis globais..."
    
    # Variáveis de ambiente obrigatórias
    $global:KeyVaultName = $env:KEY_VAULT_NAME
    $global:BlobContainerName = $env:BLOB_CONTAINER_NAME
    
    # Variáveis opcionais com valores padrão
    $global:BlobContainerName = if ($global:BlobContainerName) { $global:BlobContainerName } else { "processed-logs" }
    
    # Validar variáveis críticas
    if (-not $global:KeyVaultName) {
        Write-ProfileLog "AVISO: KEY_VAULT_NAME não está definido. Algumas funcionalidades podem não funcionar." "WARNING"
    } else {
        Write-ProfileLog "Key Vault configurado: $global:KeyVaultName"
    }
    
    Write-ProfileLog "Container de blob configurado: $global:BlobContainerName"

    # Função auxiliar para executar comandos Azure CLI com tratamento de erro
    function global:Invoke-AzCliCommand {
        param(
            [string]$Command,
            [string]$Description = "Comando Azure CLI",
            [switch]$SuppressErrors
        )
        
        Write-ProfileLog "Executando: $Description"
        
        try {
            $result = Invoke-Expression "az $Command" 2>&1
            
            if ($LASTEXITCODE -ne 0 -and -not $SuppressErrors) {
                Write-ProfileLog "Erro ao executar: $Description" "ERROR"
                Write-ProfileLog "Comando: az $Command" "ERROR"
                Write-ProfileLog "Resultado: $result" "ERROR"
                return $null
            }
            
            return $result
        }
        catch {
            if (-not $SuppressErrors) {
                Write-ProfileLog "Exceção ao executar: $Description - $($_.Exception.Message)" "ERROR"
            }
            return $null
        }
    }

    # Função auxiliar para obter secrets do Key Vault usando Azure CLI
    function global:Get-KeyVaultSecretCli {
        param(
            [string]$VaultName,
            [string]$SecretName
        )
        
        if (-not $VaultName -or -not $SecretName) {
            Write-ProfileLog "VaultName e SecretName são obrigatórios" "ERROR"
            return $null
        }
        
        try {
            $secret = Invoke-AzCliCommand "keyvault secret show --vault-name $VaultName --name $SecretName --query value --output tsv" "Obtenção do secret $SecretName" -SuppressErrors
            
            if ($secret -and $secret -ne "") {
                return $secret.Trim()
            } else {
                Write-ProfileLog "Secret $SecretName não encontrado ou vazio no Key Vault $VaultName" "WARNING"
                return $null
            }
        }
        catch {
            Write-ProfileLog "Erro ao obter secret $SecretName: $($_.Exception.Message)" "ERROR"
            return $null
        }
    }

    # Função auxiliar para verificar conectividade com recursos Azure
    function global:Test-AzureConnectivity {
        Write-ProfileLog "Testando conectividade com recursos Azure..."
        
        $results = @{
            KeyVault = $false
            Storage = $false
            Subscription = $false
        }
        
        # Testar acesso à subscription
        try {
            $account = az account show 2>$null | ConvertFrom-Json
            if ($account) {
                $results.Subscription = $true
                Write-ProfileLog "✓ Conectividade com subscription OK"
            }
        }
        catch {
            Write-ProfileLog "✗ Falha na conectividade com subscription" "WARNING"
        }
        
        # Testar acesso ao Key Vault
        if ($global:KeyVaultName) {
            try {
                $kvTest = az keyvault show --name $global:KeyVaultName 2>$null | ConvertFrom-Json
                if ($kvTest) {
                    $results.KeyVault = $true
                    Write-ProfileLog "✓ Conectividade com Key Vault OK"
                }
            }
            catch {
                Write-ProfileLog "✗ Falha na conectividade com Key Vault" "WARNING"
            }
        }
        
        return $results
    }

    # Função auxiliar para configurar logging estruturado
    function global:Write-StructuredLog {
        param(
            [string]$Message,
            [string]$Level = "Information",
            [hashtable]$Properties = @{}
        )
        
        $logEntry = @{
            timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ")
            level = $Level
            message = $Message
            source = "FunctionCopy-PowerShell"
        }
        
        # Adicionar propriedades customizadas
        foreach ($key in $Properties.Keys) {
            $logEntry[$key] = $Properties[$key]
        }
        
        # Adicionar informações de contexto se disponíveis
        if ($global:AzureSubscriptionId) {
            $logEntry.subscriptionId = $global:AzureSubscriptionId
        }
        
        if ($global:KeyVaultName) {
            $logEntry.keyVaultName = $global:KeyVaultName
        }
        
        # Converter para JSON e escrever
        $jsonLog = $logEntry | ConvertTo-Json -Compress
        Write-Host $jsonLog
    }

    # Testar conectividade inicial (opcional)
    if ($azVersion -and $env:MSI_SECRET) {
        $connectivity = Test-AzureConnectivity
        Write-ProfileLog "Teste de conectividade concluído"
    }

    Write-ProfileLog "Profile.ps1 executado com sucesso"
    Write-ProfileLog "Variáveis globais configuradas:"
    Write-ProfileLog "  - KeyVaultName: $global:KeyVaultName"
    Write-ProfileLog "  - BlobContainerName: $global:BlobContainerName"
    
    if ($global:AzureSubscriptionId) {
        Write-ProfileLog "  - SubscriptionId: $global:AzureSubscriptionId"
    }

} catch {
    Write-ProfileLog "Erro durante execução do profile.ps1: $($_.Exception.Message)" "ERROR"
    Write-ProfileLog "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    
    # Não falhar completamente para não impedir a inicialização da função
    Write-ProfileLog "Continuando inicialização apesar do erro..." "WARNING"
}

# Definir aliases úteis para comandos Azure CLI (opcional)
if (Get-Command az -ErrorAction SilentlyContinue) {
    Set-Alias -Name azlogin -Value "az login"
    Set-Alias -Name azaccount -Value "az account show"
    Set-Alias -Name azkv -Value "az keyvault"
    Set-Alias -Name azstorage -Value "az storage"
    Set-Alias -Name azfunc -Value "az functionapp"
    
    Write-ProfileLog "Aliases Azure CLI configurados: azlogin, azaccount, azkv, azstorage, azfunc"
}

Write-ProfileLog "Profile.ps1 concluído - Ambiente pronto para execução"

