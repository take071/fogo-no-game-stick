# 04 · Batalhas de Pokémon mais rápidas

[← anterior](03-graficos-e-consumo.md) · [← voltar](../../README.pt-BR.md) · [próximo: diagnóstico →](05-diagnostico-tela-preta-ram.md)

## Resultado

**Funcionou.** Aqui "batalhas" são as **batalhas de Pokémon** por turnos dos hacks de GBA. Elas estão mais rápidas; mapa, menus e texto fora da batalha seguem na velocidade normal e fluidos.

- `fastforward_ratio` em uso: **3.0**. **2.5 também foi testado e ficou "perfeito"**: é o valor de referência se quiser algo mais moderado.
- Onde mudar: `timer/gbx_mod.cfg`, ou `scripts/config/set_fastforward.sh 2.5`.

## Como o stick funciona (descoberto)

- Ponto de montagem no PC: `/run/media/user/<LABEL>`. Emulador **RetroArch**; GBA no core **mGBA** (slot 7).
- **O stick NÃO usa o `gbx66.cfg` nem o `start_game.sh` da raiz do cartão.** Usa os internos em `/usr/local/share/minigui/`. Todos os ajustes feitos no `gbx66.cfg` do cartão no início não tiveram efeito.
- O `start_game.sh` interno chama `/sdcard/timer/hook.sh` (no cartão) antes de abrir o RetroArch. **O `hook.sh` é o nosso ponto de entrada.**
- "00 Timer" e "zz Timer calibrar" são falsos jogos tratados à parte pelo `hook.sh` (cap. 06).
- Controle: **ShanWan Twin USB Joystick**, que envia **teclas de teclado** (Start = `KEY_ENTER`, Select = `KEY_RIGHTSHIFT`, A = `KEY_A`, B = `KEY_B`, Y = `KEY_Y`).

## Jogos de Pokémon (`game/gba/`)

| Jogo | Base | Observação |
|---|---|---|
| PK GS Chronicles 2.7.4 | FireRed (`BPRE`) | tem batalha |
| Stone Dragon 3 | FireRed (`BPRE`) | tem batalha |
| Pokémon Mystery Dungeon | n/d | sem batalha por turnos |

## Como funciona

1. O `hook.sh` identifica jogos do slot 7 (GBA) que não sejam "Timer".
2. Abre o RetroArch (via `ra_wrap.sh`) com `-c /sdcard/timer/gbx_mod.cfg`, cópia do config interno com `fastforward_ratio` alterado.
3. Erros vão para `timer/ra.err`; o código de saída para `hook.log`.

`gbx_mod.cfg` e `ra_wrap.sh` **serão adicionados ao repositório depois**.

## O que descobrimos

- A hipótese inicial era que o ajuste aceleraria o jogo todo. **Estava errada**: o efeito aparece só nas batalhas. **Não sabemos por quê**; funciona, mas a causa não foi investigada.
- O GBA é travado em 60 fps pelo emulador e as animações duram quadros fixos; um stick mais potente não aceleraria nada.

## Abandonado

| Ideia | Motivo |
|---|---|
| `gbx66.cfg` da raiz do cartão | O stick usa o interno |
| `tools_diag.sh` chamado pelo `start_game.sh` do cartão | Esse `start_game.sh` nunca roda |
| Botão de avanço (L, Start/Enter, códigos `_btn`) | L tem função na batalha; Start não acelerou; `_btn` não serve para um controle que manda teclas |
| Ligar o avanço por tempo (`FAST_FORWARD` via stdin) | Recusado, nunca aplicado |
| Aceleração automática lendo a memória do jogo | Exigiria RetroArch com leitura de memória e o endereço da flag de batalha por hack |
| Mais "desempenho" | O GBA é limitado a 60 fps |
| Contador de FPS (`fps_show`) | Esta build não o desenha; valeu a velocidade percebida |

## Opções dentro do jogo (independentes do emulador)

Text Speed: Fast · Battle Scene: Off · Battle Style: Set.

## Arquivos e backups no cartão

| Arquivo | Para quê |
|---|---|
| `timer/hook.sh` | ponto de entrada; abre o RetroArch com o `gbx_mod.cfg` |
| `timer/hook.sh.bak_diag2` | `hook.sh` original, antes do trecho do RetroArch |
| `timer/hook.sh.bak_ev` / `bak_dbg` / `bak_auto` | versões intermediárias |
| `timer/gbx_mod.cfg` | config dos jogos GBA (a velocidade se ajusta aqui) |
| `timer/gbx_mod.cfg.bak_20` | config com velocidade 2.0 |
| `timer/cfg_interno.cfg` | cópia do config interno original (`fastforward_ratio = 0.0`) |
| `gbx66.cfg.bak_ff`, `start_game.sh.bak_diag` | backups de ajustes ineficazes na raiz |

## Como desfazer tudo

```bash
S=/run/media/user/<LABEL>
cp "$S/timer/hook.sh.bak_diag2" "$S/timer/hook.sh"   # hook original, sem RetroArch modificado
cp "$S/start_game.sh.bak_diag" "$S/start_game.sh"    # tira a linha do tools_diag.sh
sync
```

## Limpeza opcional (pendente)

1. Remover `tools_diag.sh` e a linha `sh /sdcard/tools_diag.sh` do `start_game.sh` do cartão; `timer/diag2.sh`, `timer/ff.cfg`, `timer/snippet*.txt`, `timer/ev.event*`, `timer/ra.err`.
2. Confirmar o `hook.sh` limpo: `sed -n 4,6p timer/hook.sh` (a linha do `evtest` e o `-v` devem ter saído; a linha do `-c /sdcard/timer/gbx_mod.cfg` deve continuar).
3. `input_hold_fast_forward = "enter"` no `gbx_mod.cfg` não faz nada útil; pode ficar ou voltar a `"l"`.
4. Limitar o ajuste só aos Pokémon (hoje vale para todo o slot 7, exceto Timer). Ninguém reportou problema.
