# KB-003 - Computador lento

**Categoria:** Hardware / Software | **Prioridade tipica:** P4 | **Nivel:** N1

## Coleta inicial
```powershell
.\scripts\Inventario-Maquina.ps1
```
Anexar o HTML ao chamado. Observar memoria, espaco livre em disco e ultimo boot.

## Verificacoes em ordem
1. **Ultimo boot ha muitos dias**: reiniciar resolve boa parte dos casos.
2. **Disco com menos de 10% livre**: rodar a limpeza.
   ```powershell
   .\scripts\Limpeza-Temporarios.ps1 -WhatIf   # simula
   .\scripts\Limpeza-Temporarios.ps1           # executa
   ```
3. **Gerenciador de Tarefas**: processo usando CPU, memoria ou disco perto de 100%.
4. **Inicializacao** (Gerenciador de Tarefas > Inicializar): desativar programas desnecessarios.
5. **Antivirus**: executar verificacao completa.
6. **Atualizacoes do Windows** pendentes.

## Quando escalar ou propor troca
- Memoria abaixo de 8 GB com uso constante acima de 90%.
- Disco HD mecanico com uso de 100%: recomendar troca por SSD.
- Erros de disco (SMART) ou travamentos com tela azul: escalar para N2.
