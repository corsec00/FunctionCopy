# Azure Log Processor - Resumo Executivo

## Visão Geral da Solução

A **Azure Log Processor Function** é uma solução completa e automatizada desenvolvida para processar arquivos de log de ambientes corporativos. A solução conecta-se automaticamente ao compartilhamento `\\servidor-01\Shared02`, processa arquivos LOG e TXT, filtra linhas contendo os termos "login", "logout" e "Fail", e armazena os resultados no Azure Blob Storage.

## Características Principais

- ✅ **Execução Automatizada**: Processa arquivos a cada 15 minutos
- ✅ **Conectividade SMB**: Acesso nativo a compartilhamentos Windows
- ✅ **Filtragem Inteligente**: Identifica linhas com termos específicos
- ✅ **Armazenamento Seguro**: Upload automático para Azure Blob Storage
- ✅ **Limpeza Automática**: Remove arquivos originais após processamento
- ✅ **Monitoramento Completo**: Application Insights integrado
- ✅ **Deploy Automatizado**: Scripts PowerShell para infraestrutura

## Arquitetura da Solução

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Compartilhamento│    │  Azure Function  │    │  Blob Storage   │
│  \\servidor-01\ │──▶│    (Python)      │───▶│ processed-logs  │
│     Shared02    │    │  Timer: 15min    │    │   container     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │ Application      │
                       │ Insights         │
                       │ (Monitoramento)  │
                       └──────────────────┘
```

## Recursos Azure Criados

| Recurso | Tipo | Finalidade |
|---------|------|------------|
| **Resource Group** | Container lógico | Organização de recursos |
| **Storage Account** | Armazenamento | Dados da função + logs processados |
| **Function App** | Compute serverless | Execução do código Python |
| **Application Insights** | Monitoramento | Logs e métricas da aplicação |
| **Blob Container** | Armazenamento | Container "processed-logs" |

## Estimativa de Custos Mensais

| Componente | Custo Estimado (USD) |
|------------|---------------------|
| Azure Function (Consumption) | $0.20 - $2.00 |
| Storage Account (Standard LRS) | $2.00 - $5.00 |
| Application Insights | $1.00 - $3.00 |
| **Total Estimado** | **$3.20 - $10.00** |

*Custos podem variar baseados no volume de dados e região Azure selecionada.*

## Como Usar Esta Solução

### Opção 1: Deploy Automatizado (Recomendado)

```powershell
# Execute o script principal com suas credenciais
.\scripts\deploy-complete.ps1 `
    -SmbServer "servidor-01" `
    -SmbShare "Shared02" `
    -SmbUsername "seu_usuario" `
    -SmbPassword "sua_senha"
```

### Opção 2: Deploy Manual

1. Execute `.\scripts\01-create-infrastructure.ps1` para criar recursos
2. Execute `.\scripts\02-deploy-function.ps1` para fazer deploy do código
3. Configure monitoramento no portal Azure

## Estrutura do Projeto

```
azure-log-processor/
├── LogProcessorFunction/          # Código da Azure Function
│   ├── __init__.py               # Código principal Python
│   └── function.json             # Configuração da função
├── scripts/                      # Scripts PowerShell
│   ├── deploy-complete.ps1       # Deploy automatizado completo
│   ├── 01-create-infrastructure.ps1
│   ├── 02-deploy-function.ps1
│   ├── 03-cleanup-resources.ps1
│   └── README.md
├── host.json                     # Configuração da Function App
├── requirements.txt              # Dependências Python
├── local.settings.json           # Configurações locais
├── README.md                     # Documentação do projeto
├── GUIA_COMPLETO.md             # Documentação técnica detalhada
└── RESUMO_EXECUTIVO.md          # Este arquivo
```

## Pré-requisitos

- **Azure CLI** instalado e configurado
- **Azure Functions Core Tools** v4
- **PowerShell** 5.1+ ou PowerShell Core 7+
- **Permissões Azure**: Contributor na subscription
- **Conectividade**: Acesso de rede entre Azure e servidor SMB

## Monitoramento e Operação

Após o deploy, monitore a solução através de:

- **Portal Azure**: Status geral dos recursos
- **Application Insights**: Logs detalhados e métricas
- **Storage Account**: Arquivos processados no container
- **Alertas**: Configurados automaticamente para falhas

## Segurança

- ✅ Credenciais criptografadas nas Application Settings
- ✅ Comunicação HTTPS obrigatória
- ✅ Princípio de menor privilégio aplicado
- ✅ Logs de auditoria completos
- ✅ Integração opcional com Azure Key Vault

## Suporte e Manutenção

- **Logs**: Disponíveis no Application Insights por 90 dias
- **Backup**: Código fonte versionado e documentado
- **Atualizações**: Scripts permitem redeploy fácil
- **Limpeza**: Script de cleanup para remoção completa

## Próximos Passos

1. **Revisar pré-requisitos** e instalar ferramentas necessárias
2. **Executar deploy** utilizando o script automatizado
3. **Configurar alertas** específicos para seu ambiente
4. **Testar conectividade** com o compartilhamento SMB
5. **Monitorar execução** através do Application Insights

---

Para documentação técnica completa, consulte o arquivo `GUIA_COMPLETO.md`.

