# Guia de Deployment - FunctionCopy Modernizado

**Autor**: Manus AI  
**Data**: 12 de Agosto de 2025  
**Versão**: 2.0.0  

## Introdução

Este guia fornece instruções detalhadas para o deployment da solução FunctionCopy modernizada em ambientes Azure. O documento cobre desde a preparação inicial até a validação pós-deployment, incluindo configurações de segurança avançadas e integração com pipelines de CI/CD.

## Pré-requisitos

### Ferramentas Obrigatórias

Antes de iniciar o deployment, certifique-se de que as seguintes ferramentas estejam instaladas e configuradas:

**Azure CLI (versão 2.40.0 ou superior)**
```bash
# Instalação no Ubuntu/Debian
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Instalação no Windows
# Baixar e executar o MSI do site oficial da Microsoft

# Verificar instalação
az --version
```

**Azure Functions Core Tools (versão 4.0 ou superior)**
```bash
# Instalação via npm
npm install -g azure-functions-core-tools@4 --unsafe-perm true

# Verificar instalação
func --version
```

**PowerShell (versão 7.0 ou superior)**
```bash
# Instalação no Ubuntu
sudo snap install powershell --classic

# Verificar instalação
pwsh --version
```

**Python (versão 3.9 ou superior)**
```bash
# Verificar versão instalada
python3 --version

# Instalar pip se necessário
sudo apt update
sudo apt install python3-pip
```

### Permissões Azure

O usuário ou service principal utilizado para deployment deve possuir as seguintes permissões:

- **Contributor** na subscription Azure
- **User Access Administrator** para configurar RBAC
- Permissões para criar e gerenciar:
  - Resource Groups
  - Azure Functions
  - Key Vault
  - Storage Accounts
  - Virtual Networks
  - Private Endpoints
  - Application Insights

### Configuração Inicial

**Login no Azure**
```bash
# Login interativo
az login

# Login com service principal (para automação)
az login --service-principal -u <app-id> -p <password> --tenant <tenant-id>

# Configurar subscription padrão
az account set --subscription "sua-subscription-id"

# Verificar configuração
az account show
```

## Deployment Manual

### Passo 1: Preparação do Ambiente

**Clone do Repositório**
```bash
git clone https://github.com/corsec00/FunctionCopy.git
cd FunctionCopy
```

**Configuração de Variáveis**
```powershell
# Definir variáveis de ambiente
$ResourceGroupName = "rg-log-processor-prod"
$Location = "East US"
$StorageAccountName = "stlogprocessor$(Get-Random -Minimum 1000 -Maximum 9999)"
$FunctionAppName = "func-log-processor-$(Get-Random -Minimum 1000 -Maximum 9999)"
$KeyVaultName = "kv-log-processor-$(Get-Random -Minimum 1000 -Maximum 9999)"

# Credenciais SMB (substituir pelos valores reais)
$SmbServer = "servidor-01"
$SmbShare = "Shared02"
$SmbUsername = "usuario_smb"
$SmbPassword = "senha_segura"
```

### Passo 2: Execução do Script de Infraestrutura

**Deploy Automático (Recomendado)**
```powershell
./scripts/deploy-complete.ps1 `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -StorageAccountName $StorageAccountName `
    -FunctionAppName $FunctionAppName `
    -KeyVaultName $KeyVaultName `
    -SmbServer $SmbServer `
    -SmbShare $SmbShare `
    -SmbUsername $SmbUsername `
    -SmbPassword $SmbPassword
```

**Deploy Manual (Passo a Passo)**
```powershell
# 1. Criar infraestrutura base
./scripts/01-create-infrastructure.ps1 `
    -SubscriptionId (az account show --query id -o tsv) `
    -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -StorageAccountName $StorageAccountName `
    -FunctionAppName $FunctionAppName `
    -KeyVaultName $KeyVaultName `
    -SmbServer $SmbServer `
    -SmbShare $SmbShare `
    -SmbUsername $SmbUsername `
    -SmbPassword $SmbPassword

# 2. Deploy da função
./scripts/02-deploy-function.ps1 `
    -FunctionAppName $FunctionAppName `
    -ResourceGroupName $ResourceGroupName

