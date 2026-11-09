# Timer do console: aviso "TEMPO ACABOU" fixo por 15 s + tela cheia

Este documento registra o que foi alterado no cartão do console (sistema Linux com RetroArch) para:

1. Mostrar o aviso **"TEMPO ACABOU"** fixo na tela por **15 segundos**, sem piscar.
2. **Pausar o jogo** enquanto o aviso aparece e **retomar** sozinho depois.
3. Permitir **fechar o aviso com qualquer botão do controle**.
4. Colocar os jogos em **tela cheia**.

Tudo foi feito editando scripts e arquivos de configuração no cartão. O binário `gtimer` **não foi alterado**.

> **Aviso:** as alterações foram feitas e testadas no aparelho do autor. Em outro aparelho, versão de RetroArch ou cartão, os caminhos e o comportamento podem ser diferentes. Faça backup antes de aplicar.

---

## 1. Convenções usadas neste documento

Os comandos rodam **no PC**, com o cartão montado. Defina uma vez no terminal:

```bash
CARTAO=/caminho/do/cartao      # ponto de montagem do cartão (ex.: /run/media/SEU_USUARIO/NOME_DO_CARTAO)
T=$CARTAO/timer
[ -d "$T" ] || echo "ATENCAO: pasta timer nao encontrada, confira o caminho do cartao"
```

Dentro do aparelho, o cartão aparece como `/sdcard`. Por isso os scripts usam `/sdcard/timer/...`.

---

## 2. Como o sistema funciona

### Estrutura (pasta `timer/`)

| Arquivo | Função |
|---|---|
| `gtimer` | Programa compilado (ARM 32 bits). Desenha as telas do timer direto na tela e fala os números. |
| `hook.sh` | Chamado pelo sistema ao abrir um jogo. Se o jogo é o "Timer", roda o `gtimer` no modo normal. |
| `run.sh` | Espera o fim do tempo e dispara o aviso (`gtimer alarm`) e o som. **É o arquivo alterado.** |
| `ra_wrap.sh` | Envolve o RetroArch em alguns sistemas (coleta de diagnóstico). Não foi alterado. |
| `v/acabou.wav` | Voz que diz que o tempo acabou. |
| `gtimer.log` | Log do `gtimer` e do `run.sh`. Útil para depurar. |
| `aviso.txt` | Duração do aviso, em segundos. Criado pelo `run.sh`. |

Na raiz do cartão, `start_game.sh` escolhe o núcleo do RetroArch por sistema, e `gbx66.cfg` é a configuração de vídeo dos jogos.

### Fluxo do aviso

1. Você agenda o timer no "jogo" Timer. O `gtimer` inicia o `run.sh` passando o horário de término (em segundos de uptime).
2. O `run.sh` dorme até esse horário.
3. No fim, ele **congela o RetroArch**, abre `gtimer alarm`, toca o som e escuta os botões.
4. O aviso termina quando passam 15 s **ou** quando um botão é apertado. Aí o jogo é retomado.

### Modos do `gtimer`

Lendo o binário (strings e desmontagem), o `gtimer` aceita estes argumentos:

| Argumento | O que faz |
|---|---|
| *(nenhum)* | Tela normal de ajuste de minutos. |
| `alarm` | Desenha o aviso "TEMPO ACABOU". |
| `cal` | Calibração dos botões. |
| `test` | Modo de teste. |

Por isso **não** se deve tirar o `alarm` do `run.sh`: sem ele aparece a tela de ajuste em vez do aviso.

---

## 3. Por que o aviso piscava

O `gtimer` desenha no buffer de vídeo (DRM) que está na tela **no instante em que ele abre**, e recopia a caixa a cada 30 ms. O RetroArch alterna entre dois buffers. A caixa só aparecia nos quadros em que o buffer escolhido estava na tela, e isso era o piscar.

A versão anterior congelava o jogo 1 s **depois** de abrir o `gtimer`, tarde demais. A correção foi congelar o RetroArch **antes** de abrir o `gtimer`. Assim o buffer visível fica parado e a caixa aparece fixa.

> Isto é uma dedução feita a partir do código e do log, e foi confirmada na prática: após a mudança o aviso parou de piscar.

A duração do aviso vem do arquivo `/sdcard/timer/aviso.txt`: um número inteiro de segundos, de 1 a 3599. Sem o arquivo, o padrão é 30 s.

---

## 4. O `run.sh` final

Substitui o `run.sh` do cartão. Configurações no topo:

- `DUR=15`: segundos de aviso.
- `PAUSAR=1`: congela o jogo antes de desenhar. **Com `0` o aviso volta a piscar.**

