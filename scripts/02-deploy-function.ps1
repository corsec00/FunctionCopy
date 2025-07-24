# Script para deploy da Azure Function
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

Write-Host "=== Iniciando deploy da Azure Function ===" -ForegroundColor Green
Write-Host "Function App: $FunctionAppName" -ForegroundColor Yellow
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Project Path: $ProjectPath" -ForegroundColor Yellow

# Verificar se o Azure Functions Core Tools está instalado
Write-Host "`n1. Verificando Azure Functions Core Tools..." -ForegroundColor Cyan
try {
    $funcVersion = func --version
    Write-Host "Azure Functions Core Tools versão: $funcVersion" -ForegroundColor Green
} catch {
    Write-Host "Azure Functions Core Tools não encontrado!" -ForegroundColor Red
    Write-Host "Instale usando: npm install -g azure-functions-core-tools@4 --unsafe-perm true" -ForegroundColor Yellow
    exit 1
}

# Verificar se estamos no diretório correto
Write-Host "`n2. Verificando estrutura do projeto..." -ForegroundColor Cyan
if (-not (Test-Path "$ProjectPath/host.json")) {
    Write-Host "Arquivo host.json não encontrado! Verifique se está no diretório correto." -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "$ProjectPath/LogProcessorFunction/function.json")) {
    Write-Host "Arquivo function.json não encontrado! Verifique a estrutura do projeto." -ForegroundColor Red
    exit 1
}

Write-Host "Estrutura do projeto verificada com sucesso" -ForegroundColor Green

# Navegar para o diretório do projeto
Set-Location $ProjectPath

# Fazer o deploy
Write-Host "`n3. Fazendo deploy da função..." -ForegroundColor Cyan
try {
    func azure functionapp publish $FunctionAppName --python
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Deploy realizado com sucesso!" -ForegroundColor Green
    } else {
        Write-Host "Erro durante o deploy" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Erro ao executar o deploy: $_" -ForegroundColor Red
    exit 1
}

# Verificar status da Function App
Write-Host "`n4. Verificando status da Function App..." -ForegroundColor Cyan
$functionAppStatus = az functionapp show `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --query state `
    --output tsv

if ($functionAppStatus -eq "Running") {
    Write-Host "Function App está executando corretamente" -ForegroundColor Green
} else {
    Write-Host "Function App status: $functionAppStatus" -ForegroundColor Yellow
}

# Listar funções deployadas
Write-Host "`n5. Listando funções deployadas..." -ForegroundColor Cyan
az functionapp function list `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --query "[].{Name:name, Status:config.disabled}" `
    --output table

Write-Host "`n=== Deploy concluído com sucesso! ===" -ForegroundColor Green
Write-Host "`nPróximos passos:" -ForegroundColor Yellow
Write-Host "1. Acesse o portal Azure para monitorar a execução" -ForegroundColor White
Write-Host "2. Verifique os logs no Application Insights" -ForegroundColor White
Write-Host "3. A função será executada automaticamente a cada 15 minutos" -ForegroundColor White
Write-Host "4. Monitore o container 'processed-logs' no Storage Account" -ForegroundColor White

Write-Host "`nURLs úteis:" -ForegroundColor Yellow
Write-Host "- Portal Azure: https://portal.azure.com" -ForegroundColor White
Write-Host "- Function App: https://$FunctionAppName.azurewebsites.net" -ForegroundColor White

