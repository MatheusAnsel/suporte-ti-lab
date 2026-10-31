# KB-001 - Usuario esqueceu a senha ou conta bloqueada

**Categoria:** Acesso e Senha | **Prioridade tipica:** P3 | **Nivel:** N1

## Sintoma
"Senha incorreta", "sua conta foi bloqueada" ou "sua senha expirou" ao entrar no Windows.

## Antes de tudo
Confirmar a identidade do usuario (nome completo, setor e matricula ou gestor). Nunca resetar senha so com o pedido por mensagem.

## Diagnostico
```powershell
. .\ad\04-Rotinas-N1.ps1
Get-StatusUsuario -Login <login>
```
- `Bloqueado = True` e senha conhecida: so desbloquear.
- `Ativo = False`: conta desativada, verificar com o gestor (pode ser desligamento).
- Usuario nao lembra a senha: resetar.

## Solucao
```powershell
Unlock-ContaUsuario -Login <login> -Chamado <numero>
# ou
Reset-SenhaUsuario -Login <login> -Chamado <numero>
```
Passar a senha temporaria por canal seguro e orientar a troca no primeiro logon (minimo de 10 caracteres, com maiuscula, numero e simbolo).

## Se voltar a bloquear logo depois
Normalmente e uma senha antiga salva em outro lugar (celular com e-mail corporativo, unidade de rede mapeada, credencial salva no Windows). Verificar o Gerenciador de Credenciais e os dispositivos do usuario.
