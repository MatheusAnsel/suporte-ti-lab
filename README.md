# Laboratorio de Suporte de TI

Ambiente de laboratorio que reproduz a rotina de um service desk: dominio Active Directory com usuarios, grupos e politicas, ferramenta de chamados GLPI com SLA e base de conhecimento, e scripts PowerShell para os atendimentos mais comuns de N1.

## O que tem aqui

| Pasta | Conteudo |
|---|---|
| `ad/` | Criacao do dominio, OUs por setor, grupos, usuarios via CSV, politica de senha, GPOs de bloqueio de tela e de USB, e funcoes de N1 (reset de senha, desbloqueio, acesso a grupo, offboarding) com log de atendimento |
| `scripts/` | Inventario de hardware da estacao, diagnostico de rede em camadas e limpeza de temporarios |
| `glpi/` | GLPI em Docker com a imagem oficial e o roteiro de configuracao (categorias, SLA, grupos N1/N2, ativos) |
| `docs/` | Fluxo de atendimento baseado em ITIL 4 (incidente, requisicao, problema, matriz de prioridade, SLA) e base de conhecimento |

## Arquitetura do laboratorio

```mermaid
flowchart LR
    subgraph VirtualBox
        DC[Windows Server<br/>AD DS + DNS + GPO<br/>lab.local]
        WS[Windows 10/11<br/>estacao no dominio]
    end
    subgraph Docker
        GLPI[GLPI<br/>chamados, SLA, ativos]
        DB[(MySQL)]
    end
    WS -- logon e GPO --> DC
    WS -- abre chamado --> GLPI
    GLPI --> DB
```

## Como montar

### 1. Maquinas virtuais
- VirtualBox (gratuito).
- Windows Server em versao de avaliacao gratuita (Microsoft Evaluation Center).
- Windows 10/11 Enterprise em versao de avaliacao para a estacao.
- Rede das duas VMs em "Rede interna" ou "Rede NAT"; o DNS da estacao aponta para o IP do servidor.

### 2. Active Directory (no servidor, PowerShell como Administrador)
```powershell
.\ad\01-Instalar-AD.ps1                 # cria o dominio lab.local (o servidor reinicia)
.\ad\02-Popular-AD.ps1                  # OUs, grupos e usuarios do usuarios.csv
.\ad\03-Configurar-Politicas.ps1        # politica de senha e GPOs
```
Depois, ingresse a estacao no dominio e faca logon com um dos usuarios.

### 3. Rotinas de N1
```powershell
. .\ad\04-Rotinas-N1.ps1
Get-StatusUsuario -Login ana.souza
Unlock-ContaUsuario -Login ana.souza -Chamado 1001
Reset-SenhaUsuario -Login ana.souza -Chamado 1002
Add-UsuarioGrupo -Login bruno.lima -Grupo GG_Comercial -Chamado 1003
Disable-UsuarioDesligado -Login diego.rocha -Chamado 1004
```
Cada acao fica registrada em `ad/log-atendimentos.csv`.

### 4. Scripts da estacao
```powershell
.\scripts\Inventario-Maquina.ps1
.\scripts\Diagnostico-Rede.ps1
.\scripts\Limpeza-Temporarios.ps1 -WhatIf
```

### 5. GLPI
Ver [glpi/ROTEIRO.md](glpi/ROTEIRO.md).

## Evidencias

Prints do ambiente funcionando ficam em [docs/evidencias](docs/evidencias).

## Validacao automatica

A cada push o GitHub Actions roda o PSScriptAnalyzer nos scripts PowerShell e valida o `docker-compose.yml` do GLPI.

## Autor

Matheus Ansel - [LinkedIn](https://www.linkedin.com/in/matheusansel) - [GitHub](https://github.com/MatheusAnsel) - [Portfolio](https://matheusansel.pages.dev)
