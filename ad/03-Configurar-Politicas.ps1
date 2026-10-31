<#
.SYNOPSIS
    Aplica a politica de senha do dominio e cria duas GPOs de seguranca.

.DESCRIPTION
    1. Politica de senha padrao do dominio: minimo de 10 caracteres, complexidade,
       historico de 5 senhas e bloqueio da conta apos 5 tentativas erradas por 15 minutos.
    2. GPO "SEG - Bloqueio de tela": protecao de tela com senha apos 10 minutos,
       vinculada a OU de usuarios.
    3. GPO "SEG - Bloqueio de USB": nega acesso a armazenamento removivel,
       vinculada a OU do Financeiro.

    Para testar em uma estacao do dominio: gpupdate /force e depois gpresult /r.

.EXAMPLE
    .\03-Configurar-Politicas.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
Import-Module GroupPolicy

$dominio = Get-ADDomain
$ouUsuarios = "OU=Usuarios,OU=Empresa,$($dominio.DistinguishedName)"
$ouFinanceiro = "OU=Financeiro,$ouUsuarios"

if ($PSCmdlet.ShouldProcess($dominio.DNSRoot, 'Definir politica de senha e bloqueio')) {
    Set-ADDefaultDomainPasswordPolicy -Identity $dominio.DNSRoot `
        -MinPasswordLength 10 `
        -ComplexityEnabled $true `
        -PasswordHistoryCount 5 `
        -LockoutThreshold 5 `
        -LockoutDuration (New-TimeSpan -Minutes 15) `
        -LockoutObservationWindow (New-TimeSpan -Minutes 15)
    Write-Host 'Politica de senha aplicada.' -ForegroundColor Green
}

function New-GpoSeNaoExistir {
    param([string]$Nome, [string]$Comentario)
    $gpo = Get-GPO -Name $Nome -ErrorAction SilentlyContinue
    if (-not $gpo) {
        $gpo = New-GPO -Name $Nome -Comment $Comentario
        Write-Host "GPO criada: $Nome" -ForegroundColor Green
    }
    return $gpo
}

function Set-VinculoGpo {
    param([string]$Nome, [string]$Alvo)
    $vinculado = (Get-GPInheritance -Target $Alvo).GpoLinks | Where-Object DisplayName -eq $Nome
    if (-not $vinculado) {
        New-GPLink -Name $Nome -Target $Alvo | Out-Null
        Write-Host "GPO '$Nome' vinculada a $Alvo" -ForegroundColor Green
    }
}

# Bloqueio de tela (configuracao de usuario)
$gpoTela = 'SEG - Bloqueio de tela'
if ($PSCmdlet.ShouldProcess($gpoTela, 'Criar e configurar GPO')) {
    New-GpoSeNaoExistir -Nome $gpoTela -Comentario 'Protecao de tela com senha apos 10 minutos' | Out-Null
    $chave = 'HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop'
    Set-GPRegistryValue -Name $gpoTela -Key $chave -ValueName 'ScreenSaveActive' -Type String -Value '1' | Out-Null
    Set-GPRegistryValue -Name $gpoTela -Key $chave -ValueName 'ScreenSaverIsSecure' -Type String -Value '1' | Out-Null
    Set-GPRegistryValue -Name $gpoTela -Key $chave -ValueName 'ScreenSaveTimeOut' -Type String -Value '600' | Out-Null
    Set-VinculoGpo -Nome $gpoTela -Alvo $ouUsuarios
}

# Bloqueio de armazenamento USB (configuracao de computador)
$gpoUsb = 'SEG - Bloqueio de USB'
if ($PSCmdlet.ShouldProcess($gpoUsb, 'Criar e configurar GPO')) {
    New-GpoSeNaoExistir -Nome $gpoUsb -Comentario 'Nega acesso a armazenamento removivel' | Out-Null
    $chave = 'HKLM\Software\Policies\Microsoft\Windows\RemovableStorageDevices'
    Set-GPRegistryValue -Name $gpoUsb -Key $chave -ValueName 'Deny_All' -Type DWord -Value 1 | Out-Null
    Set-VinculoGpo -Nome $gpoUsb -Alvo $ouFinanceiro
    Write-Host 'Obs.: a GPO de USB vale para computadores; mova a estacao de teste para a OU do Financeiro para validar.' -ForegroundColor Yellow
}
