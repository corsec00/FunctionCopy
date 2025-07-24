# Scripts PowerShell para Deploy

Esta pasta contém os scripts PowerShell para automatizar a criação e deploy da solução Azure Log Processor.

## Scripts Disponíveis

### 1. `deploy-complete.ps1` (RECOMENDADO)
Script principal que executa todo o processo de deploy automaticamente.

**Uso:**
```powershell
.\scripts\deploy-complete.ps1 -SmbServer "servidor-01" -SmbShare "Shared02" -SmbUsername "seu_usuario" -SmbPassword "sua_senha"
```

**Parâmetros opcionais:**
- `-SubscriptionId`: ID da subscription Azure
- `-ResourceGroupName`: Nome do resource group (padrão: rg-log-processor)
- `-Location`: Região Azure (padrão: East US)
- `-StorageAccountName`: Nome do storage account (gerado automaticamente)
- `-FunctionAppName`: Nome da function app (gerado automaticamente)

### 2. `01-create-infrastructure.ps1`
Cria toda a infraestrutura Azure necessária.

**Uso:**
```powershell
.\scripts\01-create-infrastructure.ps1 -SubscriptionId "sua-subscription" -ResourceGroupName "rg-log-processor" -Location "East US" -StorageAccountName "stlogprocessor1234" -FunctionAppName "func-log-processor-1234" -SmbServer "servidor-01" -SmbShare "Shared02" -SmbUsername "seu_usuario" -SmbPassword "sua_senha"
```

### 3. `02-deploy-function.ps1`
Faz o deploy do código da Azure Function.

**Uso:**
```powershell
.\scripts\02-deploy-function.ps1 -FunctionAppName "func-log-processor-1234" -ResourceGroupName "rg-log-processor"
```

### 4. `03-cleanup-resources.ps1`
Remove todos os recursos criados (USE COM CUIDADO).

**Uso:**
```powershell
.\scripts\03-cleanup-resources.ps1 -ResourceGroupName "rg-log-processor"
```

## Pré-requisitos

Antes de executar os scripts, certifique-se de ter:

1. **Azure CLI** instalado e configurado
   ```bash
   # Instalar Azure CLI
   # Windows: https://docs.microsoft.com/cli/azure/install-azure-cli-windows
   # Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   
   # Login
   az login
   ```

2. **Azure Functions Core Tools** v4
   ```bash
   npm install -g azure-functions-core-tools@4 --unsafe-perm true
   ```

3. **PowerShell** 5.1 ou superior (Windows) ou PowerShell Core (Linux/Mac)

4. **Permissões adequadas** na subscription Azure para criar recursos

## Ordem de Execução

### Opção 1: Deploy Automático (Recomendado)
```powershell
.\scripts\deploy-complete.ps1 -SmbServer "servidor-01" -SmbShare "Shared02" -SmbUsername "seu_usuario" -SmbPassword "sua_senha"
```

### Opção 2: Deploy Manual
```powershell
# 1. Criar infraestrutura
.\scripts\01-create-infrastructure.ps1 -SubscriptionId "sua-subscription" -ResourceGroupName "rg-log-processor" -Location "East US" -StorageAccountName "stlogprocessor1234" -FunctionAppName "func-log-processor-1234" -SmbServer "servidor-01" -SmbShare "Shared02" -SmbUsername "seu_usuario" -SmbPassword "sua_senha"

# 2. Deploy da função
.\scripts\02-deploy-function.ps1 -FunctionAppName "func-log-processor-1234" -ResourceGroupName "rg-log-processor"
```

## Recursos Criados

Os scripts criam automaticamente:

- **Resource Group**: Container para todos os recursos
- **Storage Account**: Armazenamento para a função e arquivos processados
- **Blob Container**: `processed-logs` para arquivos filtrados
- **Application Insights**: Monitoramento e logs da aplicação
- **App Service Plan**: Plano de consumo para a Function App
- **Function App**: Aplicação que executa o código Python
- **Application Settings**: Variáveis de ambiente configuradas

## Monitoramento

Após o deploy, você pode monitorar a solução através de:

1. **Portal Azure**: https://portal.azure.com
2. **Application Insights**: Logs e métricas detalhadas
3. **Storage Account**: Verificar arquivos processados no container
4. **Function App**: Logs de execução e status

## Troubleshooting

### Erro: "Azure CLI not found"
- Instale o Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli

### Erro: "Azure Functions Core Tools not found"
- Instale via npm: `npm install -g azure-functions-core-tools@4 --unsafe-perm true`

### Erro: "Not logged in to Azure"
- Execute: `az login`

### Erro: "Storage account name already exists"
- Nomes de storage account devem ser únicos globalmente
- Use o parâmetro `-StorageAccountName` com um nome diferente

### Erro durante o deploy da função
- Verifique se todos os arquivos estão presentes
- Confirme que está executando do diretório correto
- Verifique os logs no Application Insights

