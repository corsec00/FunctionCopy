param($Timer)

try {
    # Autenticar usando Managed Identity
    Connect-AzAccount -Identity | Out-Null
    
    # Nome do Key Vault - configure como Application Setting na Function App
    $keyVaultName = $env:KEY_VAULT_NAME
    
    if (-not $keyVaultName) {
        throw "KEY_VAULT_NAME environment variable is not set"
    }

    # Lista de secrets necessários
    $requiredSecrets = @("SmbServer", "SmbShare", "SmbUsername", "SmbPassword", "StorageAccountName", "ContainerName")
    $secrets = @{}
    $missingSecrets = @()

    # Validar e obter todos os secrets
    foreach ($secretName in $requiredSecrets) {
        try {
            $secretValue = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName -AsPlainText -ErrorAction Stop
            
            if ([string]::IsNullOrWhiteSpace($secretValue)) {
                $missingSecrets += "$secretName (empty)"
            } else {
                $secrets[$secretName] = $secretValue
            }
        }
        catch {
            $missingSecrets += "$secretName (not found)"
        }
    }

    # Verificar se algum secret está faltando
    if ($missingSecrets.Count -gt 0) {
        $missingList = $missingSecrets -join ", "
        throw "Missing or empty secrets in Key Vault '$keyVaultName': $missingList"
    }

    # Conectar ao compartilhamento SMB
    $smbPath = "\\" + $secrets["SmbServer"] + "\" + $secrets["SmbShare"]
    $securePassword = ConvertTo-SecureString $secrets["SmbPassword"] -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($secrets["SmbUsername"], $securePassword)
    
    New-PSDrive -Name "SMB" -PSProvider FileSystem -Root $smbPath -Credential $credential | Out-Null

    # Obter arquivos .txt e .log
    $files = Get-ChildItem -Path "SMB:\" -Include "*.txt", "*.log" -File

    # Obter contexto da storage account
    $storageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $secrets["StorageAccountName"] }
    
    if (-not $storageAccount) {
        throw "Storage Account '$($secrets["StorageAccountName"])' not found or not accessible"
    }
    
    $storageContext = $storageAccount.Context

    foreach ($file in $files) {
        # Ler conteúdo do arquivo
        $content = Get-Content -Path $file.FullName
        
        # Filtrar linhas que contenham login, logout ou fail (case insensitive)
        $filteredLines = $content | Where-Object { 
            $_.ToLower() -match "login" -or $_.ToLower() -match "logout" -or $_.ToLower() -match "fail" 
        }
        
        if ($filteredLines -and $filteredLines.Count -gt 0) {
            # Criar arquivo temporário com linhas filtradas
            $tempFile = New-TemporaryFile
            $filteredLines | Out-File -FilePath $tempFile.FullName -Encoding UTF8
            
            # Nome do blob com timestamp
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $blobName = "filtered_" + $timestamp + "_" + $file.Name
            
            # Upload para storage account usando módulos Az
            Set-AzStorageBlobContent -File $tempFile.FullName -Container $secrets["ContainerName"] -Blob $blobName -Context $storageContext | Out-Null
            
            # Limpar arquivo temporário
            Remove-Item $tempFile.FullName -Force
        }
    }
    
    # Desconectar drive SMB
    Remove-PSDrive -Name "SMB" -Force
}
catch {
    if (Get-PSDrive -Name "SMB" -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name "SMB" -Force
    }
    throw
}

