# 06 · "00 Timer"

[← anterior](05-diagnostico-tela-preta-ram.md) · [← voltar](../../README.pt-BR.md) · [detalhes do aviso e tela cheia: 06-1 →](06-1timer.md)

## O que é

Um falso jogo ("00 Timer", "zz Timer calibrar") que aparece nas listas dos consoles (NES, GBA etc.) e funciona como cronômetro: você escolhe o tempo, volta ao menu, joga, e no fim o aviso "TEMPO ACABOU" aparece por cima do jogo e o stick fala "o tempo acabou". O timer vale para o stick inteiro, não para um console só.

Capas do timer (geradas por IA pelo autor): `assets/timer_covers/` (`gba.png`, `gb.png`, `gbc.png`, `fc.png`, `sfc.png`, `md.png`, `n64.png`, `ps1.png`, `atari.png`, `cps.png`). Pela hipótese do capítulo 02, basta nomear a capa igual ao "jogo" falso, na pasta do console.

## Scripts no aparelho

Em `scripts/timer/`:

- **`hook.sh`** (versão do timer, "update 3", sem alterações): se o jogo não tem "Timer" no nome, grava `$1 $2` em `/tmp/gtimer.game` e sai com `exit 1`. Se tem, copia `timer/gtimer` para `/tmp`, dá `chmod +x`, roda (`cal` quando o nome tem "calibrar") com uma morte de segurança de 150 s, e registra `fim rc=...` no `hook.log`.
- **`run.sh <uptime_final>`** (**versão final**, detalhes no [06-1](06-1timer.md)): dorme em passos de até 20 s até o `uptime` chegar ao instante final; **congela o RetroArch** (`kill -STOP`) **antes** de iniciar o `gtimer alarm`; grava a duração (`DUR=15`) em `timer/aviso.txt`; toca `timer/v/acabou.wav` duas vezes; escuta todos os `/dev/input/event*` com `evtest` e **mata o `gtimer` com qualquer botão**; no fim (ou em qualquer erro, via `trap`) **retoma o jogo** (`kill -CONT`). Ajustes no topo do arquivo: `DUR` e `PAUSAR`. A versão anterior (dorme, `gtimer alarm`, `aplay` duas vezes) está no histórico do git.
- **`gtimer`**: binário ARM (ELF) de ~400 KB, **sem fonte e não incluído** aqui. Pelas strings e pela desmontagem **[medido]**: aceita `alarm` (desenha o aviso), `cal` (calibração de botões), `test`, ou nenhum argumento (tela para definir os minutos). Ele **não abre nenhum dispositivo de entrada** (os botões são tratados pelo `run.sh` com `evtest`) e lê a duração do aviso de `/sdcard/timer/aviso.txt` (1 a 3599 s; 30 s sem o arquivo). Quem chama o `run.sh` é provavelmente o `gtimer` **[inferido]**.

### ⚠️ Conflito a resolver antes de instalar o `hook.sh`

O `hook.sh` desta pasta é a **versão do timer**. A versão usada nos jogos de GBA (cap. 04) abre o RetroArch com `gbx_mod.cfg` via `ra_wrap.sh`. Para jogos que não são Timer, a versão "update 3" faz `exit 1`, o que **provavelmente devolve o lançamento ao caminho padrão do stick, sem o `gbx_mod.cfg`** (perderia o avanço rápido) **[inferido]**. Faça backup do `hook.sh` atual e **una as duas versões** (o ramo "Timer" daqui + o ramo GBA de lá) antes de copiar. O `hook.sh` de GBA será adicionado ao repositório depois. (O `run.sh` não tem esse problema: pode ser copiado sozinho.)

## O aviso piscava: corrigido

**[inferido pelo código e pelo log, confirmado na prática]** O `gtimer` desenha no buffer de vídeo (DRM) que está na tela **no instante em que ele começa** e recopia a caixa a cada 30 ms. O RetroArch alterna entre dois buffers, então a caixa só aparecia nos quadros em que o buffer escolhido pelo `gtimer` era o exibido: esse era o pisca-pisca. A correção é congelar o RetroArch **antes** de iniciar o `gtimer`, para o buffer visível ficar parado. Depois da mudança o aviso parou de piscar.

- O teste antigo com `kill -STOP` "piorou" (jogo travou ~25 s, `dtick=0`, sem som). Esse congelamento agora é o comportamento **desejado**: o jogo fica pausado durante o aviso e o `trap` garante que ele seja retomado **[inferido]** (o teste antigo não tinha retomada controlada nem botão para fechar).
- A reescrita com `evtest` (qualquer botão fecha o aviso) agora está aplicada.
- Efeitos colaterais conhecidos (estalo de áudio ao retomar, botão apertado durante a pausa chegando ao jogo, `killall aplay`): veja o [06-1](06-1timer.md), seção 8.

## Timer dentro da lista do arcade: desistimos

No arcade, o menu só mostra o que está em `tbl_game` do `games.db` (36 jogos, `gameid` 1–36; arcade: `mslug`=1, `kof97`=2, arquivos em `game/cps/`). Na pasta há `kof97.fs` (424 B) e `mslug.fs` (480 B), de 1979, cuja função **não sabemos**.

| Tentativa | O que mudou | Resultado |
|---|---|---|
| 1 | Linha nova com `gameid` 900 **e** um `00 Timer.zip` falso (na verdade ROM de GBA) | Menu travou; duas mudanças juntas, causa indeterminada |
| 2 | Só o banco: `gameid` 37, linha copiada do `kof97`, nomes em `tbl_zh/en/tw/ko`; sem `.zip` | Travou de novo na tela de loading |

Um `00 Timer.fs` vazio (0 B, criado por nós) estava na pasta; é improvável que derrube o menu, então a linha no banco é a causa mais provável (não é prova). Palpite não confirmado: o menu usa o `gameid` como posição numa lista fixa.

**Decisão:** usar o timer pelos outros consoles. O cartão foi restaurado do `games.db.bak` e limpo (banco com os 36 jogos, sem linha do timer, `.fs` vazio apagado).

Se um dia tentar de novo, só com o cartão ligado ao PC e o `games.db.bak` à mão:

```bash
S=/run/media/user/<LABEL>; DB=$S/game/games.db
cp -n "$DB" "$DB.bak"                  # backup ANTES de qualquer alteração
# restaurar:
cp "$DB.bak" "$DB" && sync
# conferir:
sqlite3 -readonly "$DB" "select count(*) from tbl_game; select count(*) from tbl_game where game='00 Timer';"   # 36 e 0
```

### Como usar o timer com o arcade

1. Abra "00 Timer" no NES, GBA etc. e escolha o tempo.
2. Volte ao menu e abra `mslug` ou `kof97`.
3. No fim, o aviso deve aparecer por cima do jogo e o stick falar "o tempo acabou".

**[pendente]** Só foi verificado por cima de um jogo de GBA. No arcade deve funcionar igual (o aviso é desenhado na tela, e o `run.sh` congela qualquer processo `retroarch` em execução), mas é só hipótese.
