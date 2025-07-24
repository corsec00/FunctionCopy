# Script para limpeza dos recursos Azure
# Autor: Leo Santos
# Data: $(Get-Date)

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

Write-Host "=== Script de Limpeza de Recursos Azure ===" -ForegroundColor Red
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow

if (-not $Force) {
    Write-Host "`nAVISO: Este script irá DELETAR PERMANENTEMENTE todos os recursos no Resource Group!" -ForegroundColor Red
    Write-Host "Isso inclui:" -ForegroundColor Yellow
    Write-Host "- Function App e todas as funções" -ForegroundColor White
    Write-Host "- Storage Account e todos os dados" -ForegroundColor White
    Write-Host "- Application Insights e histórico de logs" -ForegroundColor White
    Write-Host "- App Service Plan" -ForegroundColor White
    Write-Host "- Todos os outros recursos no Resource Group" -ForegroundColor White
    
    $confirmation = Read-Host "`nTem certeza que deseja continuar? Digite 'DELETE' para confirmar"
    
    if ($confirmation -ne "DELETE") {
        Write-Host "Operação cancelada pelo usuário" -ForegroundColor Green
        exit 0
    }
}

# Listar recursos antes da exclusão
Write-Host "`n1. Listando recursos que serão deletados..." -ForegroundColor Cyan
az resource list --resource-group $ResourceGroupName --output table

Write-Host "`n2. Iniciando exclusão do Resource Group..." -ForegroundColor Cyan
Write-Host "Isso pode levar alguns minutos..." -ForegroundColor Yellow

try {
    az group delete --name $ResourceGroupName --yes --no-wait
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nExclusão iniciada com sucesso!" -ForegroundColor Green
        Write-Host "O processo continuará em background." -ForegroundColor Yellow
        Write-Host "Você pode verificar o status no portal Azure." -ForegroundColor Yellow
    } else {
        Write-Host "Erro ao iniciar a exclusão" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Erro ao executar a exclusão: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Limpeza iniciada ===" -ForegroundColor Green
Write-Host "`nPara verificar o progresso:" -ForegroundColor Yellow
Write-Host "az group show --name $ResourceGroupName --query properties.provisioningState" -ForegroundColor White
Write-Host "`nQuando a exclusão estiver completa, o comando acima retornará um erro." -ForegroundColor White

