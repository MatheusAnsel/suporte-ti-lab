<#
.SYNOPSIS
    Roteiro automatico para o chamado "estou sem internet / sem acesso ao sistema".

.DESCRIPTION
    Testa em camadas, do mais proximo ao mais distante, e para em cada falha
    com a orientacao do que verificar:
      1. Adaptador de rede conectado
      2. Endereco IP valido (detecta APIPA 169.254.x.x = DHCP sem resposta)
      3. Gateway responde
      4. DNS resolve nomes
      5. Internet acessivel (HTTPS na porta 443)
      6. Destino opcional (servidor ou sistema interno)
    O resultado sai na tela e em um TXT para colar no chamado.

.EXAMPLE
    .\Diagnostico-Rede.ps1
    .\Diagnostico-Rede.ps1 -Destino srv-erp.lab.local -Porta 443
#>
[CmdletBinding()]
param(
    [string]$Destino,
    [int]$Porta = 443,
    [string]$SiteTeste = 'www.google.com'
)

$resultados = [System.Collections.Generic.List[object]]::new()

function Add-Resultado {
    param([string]$Teste, [bool]$Ok, [string]$Detalhe, [string]$Orientacao = '')
    $resultados.Add([PSCustomObject]@{
        Teste      = $Teste
        Status     = if ($Ok) { 'OK' } else { 'FALHA' }
        Detalhe    = $Detalhe
        Orientacao = $Orientacao
    })
    $cor = if ($Ok) { 'Green' } else { 'Red' }
    Write-Host ("[{0}] {1}: {2}" -f $(if ($Ok) { 'OK' } else { 'FALHA' }), $Teste, $Detalhe) -ForegroundColor $cor
    if (-not $Ok -and $Orientacao) { Write-Host "      -> $Orientacao" -ForegroundColor Yellow }
}

function Complete-Diagnostico {
    $arquivo = Join-Path $env:TEMP "diagnostico-rede-$($env:COMPUTERNAME)-$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
    $resultados | Format-Table -AutoSize -Wrap | Out-String -Width 200 | Out-File -FilePath $arquivo -Encoding UTF8
    Write-Host "`nRelatorio salvo em: $arquivo" -ForegroundColor Cyan
}

# 1. Adaptador
$adaptadores = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up'
if (-not $adaptadores) {
    Add-Resultado 'Adaptador' $false 'Nenhum adaptador fisico conectado' 'Verificar cabo, Wi-Fi desligado, modo aviao ou driver da placa no Gerenciador de Dispositivos.'
    Complete-Diagnostico; return
}
Add-Resultado 'Adaptador' $true (($adaptadores | ForEach-Object { "$($_.Name) $($_.LinkSpeed)" }) -join ', ')

# 2. IP
$config = Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq 'Up' -and $_.IPv4Address } | Select-Object -First 1
$ip = $config.IPv4Address.IPAddress
if (-not $ip -or $ip -like '169.254.*') {
    Add-Resultado 'Endereco IP' $false "IP $ip" 'IP APIPA: o DHCP nao respondeu. Testar ipconfig /release e /renew; verificar o roteador/servidor DHCP.'
    Complete-Diagnostico; return
}
Add-Resultado 'Endereco IP' $true "$ip ($($config.InterfaceAlias))"

# 3. Gateway
$gateway = $config.IPv4DefaultGateway.NextHop
if (-not $gateway) {
    Add-Resultado 'Gateway' $false 'Sem gateway padrao' 'Configuracao de IP incompleta. Verificar IP fixo ou escopo DHCP.'
    Complete-Diagnostico; return
}
$gwOk = Test-Connection -ComputerName $gateway -Count 2 -Quiet
Add-Resultado 'Gateway' $gwOk $gateway 'Gateway nao responde: problema na rede local (switch, roteador, cabo ou VLAN).'
if (-not $gwOk) { Complete-Diagnostico; return }

# 4. DNS
try {
    $resolvido = Resolve-DnsName -Name $SiteTeste -ErrorAction Stop | Where-Object IPAddress | Select-Object -First 1
    Add-Resultado 'DNS' $true "$SiteTeste -> $($resolvido.IPAddress)"
} catch {
    $servidoresDns = (Get-DnsClientServerAddress -AddressFamily IPv4 -InterfaceAlias $config.InterfaceAlias).ServerAddresses -join ', '
    Add-Resultado 'DNS' $false "Nao resolveu $SiteTeste (DNS: $servidoresDns)" 'Testar ipconfig /flushdns; conferir servidor DNS configurado.'
    Complete-Diagnostico; return
}

# 5. Internet
$web = Test-NetConnection -ComputerName $SiteTeste -Port 443 -WarningAction SilentlyContinue
Add-Resultado 'Internet (443)' $web.TcpTestSucceeded $SiteTeste 'DNS ok mas sem saida: verificar proxy, firewall ou link da operadora.'

# 6. Destino interno opcional
if ($Destino) {
    $alvo = Test-NetConnection -ComputerName $Destino -Port $Porta -WarningAction SilentlyContinue
    Add-Resultado "Destino $Destino`:$Porta" $alvo.TcpTestSucceeded $Destino 'Servico indisponivel ou bloqueado: escalar para N2/infraestrutura com este relatorio.'
}

Complete-Diagnostico
