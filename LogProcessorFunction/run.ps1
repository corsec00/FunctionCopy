# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later
# than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

Write-Host "PowerShell timer trigger function executed at: $currentUTCtime"

# Função auxiliar para executar comandos Azure CLI com tratamento de erro
function Invoke-AzCliCommand {
    param(
        [string]$Command,
        [string]$Description = "Comando Azure CLI",
        [switch]$SuppressErrors,
        [switch]$ReturnJson
    )
    
    Write-Host "Executando: $Description"
    
    try {
        $result = Invoke-Expression "az $Command" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            if (-not $SuppressErrors) {
                Write-Error "Erro ao executar: $Description"
                Write-Error "Comando: az $Command"
                Write-Error "Resultado: $result"
            }
            return $null
        }
        
        if ($ReturnJson -and $result) {
            try {
                return $result | ConvertFrom-Json
            }
            catch {
                Write-Warning "Não foi possível converter resultado para JSON: $result"
                return $result
            }
        }
        
        return $result
    }
    catch {
        if (-not $SuppressErrors) {
            Write-Error "Exceção ao executar: $Description - $($_.Exception.Message)"
        }
        return $null
    }
}

# Função para obter secrets do Key Vault usando Azure CLI
function Get-KeyVaultSecretCli {
    param(
        [string]$VaultName,
        [string]$SecretName
    )
    
    if (-not $VaultName -or -not $SecretName) {
        Write-Error "VaultName e SecretName são obrigatórios"
        return $null
    }
    
    try {
        $secret = Invoke-AzCliCommand "keyvault secret show --vault-name $VaultName --name $SecretName --query value --output tsv" "Obtenção do secret $SecretName" -SuppressErrors
        
        if ($secret -and $secret -ne "") {
            return $secret.Trim()
        } else {
            Write-Warning "Secret $SecretName não encontrado ou vazio no Key Vault $VaultName"
            return $null
        }
    }
    catch {
        Write-Error "Erro ao obter secret $SecretName: $($_.Exception.Message)"
        return $null
    }
}

# Função para fazer upload de arquivo para blob storage usando Azure CLI
function Upload-BlobCli {
    param(
        [string]$FilePath,
        [string]$StorageAccount,
        [string]$ContainerName,
        [string]$BlobName,
        [string]$ConnectionString
    )
    
    try {
        # Definir connection string como variável de ambiente temporariamente
        $env:AZURE_STORAGE_CONNECTION_STRING = $ConnectionString
        
        $result = Invoke-AzCliCommand "storage blob upload --file `"$FilePath`" --container-name $ContainerName --name `"$BlobName`" --overwrite" "Upload do blob $BlobName"
        
        # Limpar variável de ambiente
        Remove-Item env:AZURE_STORAGE_CONNECTION_STRING -ErrorAction SilentlyContinue
        
        return $result -ne $null
    }
    catch {
        Write-Error "Erro ao fazer upload do blob: $($_.Exception.Message)"
        # Limpar variável de ambiente em caso de erro
        Remove-Item env:AZURE_STORAGE_CONNECTION_STRING -ErrorAction SilentlyContinue
        return $false
    }
}

