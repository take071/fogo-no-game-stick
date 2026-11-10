# Registro de Correção e Configuração: Mod "Fogo no Game Stick" (Timer)

Este documento registra todas as etapas de diagnóstico, a verdadeira causa dos problemas encontrados e o passo a passo para corrigir o mod de Timer (`fogo-no-game-stick` por take071) no Game Stick.

---

## 🛑 O Verdadeiro Motivo do Erro: Por que o Timer abria e fechava?

Muitos usuários podem achar que a falta de memória virtual (Swap) causa esse travamento, mas **o Swap não teve relação com o fechamento instantâneo do timer**. O erro foi causado por dois problemas específicos na manipulação dos scripts:

1. **O Script `hook.sh` foi sobrescrito:** Ao tentar instalar um script de monitoramento de memória (`diag_swap.sh`), o arquivo `hook.sh` original do timer foi apagado e substituído. Em vez de carregar a tela visual do timer, o arquivo passou a ter apenas um comando que rodava o diagnóstico e terminava abruptamente com `exit 1`. O sistema do Game Stick lia isso e fechava a tela no mesmo milissegundo.
2. **Caracteres Invisíveis do Windows (CRLF):** Se os scripts `.sh` forem editados, copiados ou salvos em um ambiente Windows antes de irem para o cartão, eles ganham caracteres invisíveis de quebra de linha (`\r`). O sistema Linux enxuto do Game Stick não entende essa formatação e aborta a execução do arquivo imediatamente, causando um "crash" silencioso.

*(Nota sobre o Swap: Embora não cause o erro do timer, a análise revelou que o Game Stick opera com 0 KB de Swap e a memória RAM despenca para quase 6 MB livres durante os jogos. Isso explica por que jogos muito pesados podem fechar sozinhos no meio da partida).*

---

## 🛠️ Como Resolver (Passo a Passo da Correção)

Para consertar o fechamento instantâneo e restaurar a interface visual, conecte o cartão SD em um PC com Linux (ou via WSL) e rode os comandos abaixo no terminal, apontando para a partição principal do Game Stick (ex: `/run/media/usuario/SD_CARD`).

### Passo 1: Recriar o script gráfico do Timer (`hook.sh`)
Este comando restaura o arquivo com a lógica correta que desenha a interface na tela:

```bash
cat << 'EOF' > /caminho/do/cartao/timer/hook.sh
#!/bin/sh
LOG=/sdcard/timer/hook.log
echo "hook $1 $2 $3" >> $LOG
NAME="${3##*/}"
case "$NAME" in
  *"Timer"*) echo "$1 $2" > /tmp/gtimer.self ;;
  *) echo "$1 $2" > /tmp/gtimer.game; exit 1 ;;
esac
P0=$(pidof gtimer); [ -n "$P0" ] && { kill $P0 2>/dev/null; sleep 1; }
rm -f /tmp/gtimer
cp /sdcard/timer/gtimer /tmp/gtimer 2>>$LOG
chmod +x /tmp/gtimer 2>>$LOG
echo "rodando" >> $LOG; sync
case "$NAME" in *"calibrar"*) ARG=cal ;; *) ARG= ;; esac
/tmp/gtimer $ARG 2>>$LOG &
P=$!
( sleep 150; kill -9 $P 2>/dev/null ) &
W=$!
wait $P
RC=$?
kill $W 2>/dev/null
echo "fim rc=$RC" >> $LOG; sync
exit 0
EOF
```

### Passo 2: Limpar a formatação do Windows
Remova qualquer caractere `\r` invisível que faça o sistema abortar:

```bash
sed -i 's/\r//g' /caminho/do/cartao/timer/hook.sh
chmod +x /caminho/do/cartao/timer/hook.sh
```

### Passo 3: Criar a regra inteligente de inicialização
Edite o arquivo `/start_game.sh` na raiz do cartão. Apague a chamada antiga do RetroArch no final do arquivo e substitua por esta linha contínua:

```bash
sh /sdcard/timer/hook.sh "$1" "$2" "$3" || /usr/bin/retroarch -y "12" -c /sdcard/gbx66.cfg -L /sdcard/retro_lib/$GAME_LIB "$3"
```
*Lógica: Ele tenta rodar o Timer. Se o jogo não for o Timer, o script do Passo 1 falha (`exit 1`), ativando a segunda metade do comando (`||`) que abre o jogo normal no RetroArch.*

---

## ⚙️ Outras Melhorias Aplicadas

Além da correção principal acima, os seguintes ajustes foram feitos no sistema (verifique os backups `.bak` no cartão caso queira reverter):

* **Fim do Pisca-Pisca do Aviso:** O arquivo `/timer/run.sh` foi editado para disparar um `kill -STOP` no RetroArch *antes* de abrir a tela de "TEMPO ACABOU". Isso congela o buffer de vídeo e deixa o aviso estático na tela.
* **Fechamento do Alerta com Botões:** Adicionado um laço com `evtest` no `/timer/run.sh` permitindo que o jogador aperte qualquer botão para fechar a mensagem de tempo esgotado sem ter que esperar 15 segundos.
* **Tela Cheia (16:9) Forçada:** Alteramos `aspect_ratio_index` para `"1"` nos arquivos `gbx66.cfg`, `gbx_mod.cfg` e `cfg_interno.cfg` para remover as bordas pretas nos jogos.