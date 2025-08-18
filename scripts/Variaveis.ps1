Clear-Host
$SubscriptionId = "e788df9b-c8c6-43e5-8a01-037e2c5bba4d"
$ResourceGroupName = "RG-Log-Processor-04"
$Location = "Central US"
$StorageAccountName = "stalogprocessorlss004" # Lembrete: Storage account name must be between 3 and 24 characters in length and use numbers and lower-case letters only
$FunctionAppName = "func-log-processor-lss004"
$KeyVaultName = "akv-log-processor-lss004"
$AppServicePlanName = "$FunctionAppName-plan"
$ApplicationInsightName = "$FunctionAppName-insights"
$ContainerName = "processed-logs"
$SmbServer = "Server004"
$SmbShare = "logs"
$SmbUsername = "leo"
$SmbPassword = "123Meu_123Meu_"
$ProjectPath = "."
$UPNKeyVault = "corsec00_gmail.com#EXT#@corsec00gmail.onmicrosoft.com"

func azure functionapp publish $FunctionAppName --powershell