try {
    # Validate required environment variables
    if (-not $global:KeyVaultName) {
        throw "KEY_VAULT_NAME environment variable is not set"
    }

    Write-Host "Starting log processing function..."
    
    # Get credentials from Azure Key Vault using Azure CLI
    Write-Host "Retrieving credentials from Key Vault: $global:KeyVaultName"
    
    $smbServer = Get-KeyVaultSecretCli -VaultName $global:KeyVaultName -SecretName "smb-server"
    $smbShare = Get-KeyVaultSecretCli -VaultName $global:KeyVaultName -SecretName "smb-share"
    $smbUsername = Get-KeyVaultSecretCli -VaultName $global:KeyVaultName -SecretName "smb-username"
    $smbPassword = Get-KeyVaultSecretCli -VaultName $global:KeyVaultName -SecretName "smb-password"
    $storageConnectionString = Get-KeyVaultSecretCli -VaultName $global:KeyVaultName -SecretName "storage-connection-string"
    
    if (-not $smbServer -or -not $smbShare -or -not $smbUsername -or -not $smbPassword -or -not $storageConnectionString) {
        throw "One or more required secrets not found in Key Vault"
    }

    # Create SMB path and credentials
    $smbPath = "\\$smbServer\$smbShare"
    $smbPasswordSecure = ConvertTo-SecureString $smbPassword -AsPlainText -Force
    $smbCredential = New-Object System.Management.Automation.PSCredential($smbUsername, $smbPasswordSecure)
    
    Write-Host "Connecting to SMB share: $smbPath"
    
    # Create temporary PSDrive for SMB access
    $driveName = "SMBDrive"
    try {
        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $smbPath -Credential $smbCredential -ErrorAction Stop | Out-Null
        Write-Host "Successfully connected to SMB share"
    }
    catch {
        throw "Failed to connect to SMB share: $($_.Exception.Message)"
    }

    # Get list of log files (.log and .txt)
    Write-Host "Listing log files in SMB share..."
    $logFiles = @()
    $logFiles += Get-ChildItem -Path "${driveName}:\" -Filter "*.log" -ErrorAction SilentlyContinue
    $logFiles += Get-ChildItem -Path "${driveName}:\" -Filter "*.txt" -ErrorAction SilentlyContinue
    
    if ($logFiles.Count -eq 0) {
        Write-Host "No log files found in SMB share"
        return
    }

    Write-Host "Found $($logFiles.Count) log files to process"

    # Extract storage account name from connection string for Azure CLI
    $storageAccountName = $null
    if ($storageConnectionString -match "AccountName=([^;]+)") {
        $storageAccountName = $matches[1]
    } else {
        throw "Could not extract storage account name from connection string"
    }
    
    # Process each log file
    $processedCount = 0
    foreach ($file in $logFiles) {
        Write-Host "Processing file: $($file.Name)"
        
        try {
            # Read file content
            $fileContent = Get-Content -Path $file.FullName -Encoding UTF8
            
            if (-not $fileContent -or $fileContent.Count -eq 0) {
                Write-Host "File $($file.Name) is empty, skipping..."
                continue
            }

            # Filter lines containing keywords
            $filteredLines = Filter-LogLines -Lines $fileContent
            
            if ($filteredLines.Count -eq 0) {
                Write-Host "No relevant lines found in $($file.Name)"
                # Remove original file even if no relevant content
                Remove-Item -Path $file.FullName -Force
                Write-Host "Original file $($file.Name) removed"
                continue
            }

            # Create temporary file with filtered content
            $tempFile = New-TemporaryFile
            $filteredLines | Out-File -FilePath $tempFile.FullName -Encoding UTF8
            
            # Create blob name with timestamp
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $blobName = "processed_${timestamp}_$($file.Name)"
            
            # Upload to blob storage using Azure CLI
            Write-Host "Uploading filtered content to blob storage as: $blobName"
            $uploadSuccess = Upload-BlobCli -FilePath $tempFile.FullName -StorageAccount $storageAccountName -ContainerName $global:BlobContainerName -BlobName $blobName -ConnectionString $storageConnectionString
            
            if (-not $uploadSuccess) {
                throw "Failed to upload blob $blobName"
            }
            
            # Clean up temporary file
            Remove-Item -Path $tempFile.FullName -Force
            
            # Remove original file after successful upload
            Remove-Item -Path $file.FullName -Force
            Write-Host "File $($file.Name) processed and uploaded successfully. Original file removed."
            
            $processedCount++
        }
        catch {
            Write-Error "Error processing file $($file.Name): $($_.Exception.Message)"
            continue
        }
    }
    
    Write-Host "Processing completed. $processedCount files processed successfully."
}
catch {
    Write-Error "Error during log processing: $($_.Exception.Message)"
    throw
}
finally {
    # Clean up PSDrive
    if (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue) {
        Remove-PSDrive -Name $driveName -Force
        Write-Host "SMB drive disconnected"
    }
    
    # Clean up any remaining environment variables
    Remove-Item env:AZURE_STORAGE_CONNECTION_STRING -ErrorAction SilentlyContinue
}

function Filter-LogLines {
    param(
        [string[]]$Lines
    )
    
    $keywords = @('login', 'logout', 'fail')
    $filteredLines = @()
    
    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        
        $lineLower = $line.ToLower()
        foreach ($keyword in $keywords) {
            if ($lineLower.Contains($keyword)) {
                $filteredLines += $line
                break
            }
        }
    }
    
    return $filteredLines
}

