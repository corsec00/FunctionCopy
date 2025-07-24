# Arquitetura da Solução - Azure Log Processing

## Visão Geral
A solução consiste em uma Azure Function que processa arquivos de log de um compartilhamento de rede, filtra linhas específicas e armazena os resultados no Azure Blob Storage.

## Componentes Principais

### 1. Azure Function App
- **Runtime**: Python 3.9+
- **Trigger**: Timer Trigger (execução a cada 15 minutos)
- **Plano**: Consumption Plan (pay-per-use)
- **Funcionalidades**:
  - Conecta ao compartilhamento \\servidor-01\Shared02
  - Processa arquivos .LOG e .TXT
  - Filtra linhas contendo "login", "logout", "Fail"
  - Upload dos arquivos processados para Blob Storage
  - Remove arquivos originais após sucesso

### 2. Azure Storage Account
- **Tipo**: StorageV2 (General Purpose v2)
- **Replicação**: LRS (Locally Redundant Storage)
- **Containers**:
  - `processed-logs`: Armazena arquivos processados
  - `function-logs`: Logs da aplicação

### 3. Configurações de Rede
- **Conectividade**: A Function App precisa acessar o servidor on-premises
- **Opções**:
  - VPN Gateway (recomendado para produção)
  - ExpressRoute (para alta disponibilidade)
  - Site-to-Site VPN

### 4. Monitoramento
- **Application Insights**: Monitoramento e logs da Function
- **Storage Analytics**: Métricas do Storage Account

## Fluxo de Processamento

1. **Timer Trigger**: Executa a cada 15 minutos
2. **Conexão**: Conecta ao compartilhamento \\servidor-01\Shared02
3. **Listagem**: Identifica arquivos .LOG e .TXT
4. **Processamento**: Para cada arquivo:
   - Lê conteúdo linha por linha
   - Filtra linhas contendo os termos especificados
   - Cria novo arquivo com linhas filtradas
5. **Upload**: Envia arquivos processados para Blob Storage
6. **Limpeza**: Remove arquivos originais se upload foi bem-sucedido
7. **Log**: Registra resultado da operação

## Considerações de Segurança

- Credenciais do compartilhamento armazenadas como Application Settings
- Conexão segura ao Storage Account via Managed Identity
- Logs não devem conter informações sensíveis
- Acesso restrito aos recursos Azure via RBAC

## Estimativa de Custos

- **Function App**: ~$0.20/mês (baseado em execução a cada 15min)
- **Storage Account**: ~$2-5/mês (dependendo do volume)
- **Application Insights**: ~$1-3/mês
- **Total estimado**: $3-8/mês

