# 06 – O "00 Timer": alerta fixo, jogo pausado e tela cheia

Aqui eu registro o que mudei no cartão (sistema Linux com RetroArch) para:

1. Mostrar o aviso **"TEMPO ACABOU"** fixo por **15 s**, sem piscar.
2. **Pausar o jogo** enquanto o aviso aparece e **retomar** sozinho depois.
3. Deixar o jogador **fechar o aviso com qualquer botão**.
4. Fazer os jogos rodarem em **tela cheia**.

Foi tudo feito editando scripts e configs do cartão. **Não mexi no binário `gtimer`.**

> ⚠️ Testei no meu aparelho. Em outro aparelho, versão de RetroArch ou cartão, caminhos e comportamento podem mudar. Faça backup antes.

---

## 1. Convenções

Comandos rodam **no PC**, com o cartão montado. Defina uma vez no terminal:

```bash
CARTAO=/caminho/do/cartao      # ex.: /run/media/SEU_USUARIO/NOME_DO_CARTAO
T=$CARTAO/timer
[ -d "$T" ] || echo "AVISO: pasta timer não encontrada, confira o caminho"
```

Dentro do aparelho o cartão aparece como `/sdcard`, por isso os scripts usam `/sdcard/timer/...`.

---

## 2. Como o timer funciona

| Arquivo (`timer/`) | Para quê |
|---|---|
| `gtimer` | Programa compilado (ARM 32 bits). Desenha as telas direto no vídeo e fala os números |
| `hook.sh` | O sistema chama quando um jogo abre. Se for o "Timer", roda o `gtimer` |
| `run.sh` | Espera o tempo acabar e dispara o alerta (`gtimer alarm`) e o som. **É o que eu alterei** |
| `ra_wrap.sh` | Envolve o RetroArch nos jogos de GBA (coleta de diagnóstico). Não alterei |
| `v/acabou.wav` | Voz avisando que o tempo acabou |
| `gtimer.log` | Log do `gtimer` e do `run.sh` |
| `aviso.txt` | Duração do alerta em segundos (criado pelo `run.sh`) |

Modos do `gtimer`, que levantei lendo o binário (strings e desmontagem) **[inferido]**:

| Argumento | O que faz |
|---|---|
| *(nenhum)* | Tela normal para escolher os minutos |
| `alarm` | Desenha o aviso "TEMPO ACABOU" |
| `cal` | Calibração de botões (provavelmente as telas de teste das fotos [10](../fotos/10-teste-tela-controle-103.jpg) e [11](../fotos/11-teste-tela-controle-48.jpg)) |
| `test` | Modo de teste |

Por isso o `alarm` **não** pode sair do `run.sh`: sem ele aparece a tela de minutos em vez do aviso.

Fluxo: eu agendo o tempo no jogo "Timer" ([foto 07](../fotos/07-timer-01-10.jpg)) → o `gtimer` inicia o `run.sh` com o horário final (segundos de uptime) → o `run.sh` dorme até lá → **congela o RetroArch**, abre `gtimer alarm`, toca o som e escuta os botões → o aviso termina em 15 s ou ao apertar um botão → o jogo é retomado.

---

## 3. Por que o aviso piscava

O `gtimer` desenha no buffer de vídeo (DRM) que está na tela **no instante em que ele começa** e recopia a caixa a cada 30 ms. O RetroArch alterna entre dois buffers, então a caixa só aparecia nos quadros em que o buffer escolhido era o exibido. Isso era o pisca-pisca.

A versão antiga congelava o jogo 1 s **depois** de abrir o `gtimer`, tarde demais. A correção foi congelar o RetroArch **antes** de abrir o `gtimer`: o buffer visível fica parado e a caixa fica firme. Isso é uma dedução a partir do código e do log, e **confirmei na prática**: depois da mudança, parou de piscar.

> **Sobre a minha tentativa anterior com `kill -STOP`:** eu tinha registrado que ela "piorou" (jogo travado ~25 s, sem som). O defeito era a ordem (congelar depois do `gtimer`) e a falta de um `kill -CONT` garantido. O `trap` do script novo resolve isso.

A duração vem de `/sdcard/timer/aviso.txt` (inteiro de 1 a 3599). Sem o arquivo, o padrão é 30 s.

---

## 4. O `run.sh` final

Está pronto em [`scripts/timer/run.sh`](../../scripts/timer/run.sh) (o original ficou em `run_original.sh`). Configurações no topo:

