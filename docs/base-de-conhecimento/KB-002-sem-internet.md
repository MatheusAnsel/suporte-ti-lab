# KB-002 - Usuario sem internet ou sem acesso a sistema

**Categoria:** Rede | **Prioridade tipica:** P3 (um usuario) ou P1/P2 (setor inteiro) | **Nivel:** N1

## Primeira pergunta
So este computador ou o setor todo? Se varios usuarios relatam ao mesmo tempo, abrir como incidente de impacto alto e acionar o N2 imediatamente.

## Diagnostico
```powershell
.\scripts\Diagnostico-Rede.ps1
# para sistema interno:
.\scripts\Diagnostico-Rede.ps1 -Destino <servidor> -Porta <porta>
```
O script para na primeira camada que falhar e indica o que verificar.

| Falha em | Causa provavel | Acao do N1 |
|---|---|---|
| Adaptador | Cabo solto, Wi-Fi desligado, driver | Reconectar cabo, ativar Wi-Fi, reinstalar driver |
| Endereco IP (169.254.x.x) | DHCP nao respondeu | `ipconfig /release` e `ipconfig /renew`; se persistir, escalar |
| Gateway | Switch, roteador ou VLAN | Testar outra porta/cabo; escalar para N2 com o relatorio |
| DNS | Servidor DNS errado ou fora | `ipconfig /flushdns`; conferir DNS configurado |
| Internet (443) | Proxy, firewall, link | Verificar proxy no navegador; escalar se for geral |

## Ao escalar
Anexar o TXT gerado pelo script ao chamado.
