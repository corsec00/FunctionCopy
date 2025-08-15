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
$SmbPassword = "123Meu_"










# Executar a função manualmente via Azure CLI
az functionapp function invoke --name $FunctionAppName --resource-group $ResourceGroupName --function-name LogProcessorFunction

az functionapp function show --name $FunctionAppName --resource-group $ResourceGroupName --function-name LogProcessorFunction --query "invokeUrlTemplate" -o tsv

az functionapp function show --name $FunctionAppName --resource-group $ResourceGroupName --function-name LogProcessorFunction --query "config.bindings"



# Fazer download da versão atual
func azure functionapp fetch-app-settings $FunctionAppName
func azure functionapp download $FunctionAppName --output-path ./backup-timer-version

# Backup das configurações
az functionapp config appsettings list --name $FunctionAppName --resource-group $ResourceGroupName > backup-settings.json

pip install -r requirements.txt

# Iniciar função localmente
func start

# Em outro terminal, testar a função
curl -X GET "http://localhost:7071/api/LogProcessorFunction?dry_run=true"











# Criar ambiente virtual
python -m venv venv

# Ativar ambiente virtual
.\venv\Scripts\Activate.ps1

# Se der erro de execução de scripts, execute:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Depois ativar novamente:
.\venv\Scripts\Activate.ps1

# Instalar dependências uma por uma
pip install --upgrade pip
pip install azure-functions
pip install azure-keyvault-secrets
pip install azure-identity
pip install azure-storage-blob
pip install requests
pip install pysmb


pip install -r requirements-windows.txt
# Verificar se tudo foi instalado
pip list | Select-String "azure|pysmb"


# Iniciar função localmente
func start

# Em outro terminal, testar a função
curl -X GET "http://localhost:7071/api/LogProcessorFunction?dry_run=true"