# 3. Configurar segurança avançada
./security/configure-security.ps1 `
    -ResourceGroupName $ResourceGroupName `
    -FunctionAppName $FunctionAppName `
    -KeyVaultName $KeyVaultName `
    -StorageAccountName $StorageAccountName
```

### Passo 3: Validação do Deployment

**Verificar Recursos Criados**
```bash
# Listar todos os recursos no Resource Group
az resource list --resource-group $ResourceGroupName --output table

# Verificar status da Function App
az functionapp show --name $FunctionAppName --resource-group $ResourceGroupName --query "state"

# Testar acesso ao Key Vault
az keyvault secret list --vault-name $KeyVaultName --output table
```

**Testar Conectividade**
```bash
# Verificar logs da Function App
az functionapp logs tail --name $FunctionAppName --resource-group $ResourceGroupName

# Verificar métricas no Application Insights
az monitor app-insights component show --app $FunctionAppName-insights --resource-group $ResourceGroupName
```

## Configuração de CI/CD

### GitHub Actions

**Configuração de Secrets**

Navegue até Settings > Secrets and variables > Actions no seu repositório GitHub e adicione os seguintes secrets:

```
AZURE_CREDENTIALS_DEV: {
  "clientId": "service-principal-client-id",
  "clientSecret": "service-principal-secret",
  "subscriptionId": "subscription-id",
  "tenantId": "tenant-id"
}

AZURE_CREDENTIALS_PROD: {
  "clientId": "service-principal-client-id",
  "clientSecret": "service-principal-secret", 
  "subscriptionId": "subscription-id",
  "tenantId": "tenant-id"
}

AZURE_FUNCTIONAPP_NAME_DEV: "func-log-processor-dev-xxxx"
AZURE_FUNCTIONAPP_NAME_PROD: "func-log-processor-prod-xxxx"
AZURE_FUNCTIONAPP_PUBLISH_PROFILE_DEV: "<publish-profile-xml>"
AZURE_FUNCTIONAPP_PUBLISH_PROFILE_PROD: "<publish-profile-xml>"
MS_TEAMS_WEBHOOK_URI: "https://outlook.office.com/webhook/..."
```

**Obter Publish Profile**
```bash
# Para ambiente de desenvolvimento
az functionapp deployment list-publishing-profiles --name $FunctionAppNameDev --resource-group $ResourceGroupNameDev --xml

# Para ambiente de produção  
az functionapp deployment list-publishing-profiles --name $FunctionAppNameProd --resource-group $ResourceGroupNameProd --xml
```

**Configuração de Environments**

1. Navegue até Settings > Environments no GitHub
2. Crie environments "development" e "production"
3. Configure protection rules para produção:
   - Required reviewers
   - Wait timer (opcional)
   - Deployment branches (apenas main)

### Azure DevOps

**Criação de Service Connections**

1. Acesse Project Settings > Service connections
2. Crie uma nova service connection do tipo "Azure Resource Manager"
3. Configure authentication method como "Service principal (automatic)"
4. Nomeie as connections como:
   - `azure-dev-connection` (para desenvolvimento)
   - `azure-prod-connection` (para produção)

**Configuração de Variable Groups**

1. Navegue até Pipelines > Library
2. Crie variable groups:

**Variable Group: "FunctionCopy-Dev"**
```
AZURE_FUNCTIONAPP_NAME_DEV: func-log-processor-dev-xxxx
AZURE_RESOURCE_GROUP_DEV: rg-log-processor-dev
ARM_SUBSCRIPTION_ID: subscription-id
ARM_TENANT_ID: tenant-id
```

**Variable Group: "FunctionCopy-Prod"**
```
AZURE_FUNCTIONAPP_NAME_PROD: func-log-processor-prod-xxxx
AZURE_RESOURCE_GROUP_PROD: rg-log-processor-prod
ARM_SUBSCRIPTION_ID: subscription-id
ARM_TENANT_ID: tenant-id
```

**Criação do Pipeline**

1. Navegue até Pipelines > Pipelines
2. Clique em "New pipeline"
3. Selecione "Azure Repos Git" ou "GitHub"
4. Escolha o repositório
5. Selecione "Existing Azure Pipelines YAML file"
6. Aponte para `.azuredevops/azure-pipelines.yml`

## Configurações de Segurança Avançadas

### Network Security

**Configuração de Private Endpoints**
```bash
# Criar Private Endpoint para Key Vault
az network private-endpoint create \
    --name kv-private-endpoint \
    --resource-group $ResourceGroupName \
    --vnet-name $VNetName \
    --subnet $SubnetName \
    --private-connection-resource-id "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName" \
    --group-id vault \
    --connection-name kv-connection

