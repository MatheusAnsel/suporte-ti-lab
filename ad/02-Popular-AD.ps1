<#
.SYNOPSIS
    Cria a estrutura de OUs, grupos por setor e usuarios ficticios a partir de um CSV.

.DESCRIPTION
    Estrutura criada:
      OU=Empresa
        OU=Usuarios  -> uma OU por setor (Financeiro, RH, Comercial, TI)
        OU=Grupos    -> GG_<Setor> (grupos globais de seguranca)
        OU=Desligados
    Cada usuario e criado na OU do setor, entra no grupo do setor e precisa trocar
    a senha no primeiro logon. A senha inicial e pedida na hora.
    O script e idempotente: o que ja existe e ignorado.

.EXAMPLE
    .\02-Popular-AD.ps1 -ArquivoCsv .\usuarios.csv
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ArquivoCsv = (Join-Path $PSScriptRoot 'usuarios.csv')
)

$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory

$dominio = Get-ADDomain
$raizDn = $dominio.DistinguishedName
$sufixoUpn = $dominio.DNSRoot

function New-OUSeNaoExistir {
    param([string]$Nome, [string]$Caminho)
    $dn = "OU=$Nome,$Caminho"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($dn, 'Criar OU')) {
            New-ADOrganizationalUnit -Name $Nome -Path $Caminho -ProtectedFromAccidentalDeletion $true
            Write-Host "OU criada: $dn" -ForegroundColor Green
        }
    }
    return $dn
}

$usuarios = Import-Csv -Path $ArquivoCsv
$setores = $usuarios.Setor | Sort-Object -Unique

$ouEmpresa = New-OUSeNaoExistir -Nome 'Empresa' -Caminho $raizDn
$ouUsuarios = New-OUSeNaoExistir -Nome 'Usuarios' -Caminho $ouEmpresa
$ouGrupos = New-OUSeNaoExistir -Nome 'Grupos' -Caminho $ouEmpresa
New-OUSeNaoExistir -Nome 'Desligados' -Caminho $ouEmpresa | Out-Null

foreach ($setor in $setores) {
    New-OUSeNaoExistir -Nome $setor -Caminho $ouUsuarios | Out-Null
    $grupo = "GG_$setor"
    if (-not (Get-ADGroup -Filter "Name -eq '$grupo'" -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($grupo, 'Criar grupo')) {
            New-ADGroup -Name $grupo -GroupScope Global -GroupCategory Security -Path $ouGrupos `
                -Description "Usuarios do setor $setor"
            Write-Host "Grupo criado: $grupo" -ForegroundColor Green
        }
    }
}

$senhaInicial = Read-Host -AsSecureString -Prompt 'Senha inicial dos usuarios (sera trocada no primeiro logon)'

foreach ($u in $usuarios) {
    if (Get-ADUser -Filter "SamAccountName -eq '$($u.Login)'" -ErrorAction SilentlyContinue) {
        Write-Host "Ja existe, ignorado: $($u.Login)" -ForegroundColor Yellow
        continue
    }
    if ($PSCmdlet.ShouldProcess($u.Login, 'Criar usuario')) {
        New-ADUser `
            -Name "$($u.Nome) $($u.Sobrenome)" `
            -GivenName $u.Nome `
            -Surname $u.Sobrenome `
            -SamAccountName $u.Login `
            -UserPrincipalName "$($u.Login)@$sufixoUpn" `
            -Department $u.Setor `
            -Title $u.Cargo `
            -Path "OU=$($u.Setor),$ouUsuarios" `
            -AccountPassword $senhaInicial `
            -ChangePasswordAtLogon $true `
            -Enabled $true
        Add-ADGroupMember -Identity "GG_$($u.Setor)" -Members $u.Login
        Write-Host "Usuario criado: $($u.Login) ($($u.Setor))" -ForegroundColor Green
    }
}
