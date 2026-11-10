# 04 – Batalhas de Pokémon mais rápidas

## Resultado

**Funcionou.** As batalhas ficaram mais rápidas e o resto do jogo (mapa, menus, texto fora de batalha) segue na velocidade normal.

- `fastforward_ratio` em uso: **3.0**.
- **2.5 também testei e ficou "perfeito"**: é o valor de referência se eu quiser algo mais moderado.
- Onde mudar: `timer/gbx_mod.cfg`, linha `fastforward_ratio`.

## Como o stick funciona (o que descobri)

- Ponto de montagem no PC: `/run/media/take/CD6F-EC8D`.
- Os jogos de GBA rodam no mGBA (slot 7).
- O stick **não usa** o `gbx66.cfg` nem o `start_game.sh` da raiz do cartão para esses jogos. Ele usa os internos em `/usr/local/share/minigui/`. A linha de comando real, que capturei no diagnóstico de RAM, confirma:

  ```
  /usr/bin/retroarch -y 12 -c /usr/local/share/minigui/gbx66.cfg -L /sdcard/retro_lib/mgba_libretro.so /sdcard/game/gba/Stone Dragon 3.gba
  ```

  Ou seja, os ajustes que eu fiz no `gbx66.cfg` do cartão no começo não tinham efeito.
- O `start_game.sh` interno chama `/sdcard/timer/hook.sh` antes de abrir o RetroArch. **O `hook.sh` é o meu ponto de entrada.**
- O jogo "Timer" (`00 Timer`, `zz Timer calibrar`) é um jogo falso que serve de cronômetro (`gtimer`). O `hook.sh` o trata à parte.
- Controle: ShanWan Twin USB Joystick, que manda **teclas de teclado** (Start = `KEY_ENTER`, Select = `KEY_RIGHTSHIFT`, A = `KEY_A`, B = `KEY_B`, Y = `KEY_Y`).

## Os jogos

| Jogo | Base | Observação |
|---|---|---|
| PK GS Chronicles 2.7.4 | FireRed (`BPRE`) | tem batalha |
| Stone Dragon 3 | FireRed (`BPRE`) | tem batalha |
| Pokémon Mystery Dungeon | — | não tem batalha por turnos |

## Como a solução funciona

1. O `hook.sh` identifica jogos do slot 7 (GBA) que não sejam "Timer".
2. Para eles abre o RetroArch com `-c /sdcard/timer/gbx_mod.cfg` (cópia do config interno com `fastforward_ratio` alterado), via `ra_wrap.sh`.
3. Erros vão para `timer/ra.err` e o código de saída para `hook.log`.

Eu achava que o ajuste deixaria o jogo todo mais rápido e **estava errado**: só aparece nas batalhas. **Não sei explicar por quê**; funciona, mas não investiguei a causa.

## O que larguei

| Ideia | Por quê |
|---|---|
| Ajustar o `gbx66.cfg` da raiz | O stick usa o interno |
| `tools_diag.sh` pelo `start_game.sh` do cartão | Esse arquivo não é executado |
| Botão de avanço rápido | L já tem função, Start não acelerou, `_btn` não serve para este controle |
| Avanço rápido automático por tempo | Recusei |
| Aceleração lendo a memória do jogo | Exigiria RetroArch customizado e um endereço por hack |
| Mais "desempenho" | GBA é travado a 60 fps pelo emulador |
| `fps_show` | Este build não desenha |

## Mudar a velocidade

```bash
S=$(ls -d /run/media/take/CD6F* | head -1)
sed -i 's/^fastforward_ratio = .*/fastforward_ratio = "2.500000"/' "$S/timer/gbx_mod.cfg"
grep -n '^fastforward_ratio' "$S/timer/gbx_mod.cfg"
sync
```

## Limpeza que ainda falta

- `tools_diag.sh` e a linha `sh /sdcard/tools_diag.sh` no `start_game.sh` do cartão (`cp start_game.sh.bak_diag start_game.sh`).
- `timer/diag2.sh`, `timer/ff.cfg`, `timer/snippet*.txt`, `timer/ev.event*`, `timer/ra.err`.
- Conferir o `hook.sh` com `sed -n 4,6p timer/hook.sh`: a linha do `evtest` e o `-v` devem ter saído.
- Opções dentro do jogo que cortam ainda mais tempo: Text Speed: Fast, Battle Scene: Off, Battle Style: Set.

## Desfazer tudo

```bash
S=$(ls -d /run/media/take/CD6F* | head -1)
cp "$S/timer/hook.sh.bak_diag2" "$S/timer/hook.sh"
cp "$S/start_game.sh.bak_diag" "$S/start_game.sh"
sync
```
