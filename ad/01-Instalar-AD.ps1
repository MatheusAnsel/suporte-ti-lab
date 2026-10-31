<#
.SYNOPSIS
    Instala o Active Directory Domain Services e cria o dominio do laboratorio.

.DESCRIPTION
    Executar no Windows Server (versao de avaliacao) recem-instalado, como Administrador.
    O servidor reinicia ao final da promocao a controlador de dominio.
    A senha do modo de restauracao (DSRM) e pedida na hora; nenhuma senha fica gravada no script.

.EXAMPLE
    .\01-Instalar-AD.ps1 -NomeDominio "lab.local" -NomeNetBIOS "LAB"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$NomeDominio = 'lab.local',
    [string]$NomeNetBIOS = 'LAB'
)

$ErrorActionPreference = 'Stop'

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Execute este script em um PowerShell aberto como Administrador.'
}

Write-Host "Instalando a funcao AD DS e as ferramentas de gerenciamento..." -ForegroundColor Cyan
Install-WindowsFeature -Name AD-Domain-Services, DNS, GPMC -IncludeManagementTools | Out-Null

$senhaDsrm = Read-Host -AsSecureString -Prompt 'Defina a senha do modo de restauracao (DSRM)'

if ($PSCmdlet.ShouldProcess($NomeDominio, 'Criar nova floresta e promover a controlador de dominio')) {
    Install-ADDSForest `
        -DomainName $NomeDominio `
        -DomainNetbiosName $NomeNetBIOS `
        -InstallDns `
        -SafeModeAdministratorPassword $senhaDsrm `
        -Force
}
