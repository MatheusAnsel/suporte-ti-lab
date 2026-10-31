<#
.SYNOPSIS
    Limpa arquivos temporarios para o chamado "computador lento / disco cheio".

.DESCRIPTION
    Remove arquivos com mais de N dias (padrao: 2) de:
      - Temp do usuario (%TEMP%)
      - C:\Windows\Temp (somente como administrador)
      - Cache do Windows Update (C:\Windows\SoftwareDistribution\Download, somente como administrador)
    Mostra o espaco livre antes e depois. Arquivos em uso sao ignorados.
    Use -WhatIf para simular sem apagar nada.

.EXAMPLE
    .\Limpeza-Temporarios.ps1 -WhatIf
    .\Limpeza-Temporarios.ps1 -DiasMinimos 7
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [int]$DiasMinimos = 2
)

function Get-EspacoLivreGB {
    $disco = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID = '$($env:SystemDrive)'"
    return [math]::Round($disco.FreeSpace / 1GB, 2)
}

$ehAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

$pastas = @($env:TEMP)
if ($ehAdmin) {
    $pastas += Join-Path $env:SystemRoot 'Temp'
    $pastas += Join-Path $env:SystemRoot 'SoftwareDistribution\Download'
} else {
    Write-Host 'Sem privilegio de administrador: limpando apenas a pasta Temp do usuario.' -ForegroundColor Yellow
}

$antes = Get-EspacoLivreGB
$limite = (Get-Date).AddDays(-$DiasMinimos)
$removidos = 0
$ignorados = 0

foreach ($pasta in $pastas) {
    if (-not (Test-Path $pasta)) { continue }
    Write-Host "Limpando $pasta" -ForegroundColor Cyan
    $arquivos = Get-ChildItem -Path $pasta -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object LastWriteTime -lt $limite
    foreach ($arquivo in $arquivos) {
        if ($PSCmdlet.ShouldProcess($arquivo.FullName, 'Remover')) {
            try {
                Remove-Item -LiteralPath $arquivo.FullName -Force -ErrorAction Stop
                $removidos++
            } catch {
                $ignorados++
            }
        }
    }
}

$depois = Get-EspacoLivreGB
Write-Host ''
Write-Host "Arquivos removidos: $removidos | ignorados (em uso): $ignorados" -ForegroundColor Green
Write-Host "Espaco livre em $($env:SystemDrive): $antes GB -> $depois GB (liberado: $([math]::Round($depois - $antes, 2)) GB)" -ForegroundColor Green
