# Azure Log Processor Function

Esta Azure Function processa arquivos de log de um compartilhamento de rede, filtra linhas específicas e armazena os resultados no Azure Blob Storage.

## Funcionalidades

- Executa automaticamente a cada 15 minutos
- Conecta ao compartilhamento `\\servidor-01\Shared02`
- Processa arquivos .LOG e .TXT
- Filtra linhas contendo "login", "logout" ou "Fail"
- Upload dos arquivos processados para Blob Storage
- Remove arquivos originais após processamento bem-sucedido

## Estrutura do Projeto

```
FUNCTIONCOPY/
├── LogProcessorFunction/
│   ├── __init__.py          # Código principal da função
│   └── function.json        # Configuração da função
├── host.json                # Configuração do host
├── requirements.txt         # Dependências Python
├── local.settings.json      # Configurações locais (desenvolvimento)
└── README.md                # Este arquivo
```

## Configurações Necessárias

As seguintes variáveis de ambiente devem ser configuradas na Function App:

- `SMB_SERVER`: Nome do servidor (ex: servidor-01)
- `SMB_SHARE`: Nome do compartilhamento (ex: Shared02)
- `SMB_USERNAME`: Usuário para acesso ao compartilhamento
- `SMB_PASSWORD`: Senha para acesso ao compartilhamento
- `STORAGE_CONNECTION_STRING`: String de conexão do Storage Account
- `BLOB_CONTAINER_NAME`: Nome do container no Blob Storage (ex: processed-logs)

## Dependências

- `azure-functions`: SDK das Azure Functions
- `azure-storage-blob`: Cliente para Blob Storage
- `smbprotocol`: Cliente SMB para Python
- `logging`: Logging (built-in)

## Deploy

Use os scripts PowerShell fornecidos para criar a infraestrutura e fazer o deploy da função.