```bash
cat > "$T/run.sh" <<'EOF'
#!/bin/sh
END=$1
DUR=15      # segundos com o aviso na tela
PAUSAR=1    # 1 = congela o jogo antes de desenhar o aviso (evita piscar)
LOG=/sdcard/timer/gtimer.log
echo $$ > /tmp/gtimer.pid
while :; do
  read UP _ < /proc/uptime; UP=${UP%.*}
  LEFT=$((END - UP))
  [ "$LEFT" -le 0 ] && break
  [ "$LEFT" -gt 20 ] && sleep 20 || sleep "$LEFT"
done
rm -f /tmp/gtimer.pid
[ -x /tmp/gtimer ] || { cp /sdcard/timer/gtimer /tmp/gtimer; chmod +x /tmp/gtimer; }

RP=$(pidof retroarch | awk '{print $1}')
GP=; AP=
cleanup() {
  [ -n "$RP" ] && kill -CONT $RP 2>/dev/null
  [ -n "$GP" ] && kill $GP 2>/dev/null
  [ -n "$AP" ] && kill $AP 2>/dev/null
  killall aplay 2>/dev/null
  killall evtest 2>/dev/null
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

# 1) congela o jogo ANTES de abrir o gtimer
if [ "$PAUSAR" = 1 ] && [ -n "$RP" ]; then
  kill -STOP $RP 2>/dev/null
  sleep 0.3 2>/dev/null || sleep 1
fi
echo "run.sh: retroarch pid=${RP:-nenhum} pausar=$PAUSAR dur=$DUR" >> $LOG

# 2) duracao do aviso (o gtimer le este arquivo)
echo "$DUR" > /sdcard/timer/aviso.txt

/tmp/gtimer alarm >/dev/null 2>&1 &
GP=$!
( aplay -q /sdcard/timer/v/acabou.wav; sleep 4; aplay -q /sdcard/timer/v/acabou.wav ) &
AP=$!
read T0 _ < /proc/uptime; T0=${T0%.*}
sleep 1
for d in /dev/input/event*; do
  ( evtest $d 2>/dev/null | while read l; do
      case "$l" in *"type 1 (EV_KEY)"*"value 1"*) kill $GP 2>/dev/null; break ;; esac
    done ) &
done

alive() { ST=$(cut -d' ' -f3 /proc/$GP/stat 2>/dev/null); [ -n "$ST" ] && [ "$ST" != Z ] && [ "$ST" != X ]; }
while alive; do
  read T1 _ < /proc/uptime; T1=${T1%.*}
  [ $((T1 - T0)) -ge $((DUR + 3)) ] && break
  sleep 0.5 2>/dev/null || sleep 1
done
echo "run.sh: fim aviso" >> $LOG
exit 0
EOF
sync
```

### O que cada parte faz

- **Espera:** o primeiro laço dorme em blocos de até 20 s até o horário de término.
- **`RP`:** pega o PID do RetroArch. Se não houver RetroArch (você está no próprio Timer), a pausa é ignorada.
- **`cleanup` + `trap`:** em **qualquer** saída (fim normal, erro, interrupção) o jogo é retomado (`kill -CONT`), e `gtimer`, som e `evtest` são encerrados. Isso evita o jogo ficar travado por acidente.
- **`kill -STOP` antes do `gtimer`:** é a correção do piscar.
- **Botões:** um `evtest` por dispositivo de entrada. Ao detectar qualquer botão apertado (`EV_KEY value 1`), ele encerra o `gtimer`. O `sleep 1` antes evita que um botão já pressionado feche o aviso na hora.
- **`alive`:** verifica se o `gtimer` ainda roda, ignorando processo zumbi. Sem isso o jogo poderia ficar pausado alguns segundos a mais.
- **Limite de segurança:** se o `gtimer` não terminar, o script o derruba após `DUR + 3` segundos.

### Verificar depois de um teste

```bash
tail -5 "$T/gtimer.log"
```

Deve terminar com algo como:

```
aviso: fim do tempo, fica 15 s
fim aviso
run.sh: fim aviso
```

Se aparecer `retroarch pid=nenhum`, a pausa não pegou, e o piscar pode voltar.

---

## 5. Tela cheia

Os jogos (exceto GBA) usam `gbx66.cfg` na raiz do cartão. Os GBA usam `timer/gbx_mod.cfg`, e há também `timer/cfg_interno.cfg`. Nos três, `aspect_ratio_index` valia `18`. A saída do aparelho é 1280x720, e o índice `1` é 16:9 no RetroArch.

