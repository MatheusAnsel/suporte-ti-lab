<#
.SYNOPSIS
    Funcoes para os atendimentos mais comuns de N1 no Active Directory.

.DESCRIPTION
    Carregue as funcoes na sessao com:  . .\04-Rotinas-N1.ps1
    Todas registram o atendimento em um log CSV (numero do chamado, acao, usuario, tecnico, data).

    Funcoes:
      Get-StatusUsuario       Conta ativa? bloqueada? ultima troca de senha? grupos?
      Reset-SenhaUsuario      Reseta a senha e obriga troca no proximo logon
      Unlock-ContaUsuario     Desbloqueia conta bloqueada por tentativas erradas
      Add-UsuarioGrupo        Concede acesso adicionando a um grupo
      Disable-UsuarioDesligado  Offboarding: desativa, remove grupos e move para OU Desligados

.EXAMPLE
    . .\04-Rotinas-N1.ps1
    Get-StatusUsuario -Login ana.souza
    Unlock-ContaUsuario -Login ana.souza -Chamado 1042
#>

Import-Module ActiveDirectory

$script:ArquivoLog = Join-Path $PSScriptRoot 'log-atendimentos.csv'

function Write-LogAtendimento {
    param([string]$Chamado, [string]$Acao, [string]$Login)
    [PSCustomObject]@{
        DataHora = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        Chamado  = $Chamado
        Acao     = $Acao
        Usuario  = $Login
        Tecnico  = $env:USERNAME
    } | Export-Csv -Path $script:ArquivoLog -Append -NoTypeInformation -Encoding UTF8
}

function Get-StatusUsuario {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Login)

    $u = Get-ADUser -Identity $Login -Properties Enabled, LockedOut, PasswordLastSet, LastLogonDate, MemberOf, Department, Title
    [PSCustomObject]@{
        Usuario         = $u.SamAccountName
        Nome            = $u.Name
        Setor           = $u.Department
        Cargo           = $u.Title
        Ativo           = $u.Enabled
        Bloqueado       = $u.LockedOut
        UltimaSenha     = $u.PasswordLastSet
        UltimoLogon     = $u.LastLogonDate
        Grupos          = ($u.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' }) -join ', '
    }
}

function Reset-SenhaUsuario {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Login,
        [Parameter(Mandatory)][string]$Chamado
    )
    $novaSenha = Read-Host -AsSecureString -Prompt "Nova senha temporaria para $Login"
    if ($PSCmdlet.ShouldProcess($Login, 'Resetar senha')) {
        Set-ADAccountPassword -Identity $Login -NewPassword $novaSenha -Reset
        Set-ADUser -Identity $Login -ChangePasswordAtLogon $true
        Unlock-ADAccount -Identity $Login
        Write-LogAtendimento -Chamado $Chamado -Acao 'Reset de senha' -Login $Login
        Write-Host "Senha de $Login resetada. Troca obrigatoria no proximo logon." -ForegroundColor Green
    }
}

function Unlock-ContaUsuario {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Login,
        [Parameter(Mandatory)][string]$Chamado
    )
    $u = Get-ADUser -Identity $Login -Properties LockedOut
    if (-not $u.LockedOut) {
        Write-Host "$Login nao esta bloqueado. Verifique senha expirada ou conta desativada (Get-StatusUsuario)." -ForegroundColor Yellow
        return
    }
    if ($PSCmdlet.ShouldProcess($Login, 'Desbloquear conta')) {
        Unlock-ADAccount -Identity $Login
        Write-LogAtendimento -Chamado $Chamado -Acao 'Desbloqueio de conta' -Login $Login
        Write-Host "Conta $Login desbloqueada." -ForegroundColor Green
    }
}

function Add-UsuarioGrupo {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Login,
        [Parameter(Mandatory)][string]$Grupo,
        [Parameter(Mandatory)][string]$Chamado
    )
    if ($PSCmdlet.ShouldProcess("$Login -> $Grupo", 'Adicionar ao grupo')) {
        Add-ADGroupMember -Identity $Grupo -Members $Login
        Write-LogAtendimento -Chamado $Chamado -Acao "Adicionado ao grupo $Grupo" -Login $Login
        Write-Host "$Login adicionado a $Grupo." -ForegroundColor Green
    }
}

function Disable-UsuarioDesligado {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$Login,
        [Parameter(Mandatory)][string]$Chamado
    )
    $dominio = Get-ADDomain
    $ouDesligados = "OU=Desligados,OU=Empresa,$($dominio.DistinguishedName)"
    $u = Get-ADUser -Identity $Login -Properties MemberOf

    if ($PSCmdlet.ShouldProcess($Login, 'Desativar, remover grupos e mover para Desligados')) {
        Disable-ADAccount -Identity $Login
        foreach ($g in $u.MemberOf) {
            Remove-ADGroupMember -Identity $g -Members $Login -Confirm:$false
        }
        Set-ADUser -Identity $Login -Description "Desligado em $(Get-Date -Format 'dd/MM/yyyy') - chamado $Chamado"
        Move-ADObject -Identity $u.DistinguishedName -TargetPath $ouDesligados
        Write-LogAtendimento -Chamado $Chamado -Acao 'Offboarding' -Login $Login
        Write-Host "$Login desativado e movido para Desligados." -ForegroundColor Green
    }
}