# Criar Private Endpoint para Storage Account
az network private-endpoint create \
    --name storage-private-endpoint \
    --resource-group $ResourceGroupName \
    --vnet-name $VNetName \
    --subnet $SubnetName \
    --private-connection-resource-id "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Storage/storageAccounts/$StorageAccountName" \
    --group-id blob \
    --connection-name storage-connection
```

**Configuração de Network Security Groups**
```bash
# Criar NSG
az network nsg create \
    --name function-nsg \
    --resource-group $ResourceGroupName \
    --location $Location

# Regra para permitir HTTPS
az network nsg rule create \
    --name AllowHTTPS \
    --nsg-name function-nsg \
    --resource-group $ResourceGroupName \
    --priority 1000 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --destination-port-ranges 443

# Regra para negar HTTP
az network nsg rule create \
    --name DenyHTTP \
    --nsg-name function-nsg \
    --resource-group $ResourceGroupName \
    --priority 1001 \
    --direction Inbound \
    --access Deny \
    --protocol Tcp \
    --destination-port-ranges 80
```

### Monitoring e Alertas

**Configuração de Diagnostic Settings**
```bash
# Para Function App
az monitor diagnostic-settings create \
    --name FunctionAppDiagnostics \
    --resource "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$FunctionAppName" \
    --logs '[{"category":"FunctionAppLogs","enabled":true,"retentionPolicy":{"enabled":true,"days":90}}]' \
    --metrics '[{"category":"AllMetrics","enabled":true,"retentionPolicy":{"enabled":true,"days":90}}]' \
    --storage-account $StorageAccountName

# Para Key Vault
az monitor diagnostic-settings create \
    --name KeyVaultDiagnostics \
    --resource "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName" \
    --logs '[{"category":"AuditEvent","enabled":true,"retentionPolicy":{"enabled":true,"days":90}}]' \
    --storage-account $StorageAccountName
```

**Configuração de Alertas**
```bash
# Criar Action Group
az monitor action-group create \
    --name SecurityAlerts \
    --resource-group $ResourceGroupName \
    --short-name SecAlert

# Alerta para falhas de autenticação
az monitor metrics alert create \
    --name "KeyVault-AuthFailures" \
    --resource-group $ResourceGroupName \
    --scopes "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName" \
    --condition "count 'ServiceApiResult' > 5" \
    --description "Múltiplas falhas de autenticação no Key Vault" \
    --evaluation-frequency 5m \
    --window-size 15m \
    --severity 2 \
    --action SecurityAlerts
```

## Troubleshooting

### Problemas Comuns

**Erro: "DefaultAzureCredential failed to retrieve a token"**

*Causa*: Managed Identity não configurada ou sem permissões no Key Vault

*Solução*:
```bash
# Verificar se Managed Identity está habilitada
az functionapp identity show --name $FunctionAppName --resource-group $ResourceGroupName

# Habilitar se necessário
az functionapp identity assign --name $FunctionAppName --resource-group $ResourceGroupName

# Verificar permissões no Key Vault
az keyvault show --name $KeyVaultName --resource-group $ResourceGroupName --query "properties.accessPolicies"

# Conceder permissões se necessário
az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee $(az functionapp identity show --name $FunctionAppName --resource-group $ResourceGroupName --query principalId -o tsv) \
    --scope "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName"
```

**Erro: "SMBException - Connection failed"**

*Causa*: Credenciais incorretas ou problemas de conectividade de rede

*Solução*:
```bash
# Verificar credenciais no Key Vault
az keyvault secret show --vault-name $KeyVaultName --name smb-server
az keyvault secret show --vault-name $KeyVaultName --name smb-username