### Aplicar

```bash
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do
  sed -i 's/^\(aspect_ratio_index = \)"[0-9]*"/\1"1"/' "$f"
  grep '^aspect_ratio_index' "$f"
done
sync
```

O `grep` deve mostrar `aspect_ratio_index = "1"` nos três arquivos.

### Desfazer (volta ao valor original, 18)

```bash
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do
  sed -i 's/^\(aspect_ratio_index = \)"[0-9]*"/\1"18"/' "$f"
done
sync
```

> **Atenção:** jogos em 4:3 (PS1, NES, SNES etc.) ficam esticados na horizontal, porque o 16:9 preenche a tela inteira.

---

## 6. Backup e restauração

Antes de mexer, o ideal é copiar:

```bash
cp "$T/run.sh" "$T/run.sh.bak"
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do cp "$f" "$f.bak"; done
```

Para restaurar:

```bash
cp "$T/run.sh.bak" "$T/run.sh"
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do cp "$f.bak" "$f"; done
sync
```

### `run.sh` original (versão anterior às mudanças)

```bash
cat > "$T/run.sh" <<'EOF'
#!/bin/sh
END=$1
echo $$ > /tmp/gtimer.pid
while :; do
  read UP _ < /proc/uptime; UP=${UP%.*}
  LEFT=$((END - UP))
  [ "$LEFT" -le 0 ] && break
  [ "$LEFT" -gt 20 ] && sleep 20 || sleep "$LEFT"
done
rm -f /tmp/gtimer.pid
[ -x /tmp/gtimer ] || { cp /sdcard/timer/gtimer /tmp/gtimer; chmod +x /tmp/gtimer; }
/tmp/gtimer alarm >/dev/null 2>&1 &
GP=$!
sleep 1
for d in /dev/input/event*; do
  ( evtest $d 2>/dev/null | while read l; do
      case "$l" in *"type 1 (EV_KEY)"*"value 1"*) kill $GP 2>/dev/null; break ;; esac
    done ) &
done
aplay -q /sdcard/timer/v/acabou.wav
sleep 4
aplay -q /sdcard/timer/v/acabou.wav
sleep 26
killall evtest 2>/dev/null
EOF
rm -f "$T/aviso.txt"
sync
```

---

## 7. Comandos de diagnóstico (só leitura)

Localizar arquivos do timer:

```bash
find "$CARTAO" -type f \( -iname '*timer*' -o -iname '*.sh' \) 2>/dev/null | head -40
```

Ver os modos e textos do `gtimer`:

```bash
strings -n 4 "$T/gtimer" | grep -i -E "alarm|normal|cal|test|aviso|fica"
```

Ver as configurações de vídeo:

```bash
grep -E '^(aspect_ratio_index|video_scale_integer|video_force_aspect|custom_viewport|video_fullscreen)' "$CARTAO/gbx66.cfg"
```

Ver o fim do log:

```bash
tail -40 "$T/gtimer.log"
```

---

## 8. Problemas conhecidos

- **Estalo de áudio** ao retomar o jogo depois da pausa.
- **Botão apertado durante a pausa** pode chegar ao jogo quando ele volta.
- **`killall aplay`** no `cleanup` também encerra qualquer outro `aplay` em execução naquele momento.
- **`sleep 0.3`** pode não ser aceito em todos os aparelhos; o script usa 1 s como alternativa.
- **Jogos 4:3 esticados** com a tela cheia em 16:9.
- Se algum sistema ainda mostrar faixas pretas, pode haver um ajuste por núcleo ou por jogo guardado dentro do aparelho (fora do cartão).
- Se o aviso voltar a piscar, confira no log se a linha `run.sh: retroarch pid=...` mostra um número (e não `nenhum`).

---

## 9. Resumo das mudanças

| Item | Arquivo | Mudança |
|---|---|---|
| Aviso de 15 s | `timer/run.sh` + `timer/aviso.txt` | `DUR=15`, gravado em `aviso.txt` |
| Jogo pausa durante o aviso | `timer/run.sh` | `kill -STOP` no RetroArch e `kill -CONT` no fim |
| Sem piscar | `timer/run.sh` | Congela o jogo **antes** de abrir o `gtimer` |
| Botão fecha o aviso | `timer/run.sh` | `evtest` mantido; agora o som também para |
| Retomada garantida | `timer/run.sh` | `trap` com `cleanup` |
| Tela cheia | `gbx66.cfg`, `timer/gbx_mod.cfg`, `timer/cfg_interno.cfg` | `aspect_ratio_index` de `18` para `1` |