- `DUR=15`: segundos do aviso na tela.
- `PAUSAR=1`: congela o jogo antes de desenhar. **Com `0` o aviso volta a piscar.**

Para instalar no cartão:

```bash
cp "$T/run.sh" "$T/run.sh.bak"           # guarde o seu antes
cp scripts/timer/run.sh "$T/run.sh"
sed -i 's/\r//g' "$T/run.sh"
sync
```

### O que cada parte faz

- **Espera:** dorme em blocos de até 20 s até o horário final.
- **`RP`:** pega o PID do RetroArch. Se não estiver rodando (eu estou no próprio Timer), pula a pausa.
- **`cleanup` + `trap`:** em **qualquer** saída (normal, erro, interrupção) o jogo é retomado (`kill -CONT`) e `gtimer`, som e `evtest` são parados. Isso evita deixar o jogo congelado por acidente.
- **`kill -STOP` antes do `gtimer`:** é a correção do pisca-pisca.
- **Botões:** um `evtest` por dispositivo de entrada. Qualquer `EV_KEY value 1` mata o `gtimer`. O `sleep 1` antes evita que um botão já apertado feche o aviso na hora.
- **`alive`:** verifica se o `gtimer` ainda roda, ignorando processos zumbis (sem isso o jogo podia ficar pausado alguns segundos a mais).
- **Limite de segurança:** se o `gtimer` não terminar, o script o mata depois de `DUR + 3` s.

### Conferir depois de um teste

```bash
tail -5 "$T/gtimer.log"
```

Deve terminar com algo como:

```
aviso: fim do tempo, fica 15 s
fim aviso
run.sh: fim aviso
```

Se aparecer `retroarch pid=nenhum`, a pausa não funcionou e o pisca-pisca pode voltar.

---

## 5. Tela cheia

Os jogos (exceto GBA) usam o `gbx66.cfg` da raiz do cartão. Os de GBA usam `timer/gbx_mod.cfg`, e existe também `timer/cfg_interno.cfg`. Nos três, `aspect_ratio_index` era `18`. A saída do aparelho é 1280x720 e o índice `1` é 16:9 no RetroArch.

```bash
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do
  sed -i 's/^\(aspect_ratio_index = \)"[0-9]*"/\1"1"/' "$f"
  grep '^aspect_ratio_index' "$f"
done
sync
```

Desfazer (volta ao `18`): rode o mesmo laço trocando `"1"` por `"18"`.

> **Atenção, uma dúvida minha:** descobri depois que o stick usa o `gbx66.cfg` **interno** (`/usr/local/share/minigui/gbx66.cfg`) nos jogos que não passam pelo `gbx_mod.cfg` (ver [doc 04](04-pokemon-fastforward.md)). Então a mudança no `gbx66.cfg` do cartão pode **não ter efeito** fora do GBA. Para esses consoles, a tela cheia provavelmente exige o mesmo patch no squashfs dos saves **[pendente]**. Jogos 4:3 (PS1, NES, SNES...) ficam esticados na horizontal em 16:9.

---

## 6. Por que o Timer abria e fechava na hora (e como consertei)

Achei que fosse falta de swap. **Não era.** Foram dois problemas meus:

1. **Sobrescrevi o `hook.sh`.** Ao instalar um script de diagnóstico de memória, apaguei o `hook.sh` do timer e coloquei um que só rodava o diagnóstico e fazia `exit 1`. O sistema lia aquilo e fechava a tela no mesmo instante. A cópia restaurada está em [`scripts/timer/hook_timer_restaurado.sh`](../../scripts/timer/hook_timer_restaurado.sh).
2. **Quebras de linha do Windows (`\r`).** Scripts editados no Windows ganham `\r`, que o Linux enxuto do stick não entende, e o script aborta em silêncio. Conserto: `sed -i 's/\r//g' timer/hook.sh && chmod +x timer/hook.sh`.

(O stick opera com 0 KB de swap e cai para ~6 MB de `MemFree` em jogo pesado, mas isso é outro assunto; veja o [doc 05](05-diagnosis-black-screen-ram.md).)

Esse `hook.sh` do timer decide: se o nome do jogo contém "Timer", roda o `gtimer`; senão faz `exit 1` e deixa o fluxo abrir o jogo normal. **Ele é a versão só do timer;** a versão que também abre os jogos de GBA com o `ra_wrap.sh` ainda preciso juntar **[pendente]**.

