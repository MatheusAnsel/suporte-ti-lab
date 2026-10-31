# Roteiro do GLPI no laboratorio

## Subir

```bash
cd glpi
cp .env.example .env
docker compose up -d
```

Acesse `http://localhost:8080`. Usuarios padrao do GLPI: `glpi`, `tech`, `normal` e `post-only` (a senha de cada um e igual ao login). Troque as quatro senhas logo no primeiro acesso, em Administracao > Usuarios, e apague a pasta `install` se o GLPI pedir.

## O que configurar (e registrar com print em `docs/evidencias/`)

1. **Categorias de chamado**: Hardware, Software, Rede, Acesso e Senha, Impressao, E-mail.
2. **SLA** (Configurar > Niveis de servico): crie os SLAs de tempo de atendimento e de solucao seguindo a matriz de `docs/fluxo-de-atendimento.md`.
3. **Grupos tecnicos**: N1 - Service Desk e N2 - Infraestrutura, com o usuario `tech` no N1.
4. **Ativos**: cadastre 3 computadores usando os dados do `Inventario-Maquina.ps1` (fabricante, modelo, numero de serie, memoria, SO).
5. **Base de conhecimento**: cadastre os artigos de `docs/base-de-conhecimento/`.
6. **Simulacao de atendimento**: abra 5 chamados como usuario `post-only` (um de cada categoria), atenda como `tech`, escale um para o N2, resolva os demais e vincule cada solucao ao artigo da base de conhecimento.
7. **Painel**: tire print do painel de chamados mostrando status e SLA.

## Parar

```bash
docker compose down        # mantem os dados
docker compose down -v     # e apague a pasta storage para zerar
```
