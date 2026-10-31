<#
.SYNOPSIS
    Gera o inventario de hardware e software de uma estacao Windows.

.DESCRIPTION
    Coleta nome, usuario logado, sistema operacional, fabricante/modelo, numero de serie,
    processador, memoria, discos (com espaco livre), adaptadores de rede e ultimo boot.
    Salva em CSV (para importar em planilha ou no GLPI) e em HTML (para anexar ao chamado).
    Nao precisa de privilegio de administrador.

.EXAMPLE
    .\Inventario-Maquina.ps1
    .\Inventario-Maquina.ps1 -PastaSaida C:\Suporte\Inventarios
#>
[CmdletBinding()]
param(
    [string]$PastaSaida = (Join-Path $env:USERPROFILE 'Desktop')
)

$ErrorActionPreference = 'Stop'

$so = Get-CimInstance Win32_OperatingSystem
$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

$discos = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 3' | ForEach-Object {
    $livre = [math]::Round($_.FreeSpace / 1GB, 1)
    $total = [math]::Round($_.Size / 1GB, 1)
    "$($_.DeviceID) $livre GB livres de $total GB"
}

$redes = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = True' | ForEach-Object {
    "$($_.Description) | IP $($_.IPAddress -join ', ') | MAC $($_.MACAddress)"
}

$inventario = [PSCustomObject]@{
    Computador      = $env:COMPUTERNAME
    UsuarioLogado   = $cs.UserName
    Dominio         = $cs.Domain
    Fabricante      = $cs.Manufacturer
    Modelo          = $cs.Model
    NumeroSerie     = $bios.SerialNumber
    SistemaOp       = "$($so.Caption) ($($so.OSArchitecture)) build $($so.BuildNumber)"
    Processador     = $cpu.Name.Trim()
    MemoriaGB       = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    Discos          = $discos -join ' ; '
    Rede            = $redes -join ' ; '
    UltimoBoot      = $so.LastBootUpTime
    DataInventario  = Get-Date -Format 'yyyy-MM-dd HH:mm'
}

if (-not (Test-Path $PastaSaida)) { New-Item -ItemType Directory -Path $PastaSaida | Out-Null }
$base = Join-Path $PastaSaida "inventario-$($env:COMPUTERNAME)-$(Get-Date -Format 'yyyyMMdd')"

$inventario | Export-Csv -Path "$base.csv" -NoTypeInformation -Encoding UTF8
$inventario | ConvertTo-Html -As List -Title "Inventario $env:COMPUTERNAME" -PreContent "<h2>Inventario de $env:COMPUTERNAME</h2>" |
    Out-File -FilePath "$base.html" -Encoding UTF8

$inventario | Format-List
Write-Host "Arquivos gerados: $base.csv e $base.html" -ForegroundColor Green