# Testar conectividade de rede
# (executar a partir da Function App ou VM na mesma VNet)
telnet $SmbServer 445
```

**Erro: "Deployment failed in CI/CD"**

*Causa*: Secrets/variables não configurados ou permissões insuficientes

*Solução*:
```bash
# Verificar service principal permissions
az role assignment list --assignee $ServicePrincipalId --output table

# Verificar se todos os secrets estão configurados
# GitHub: Settings > Secrets and variables > Actions
# Azure DevOps: Pipelines > Library > Variable groups
```

### Logs e Diagnóstico

**Visualizar Logs da Function App**
```bash
# Logs em tempo real
az functionapp logs tail --name $FunctionAppName --resource-group $ResourceGroupName

# Logs históricos via Application Insights
az monitor app-insights query \
    --app $FunctionAppName-insights \
    --analytics-query "traces | where timestamp > ago(1h) | order by timestamp desc"
```

**Verificar Status dos Recursos**
```bash
# Status geral dos recursos
az resource list --resource-group $ResourceGroupName --query "[].{Name:name, Type:type, Location:location, Status:properties.provisioningState}" --output table

# Status específico da Function App
az functionapp show --name $FunctionAppName --resource-group $ResourceGroupName --query "{Name:name, State:state, HostNames:hostNames}"

# Status do Key Vault
az keyvault show --name $KeyVaultName --resource-group $ResourceGroupName --query "{Name:name, Location:location, Sku:properties.sku.name}"
```

## Validação Pós-Deployment

### Testes Funcionais

**Teste de Conectividade SMB**
```python
# Script de teste (executar localmente com as mesmas credenciais)
from smbclient import listdir
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential

credential = DefaultAzureCredential()
client = SecretClient(vault_url="https://$KeyVaultName.vault.azure.net/", credential=credential)

smb_server = client.get_secret("smb-server").value
smb_share = client.get_secret("smb-share").value
smb_username = client.get_secret("smb-username").value
smb_password = client.get_secret("smb-password").value

try:
    files = listdir(f"\\\\{smb_server}\\{smb_share}", username=smb_username, password=smb_password)
    print(f"Conectividade SMB OK. Arquivos encontrados: {len(files)}")
except Exception as e:
    print(f"Erro na conectividade SMB: {e}")
```

**Teste de Acesso ao Key Vault**
```bash
# Testar acesso aos segredos
az keyvault secret show --vault-name $KeyVaultName --name smb-server --query "value"
az keyvault secret show --vault-name $KeyVaultName --name storage-connection-string --query "value"
```

**Teste de Upload para Blob Storage**
```bash
# Criar arquivo de teste
echo "Teste de upload $(date)" > test-file.txt

# Upload usando Azure CLI
az storage blob upload \
    --account-name $StorageAccountName \
    --container-name processed-logs \
    --name test-file-$(date +%Y%m%d-%H%M%S).txt \
    --file test-file.txt

# Verificar upload
az storage blob list \
    --account-name $StorageAccountName \
    --container-name processed-logs \
    --output table
```

### Testes de Segurança

**Verificar Configurações de Segurança**
```bash
# Verificar HTTPS obrigatório
az functionapp show --name $FunctionAppName --resource-group $ResourceGroupName --query "httpsOnly"

# Verificar TLS mínimo
az functionapp config show --name $FunctionAppName --resource-group $ResourceGroupName --query "minTlsVersion"

# Verificar soft delete no Key Vault
az keyvault show --name $KeyVaultName --resource-group $ResourceGroupName --query "properties.enableSoftDelete"

# Verificar purge protection
az keyvault show --name $KeyVaultName --resource-group $ResourceGroupName --query "properties.enablePurgeProtection"
```

**Teste de Private Endpoints**
```bash
# Verificar Private Endpoints
az network private-endpoint list --resource-group $ResourceGroupName --output table

# Testar resolução DNS (deve resolver para IP privado)
nslookup $KeyVaultName.vault.azure.net
nslookup $StorageAccountName.blob.core.windows.net
```

### Testes de Monitoramento

**Verificar Application Insights**
```bash
# Verificar se Application Insights está coletando dados
az monitor app-insights component show --app $FunctionAppName-insights --resource-group $ResourceGroupName

