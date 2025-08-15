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

try {
    # Validate required environment variables
    if (-not $global:KeyVaultName) {
        throw "KEY_VAULT_NAME environment variable is not set"
    }

    Write-Host "Starting log processing function..."
    
    # Get credentials from Azure Key Vault
    Write-Host "Retrieving credentials from Key Vault: $global:KeyVaultName"
    
    $smbServer = Get-AzKeyVaultSecret -VaultName $global:KeyVaultName -Name "smb-server" -AsPlainText
    $smbShare = Get-AzKeyVaultSecret -VaultName $global:KeyVaultName -Name "smb-share" -AsPlainText
    $smbUsername = Get-AzKeyVaultSecret -VaultName $global:KeyVaultName -Name "smb-username" -AsPlainText
    $smbPasswordSecure = Get-AzKeyVaultSecret -VaultName $global:KeyVaultName -Name "smb-password"
    $storageConnectionString = Get-AzKeyVaultSecret -VaultName $global:KeyVaultName -Name "storage-connection-string" -AsPlainText
    
    if (-not $smbServer -or -not $smbShare -or -not $smbUsername -or -not $smbPasswordSecure -or -not $storageConnectionString) {
        throw "One or more required secrets not found in Key Vault"
    }

    # Create SMB path and credentials
    $smbPath = "\\$smbServer\$smbShare"
    $smbCredential = New-Object System.Management.Automation.PSCredential($smbUsername, $smbPasswordSecure.SecretValue)
    
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

    # Initialize storage context
    $storageContext = New-AzStorageContext -ConnectionString $storageConnectionString
    
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
            
            # Upload to blob storage
            Write-Host "Uploading filtered content to blob storage as: $blobName"
            Set-AzStorageBlobContent -File $tempFile.FullName -Container $global:BlobContainerName -Blob $blobName -Context $storageContext -Force | Out-Null
            
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