> **Dúvida minha:** o registro antigo mandava editar o `/start_game.sh` da raiz do cartão com `sh hook.sh ... || retroarch ...`. Como o stick usa o `start_game.sh` interno (que já chama o hook), eu **não considero esse passo confirmado**. Só use se o seu aparelho realmente ler o da raiz.

---

## 7. Timer no arcade: tentei e larguei

O Timer funciona nos consoles em que basta um arquivo falso na pasta (NES, GBA etc.). No arcade o menu só mostra o que está em `tbl_game` do `games.db` (36 jogos, `gameid` 1 a 36).

- **Tentativa 1:** linha com `gameid` 900 + `00 Timer.zip` falso na pasta do arcade. O menu travou. Mudei duas coisas juntas, então não sei qual causou.
- **Tentativa 2:** só o banco, `gameid` 37, linha copiada do `kof97` e nomes em `tbl_zh/en/tw/ko`. O menu travou de novo na tela de loading. Um `00 Timer.fs` vazio ainda estava na pasta (improvável que derrube o menu, mas não é prova).
- **Decisão:** larguei. Restaurei o `games.db` do `.bak` (`cp "$DB.bak" "$DB"`), apaguei o `.fs` vazio e conferi: 36 jogos, 0 linhas do timer. O `games.db.bak` continua no cartão.
- **Palpite não confirmado:** o menu usa o `gameid` como posição numa lista fixa. Também não sei o que são os `.fs` de fábrica (`kof97.fs`, `mslug.fs`).

**Como uso o timer com o arcade:** abro o "00 Timer" na lista de NES/GBA, escolho o tempo, volto e abro um jogo de arcade (`mslug` ou `kof97`). O aviso deve aparecer por cima, porque é desenhado na tela. **Só testei por cima de GBA** (fotos [08](../fotos/08-tempo-acabou-azul.jpg) e [12](../fotos/12-tempo-acabou-arroxeado.jpg)) **[pendente]**.

---

## 8. Backup e restauração

```bash
cp "$T/run.sh" "$T/run.sh.bak"
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do cp "$f" "$f.bak"; done
# restaurar:
cp "$T/run.sh.bak" "$T/run.sh"
for f in "$CARTAO/gbx66.cfg" "$T/gbx_mod.cfg" "$T/cfg_interno.cfg"; do cp "$f.bak" "$f"; done
sync
```

---

## 9. Comandos só de leitura

```bash
find "$CARTAO" -type f \( -iname '*timer*' -o -iname '*.sh' \) 2>/dev/null | head -40
strings -n 4 "$T/gtimer" | grep -i -E "alarm|normal|cal|test|aviso|fica"
grep -E '^(aspect_ratio_index|video_scale_integer|video_force_aspect|custom_viewport|video_fullscreen)' "$CARTAO/gbx66.cfg"
tail -40 "$T/gtimer.log"
```

---

## 10. Problemas conhecidos

- **Estalo de áudio** quando o jogo retoma da pausa.
- **Um botão apertado durante a pausa** pode chegar ao jogo na retomada.
- **`killall aplay`** no `cleanup` também para qualquer outro `aplay` que esteja rodando.
- **`sleep 0.3`** pode não ser aceito em todo aparelho; o script cai para 1 s.
- **Jogos 4:3 esticados** em 16:9.
- Se algum sistema ainda mostra bordas pretas, pode haver config por núcleo ou por jogo dentro do aparelho (fora do cartão).
- Se o aviso voltar a piscar, confira no log se `run.sh: retroarch pid=...` tem um número (e não `nenhum`).

## 11. Resumo das mudanças

| Item | Arquivo | Mudança |
|---|---|---|
| Aviso de 15 s | `timer/run.sh` + `timer/aviso.txt` | `DUR=15`, gravado em `aviso.txt` |
| Jogo pausa no aviso | `timer/run.sh` | `kill -STOP` no RetroArch e `kill -CONT` no fim |
| Sem pisca-pisca | `timer/run.sh` | Congela **antes** de iniciar o `gtimer` |
| Botão fecha o aviso | `timer/run.sh` | `evtest` mantido; o som também para |
| Retomada garantida | `timer/run.sh` | `trap` com `cleanup` |
| Tela cheia | `gbx66.cfg`, `timer/gbx_mod.cfg`, `timer/cfg_interno.cfg` | `aspect_ratio_index` de `18` para `1` |