# Query de teste para verificar telemetria
az monitor app-insights query \
    --app $FunctionAppName-insights \
    --analytics-query "requests | where timestamp > ago(1h) | summarize count() by bin(timestamp, 5m)"
```

**Verificar Alertas**
```bash
# Listar alertas configurados
az monitor metrics alert list --resource-group $ResourceGroupName --output table

# Verificar Action Groups
az monitor action-group list --resource-group $ResourceGroupName --output table
```

## Manutenção e Operação

### Rotação de Credenciais

**Script de Rotação Automática**
```powershell
# Script para rotação de credenciais SMB
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory=$true)]
    [string]$NewPassword
)

# Atualizar senha no Key Vault
az keyvault secret set --vault-name $KeyVaultName --name "smb-password" --value $NewPassword

# Reiniciar Function App para aplicar nova credencial
az functionapp restart --name $FunctionAppName --resource-group $ResourceGroupName

Write-Host "Credencial rotacionada com sucesso"
```

### Backup e Recuperação

**Script de Backup do Key Vault**
```bash
#!/bin/bash
# Script de backup automático do Key Vault

KEYVAULT_NAME="$1"
STORAGE_ACCOUNT="$2"
CONTAINER_NAME="keyvault-backups"
BACKUP_DATE=$(date +%Y%m%d-%H%M%S)

# Criar container se não existir
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT

# Backup de todos os segredos
SECRETS=$(az keyvault secret list --vault-name $KEYVAULT_NAME --query "[].name" -o tsv)

for SECRET in $SECRETS; do
    BACKUP_FILE="${SECRET}-backup-${BACKUP_DATE}.json"
    
    # Fazer backup do segredo
    az keyvault secret backup --vault-name $KEYVAULT_NAME --name $SECRET --file $BACKUP_FILE
    
    # Upload para storage
    az storage blob upload --account-name $STORAGE_ACCOUNT --container-name $CONTAINER_NAME --name $BACKUP_FILE --file $BACKUP_FILE
    
    # Limpar arquivo local
    rm $BACKUP_FILE
    
    echo "Backup do segredo $SECRET concluído"
done

echo "Backup completo do Key Vault finalizado"
```

### Monitoramento Contínuo

**Dashboard de Monitoramento**

Crie um dashboard personalizado no Azure Portal com os seguintes componentes:

1. **Métricas da Function App**:
   - Execution count
   - Execution duration
   - Error rate
   - Memory usage

2. **Métricas do Key Vault**:
   - Service API hits
   - Service API latency
   - Authentication failures

3. **Métricas do Storage Account**:
   - Blob count
   - Storage used
   - Transaction count

4. **Logs de Aplicação**:
   - Recent errors
   - Performance trends
   - Security events

**Alertas Recomendados**:

```bash
# Alerta para alta taxa de erro
az monitor metrics alert create \
    --name "FunctionApp-HighErrorRate" \
    --resource-group $ResourceGroupName \
    --scopes "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$FunctionAppName" \
    --condition "avg 'Http5xx' > 5" \
    --description "Alta taxa de erros HTTP 5xx" \
    --evaluation-frequency 5m \
    --window-size 15m \
    --severity 2

# Alerta para falhas de execução
az monitor metrics alert create \
    --name "FunctionApp-ExecutionFailures" \
    --resource-group $ResourceGroupName \
    --scopes "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$FunctionAppName" \
    --condition "count 'FunctionExecutionCount' < 1" \
    --description "Função não está executando" \
    --evaluation-frequency 15m \
    --window-size 30m \
    --severity 1
```

## Conclusão

Este guia fornece um roadmap completo para deployment e operação da solução FunctionCopy modernizada. Seguindo estas instruções, você terá uma implementação robusta, segura e monitorada que atende às melhores práticas da indústria.

Para suporte adicional ou questões específicas, consulte a documentação técnica ou abra uma issue no repositório do projeto.

---

**Próximos Passos Recomendados**:

1. Implementar automação completa via Terraform
2. Configurar Azure Sentinel para SIEM avançado
3. Implementar testes de carga automatizados
4. Configurar disaster recovery multi-região
5. Implementar observabilidade avançada com OpenTelemetry

