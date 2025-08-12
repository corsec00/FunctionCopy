# Script para deploy da Azure Function com Azure Key Vault
# Autor: Leo Santos
# Data: $(Get-Date)

param(
    [Parameter(Mandatory=$true)]
    [string]$FunctionAppName,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = "."
)

Write-Host "=== Iniciando Deploy da Azure Function ===" -ForegroundColor Green
Write-Host "Function App: $FunctionAppName" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Project Path: $ProjectPath" -ForegroundColor Yellow

# Verificar se o Azure Functions Core Tools está instalado
Write-Host "n1. Verificando Azure Functions Core Tools..." -ForegroundColor Cyan
try {
    $funcVersion = func --version
    Write-Host "Azure Functions Core Tools: $funcVersion" -ForegroundColor Green
} catch {
    Write-Host "Azure Functions Core Tools não encontrado!" -ForegroundColor Red
    Write-Host "Instale usando: npm install -g azure-functions-core-tools@4 --unsafe-perm true" -ForegroundColor Yellow
    exit 1
}

# Verificar se está logado no Azure
Write-Host "n2. Verificando login no Azure..." -ForegroundColor Cyan
try {
    $account = az account show --query user.name --output tsv
    Write-Host "Logado como: $account" -ForegroundColor Green
} catch {
    Write-Host "Não logado no Azure. Execute 'az login' primeiro." -ForegroundColor Red
    exit 1
}

# Verificar se os arquivos necessários existem
Write-Host "n3. Verificando arquivos do projeto..." -ForegroundColor Cyan
$requiredFiles = @(
    "host.json",
    "requirements.txt",
    "LogProcessorFunction/__init__.py",
    "LogProcessorFunction/function.json"
)

foreach ($file in $requiredFiles) {
    $filePath = Join-Path $ProjectPath $file
    if (-not (Test-Path $filePath)) {
        Write-Host "Arquivo obrigatório não encontrado: $file" -ForegroundColor Red
        exit 1
    }
}
Write-Host "Todos os arquivos necessários encontrados" -ForegroundColor Green

# Navegar para o diretório do projeto
Write-Host "n4. Navegando para o diretório do projeto..." -ForegroundColor Cyan
$originalLocation = Get-Location
Set-Location $ProjectPath

try {
    # Fazer o deploy da função
    Write-Host "n5. Fazendo deploy da função..." -ForegroundColor Cyan
    func azure functionapp publish $FunctionAppName --python

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Deploy realizado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "Erro durante o deploy" -ForegroundColor Red
        exit 1
    }

    # Verificar status da função
    Write-Host "n6. Verificando status da função..." -ForegroundColor Cyan
    $functionStatus = az functionapp show --name $FunctionAppName --resource-group $ResourceGroupName --query state --output tsv
    Write-Host "Status da Function App: $functionStatus" -ForegroundColor Green

    # Obter URL da função
    Write-Host "n7. Obtendo informações da função..." -ForegroundColor Cyan
    $functionUrl = az functionapp show --name $FunctionAppName --resource-group $ResourceGroupName --query defaultHostName --output tsv
    Write-Host "URL da Function App: https://$functionUrl" -ForegroundColor Green

    Write-Host "n=== Deploy Concluído com Sucesso! ===" -ForegroundColor Green
    Write-Host "nInformações importantes:" -ForegroundColor Yellow
    Write-Host "- Function App: $FunctionAppName" -ForegroundColor White
    Write-Host "- URL: https://$functionUrl" -ForegroundColor White
    Write-Host "- Status: $functionStatus" -ForegroundColor White
    
    Write-Host "nMonitoramento:" -ForegroundColor Yellow
    Write-Host "- Portal Azure: https://portal.azure.com" -ForegroundColor White
    Write-Host "- Application Insights: Verifique logs e métricas" -ForegroundColor White
    Write-Host "- Storage Account: Verifique arquivos processados" -ForegroundColor White
    
    Write-Host "nPróximos passos:" -ForegroundColor Yellow
    Write-Host "1. Aguarde a próxima execução (a cada 15 minutos)" -ForegroundColor White
    Write-Host "2. Monitore os logs no Application Insights" -ForegroundColor White
    Write-Host "3. Verifique os arquivos processados no container 'processed-logs'" -ForegroundColor White

} finally {
    # Retornar ao diretório original
    Set-Location $originalLocation
}

