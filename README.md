# FunctionCopy - PowerShell Version

Azure Function em PowerShell para processamento automatizado de arquivos de log de compartilhamentos SMB com integração segura ao Azure Key Vault.

## Visão Geral

Esta é uma versão PowerShell do projeto FunctionCopy original (Python), que processa arquivos de log de compartilhamentos de rede SMB, filtra linhas relevantes e armazena os resultados no Azure Blob Storage.

### Principais Funcionalidades

- **Processamento Automatizado**: Executa a cada 15 minutos via Timer Trigger
- **Segurança Integrada**: Credenciais armazenadas no Azure Key Vault
- **Filtragem Inteligente**: Filtra linhas contendo palavras-chave: `login`, `logout`, `fail`
- **Armazenamento Seguro**: Upload automático para Azure Blob Storage
- **Limpeza Automática**: Remove arquivos originais após processamento bem-sucedido

## Arquitetura

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Timer Trigger │───▶│  Azure Function  │───▶│  Azure Key Vault│
│   (15 minutos)  │    │   (PowerShell)   │    │   (Credenciais) │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Compartilhamento│◀───│  Processamento   │───▶│  Azure Blob     │
│      SMB        │    │    de Logs       │    │    Storage      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Estrutura do Projeto

```
FunctionCopy-PowerShell/
├── LogProcessorFunction/
│   ├── run.ps1              # Script principal da função
│   └── function.json        # Configuração do timer trigger
├── host.json                # Configurações do host
├── requirements.psd1        # Dependências PowerShell
├── profile.ps1              # Inicialização de módulos
├── local.settings.json      # Configurações locais
└── README.md               # Este arquivo
```

## Pré-requisitos

### Ambiente de Desenvolvimento
- **PowerShell 7.2+**
- **Azure Functions Core Tools v4**
- **Azure CLI**
- **Visual Studio Code** (recomendado)
  - Extensão Azure Functions
  - Extensão PowerShell

### Recursos Azure
- **Azure Function App** (PowerShell 7.2 runtime)
- **Azure Key Vault**
- **Azure Storage Account**
- **Managed Identity** habilitada na Function App

## Configuração

### 1. Azure Key Vault

Crie os seguintes secrets no Azure Key Vault:

```bash
# Credenciais do compartilhamento SMB
az keyvault secret set --vault-name "your-keyvault" --name "smb-server" --value "server.domain.com"
az keyvault secret set --vault-name "your-keyvault" --name "smb-share" --value "logs"
az keyvault secret set --vault-name "your-keyvault" --name "smb-username" --value "username"
az keyvault secret set --vault-name "your-keyvault" --name "smb-password" --value "password"

# Connection string do Storage Account
az keyvault secret set --vault-name "your-keyvault" --name "storage-connection-string" --value "DefaultEndpointsProtocol=https;AccountName=..."
```

### 2. Managed Identity

Configure a Managed Identity da Function App com acesso ao Key Vault:

```bash
# Habilitar Managed Identity
az functionapp identity assign --name "your-function-app" --resource-group "your-rg"

# Conceder acesso ao Key Vault
az keyvault set-policy --name "your-keyvault" --object-id "managed-identity-object-id" --secret-permissions get list
```

### 3. Variáveis de Ambiente

Configure as seguintes variáveis na Function App:

```bash
az functionapp config appsettings set --name "your-function-app" --resource-group "your-rg" --settings \
  "KEY_VAULT_NAME=your-keyvault-name" \
  "BLOB_CONTAINER_NAME=processed-logs"
```

### 4. Container de Blob Storage

Crie o container para armazenar os logs processados:

```bash
az storage container create --name "processed-logs" --account-name "your-storage-account"
```

## Desenvolvimento Local

### 1. Configuração Local

Edite o arquivo `local.settings.json`:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "powershell",
    "FUNCTIONS_WORKER_RUNTIME_VERSION": "7.2",
    "KEY_VAULT_NAME": "your-keyvault-name",
    "BLOB_CONTAINER_NAME": "processed-logs"
  }
}
```

### 2. Executar Localmente

```bash
# Instalar dependências
func extensions install

# Executar a função localmente
func start
```

### 3. Testar a Função

```bash
# Trigger manual da função
func start --verbose
```

## Deploy

### Método 1: Azure Functions Core Tools

```bash
# Login no Azure
az login

# Deploy da função
func azure functionapp publish your-function-app-name
```

### Método 2: Azure CLI

```bash
# Criar zip do projeto
zip -r function-app.zip . -x "*.git*" "local.settings.json"

# Deploy via Azure CLI
az functionapp deployment source config-zip --resource-group "your-rg" --name "your-function-app" --src "function-app.zip"
```

### Método 3: GitHub Actions

Crie um workflow `.github/workflows/deploy.yml`:

```yaml
name: Deploy Azure Function

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Deploy to Azure Functions
      uses: Azure/functions-action@v1
      with:
        app-name: 'your-function-app'
        package: '.'
```

## Monitoramento

### Application Insights

A função automaticamente envia logs para o Application Insights. Monitore:

- **Execuções**: Frequência e duração das execuções
- **Erros**: Falhas de conexão SMB ou upload
- **Performance**: Tempo de processamento por arquivo

### Queries KQL Úteis

```kql
// Execuções da função nas últimas 24 horas
traces
| where timestamp > ago(24h)
| where message contains "PowerShell timer trigger function executed"
| summarize count() by bin(timestamp, 1h)

// Erros de processamento
traces
| where timestamp > ago(24h)
| where severityLevel >= 3
| project timestamp, message, severityLevel
```

## Troubleshooting

### Problemas Comuns

1. **Erro de Conexão SMB**
   - Verificar credenciais no Key Vault
   - Confirmar conectividade de rede
   - Validar permissões do usuário SMB

2. **Erro de Key Vault**
   - Verificar Managed Identity
   - Confirmar permissões no Key Vault
   - Validar nome do Key Vault

3. **Erro de Blob Storage**
   - Verificar connection string
   - Confirmar existência do container
   - Validar permissões de escrita

### Logs de Debug

Para habilitar logs detalhados, adicione na configuração:

```json
{
  "logging": {
    "logLevel": {
      "default": "Information",
      "Function.LogProcessorFunction": "Debug"
    }
  }
}
```

## Segurança

### Boas Práticas Implementadas

- ✅ Credenciais armazenadas no Key Vault
- ✅ Managed Identity para autenticação
- ✅ Conexões criptografadas (TLS)
- ✅ Princípio do menor privilégio
- ✅ Logs de auditoria completos

### Recomendações Adicionais

- Configure Network Security Groups
- Use Private Endpoints quando possível
- Implemente backup do Key Vault
- Configure alertas de segurança

## Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## Licença

Este projeto está licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.

## Suporte

Para suporte e dúvidas:
- Abra uma issue no GitHub
- Consulte a documentação oficial do Azure Functions
- Verifique os logs no Application Insights

fim durante uma aula da FIAP