# configs/

**PT:** cópias dos arquivos de configuração do **cartão** do Game Stick, com a mesma estrutura de pastas do cartão (`configs/card/` = raiz do cartão).
**EN:** copies of the Game Stick **card's** config files, with the same folder layout as the card (`configs/card/` = card root).

| Arquivo no repo / File in repo | Onde fica no cartão / On the card | O que é / What it is |
|---|---|---|
| `card/timer/gbx_mod.cfg` | `timer/gbx_mod.cfg` | **PT:** config dos jogos de GBA com o avanço rápido das batalhas. É o `cfg_interno.cfg` com **3 valores alterados** [medido, `diff`]: `fastforward_ratio` `0.000000`→`3.000000`, `input_hold_fast_forward` `l`→`enter`, `input_hold_fast_forward_btn` `nul`→`28`. O `scripts/config/set_fastforward.sh` muda o `fastforward_ratio` aqui. **EN:** GBA config with the battle fast-forward. It is `cfg_interno.cfg` with **3 values changed** [measured, `diff`] (listed above); `scripts/config/set_fastforward.sh` edits `fastforward_ratio` here. |
| `card/timer/cfg_interno.cfg` | `timer/cfg_interno.cfg` | **PT:** cópia da config interna do stick (`/usr/local/share/minigui/gbx66.cfg`), guardada como original para comparar e restaurar. **EN:** copy of the stick's internal config, kept as the original to compare and restore. |
| `card/gbx66.cfg` | raiz do cartão / card root | **PT:** a config da raiz do cartão. **O stick não a usa** para os jogos de GBA (doc 04); difere do `cfg_interno.cfg` em 185 linhas [medido]. **EN:** the card-root config. **The stick does not use it** for the GBA games (doc 04); it differs from `cfg_interno.cfg` in 185 lines [measured]. |
| `card/retro_lib/retroarch-core-options.cfg` | `retro_lib/retroarch-core-options.cfg` | **PT:** opções dos núcleos (ex.: PCSX-ReARMed/NEON). O `scripts/config/set_enhanced_resolution.sh` altera e confere esse arquivo. **EN:** core options (e.g. PCSX-ReARMed/NEON); `scripts/config/set_enhanced_resolution.sh` edits and checks this file. |
| `card/timer/ff.cfg` | `timer/ff.cfg` | **PT:** config mínima de teste do avanço rápido (3 linhas). Está em "Limpeza que ainda falta" do doc 04: no cartão pode ser apagada; aqui fica só como registro. **EN:** minimal fast-forward test config (3 lines). It is in the doc 04 cleanup list: it can be deleted on the card; it is kept here only as a record. |

## Notas / Notes

- **PT:** são texto puro, sem `\r` e sem segredos: os campos de senha e nickname do RetroArch estão vazios [conferido]. **EN:** plain text, no `\r` and no secrets: the RetroArch password and nickname fields are empty [checked].
- **PT:** o `hook.sh` deste repositório (a versão do timer) **não** lê o `gbx_mod.cfg`; quem o usa é a versão de GBA do `hook.sh`, que ainda não está no repositório. **EN:** this repo's `hook.sh` (the timer version) does **not** read `gbx_mod.cfg`; the GBA version of `hook.sh` does, and it is not in the repo yet.
- **PT:** os arquivos internos do firmware (em `/usr/local/share/minigui/` no stick, como o `gbx66_ko.cfg`) **não** estão aqui. **EN:** the firmware's internal files (in `/usr/local/share/minigui/` on the stick, such as `gbx66_ko.cfg`) are **not** here.
- **PT:** para aplicar no cartão, copie só o que precisa (faça backup antes). Exemplo: `cp configs/card/timer/gbx_mod.cfg "$SD/timer/"`. **EN:** to apply to the card, copy only what you need (back up first). Example: `cp configs/card/timer/gbx_mod.cfg "$SD/timer/"`.
