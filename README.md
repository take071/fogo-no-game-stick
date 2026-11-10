# 🔥 fogo no game stick

🇬🇧 [Read in English](README.en.md)

Aqui eu guardo tudo o que descobri e mexi no meu **Game Stick 4K Lite** (placa vermelha, firmware "V5 Base TG", menu MiniGUI + RetroArch 1.7.4). Fiz tudo a partir de um PC com Fedora, sem instalar o RetroArch e sem rodar código ARM no x86_64.

> **Projeto em andamento.** Este repositório é meu caderno: o que funcionou, o que tentei e larguei, e o que ainda falta. Eu marco cada afirmação: **[medido]** vi em log ou comando · **[inferido]** deduzi, não confirmei · **[hipótese]** desconfiança sem prova · **[pendente]** ainda não testei.

> **Sobre "batalhas":** aqui, "batalha" sempre quer dizer as **batalhas por turnos dos hacks de Pokémon para GBA** (PK GS Chronicles 2.7.4 e Stone Dragon 3, os dois baseados em FireRed). O avanço rápido (`fastforward_ratio`) vale para os jogos de GBA abertos pelo hook, mas só dá para perceber nas batalhas; mapa, menus e texto ficam na velocidade normal. Pokémon Mystery Dungeon não tem batalha por turnos, e PS1 e arcade não são afetados.

> ⚠️ Use por sua conta e risco. Faça backup antes de mexer na partição do firmware. Nos exemplos eu uso `/run/media/usuario/<NOME>` como ponto de montagem do cartão; troque pelo seu.

## O aparelho em resumo

| Item | Valor |
|---|---|
| Aparelho | Game Stick 4K Lite, placa vermelha, V5 Base TG |
| CPU / RAM | 1 núcleo a 1008 MHz (única frequência), ~230 MB úteis, sem swap **[medido]** |
| Kernel | Linux 4.4.194 armv7l, BusyBox 1.27.2 **[medido]** |
| Emulador | RetroArch 1.7.4 (ARM 32 bits hard-float, glibc 2.29) **[medido]** |
| Núcleos | `pcsx_rearmed` (PS1), `mgba` (GBA, slot 7) |
| Partições do cartão | `p1–p3` boot (não mexer) · `p4` squashfs 65 MB (sistema, só leitura) · `p5` exFAT (dados, aparece como `/sdcard`) |
| Jogos | `game/<console>/` (`atari cps fc gb gba gbc md n64 ps1 sfc`) |

## O que eu fiz

| # | Assunto | Resultado | Doc |
|---|---|---|---|
| 1 | PS1: CUE/BIN → PBP (corrigindo `.cue` quebrados) | ✅ 6 jogos convertidos, 10 PBPs no total, testado no aparelho | [01](docs/pt-BR/01-ps1-pbp.md) |
| 2 | Saves e states redirecionados para `saves/` e `states/` (patch no squashfs) | ✅ saves novos caem nas pastas novas **[medido]** | [02](docs/pt-BR/02-saves-and-covers.md) |
| 3 | Capas (libretro-thumbnails) | ✅ baixadas · ❓ não confirmei se o menu mostra | [02](docs/pt-BR/02-saves-and-covers.md) |
| 4 | PS1 "Enhanced Resolution" + medição de RAM/CPU | ✅ aplicado · ❓ custo de CPU ainda não isolado | [03](docs/pt-BR/03-graphics-and-consumption.md) |
| 5 | Batalhas de Pokémon mais rápidas (`fastforward_ratio` pelo `hook.sh`) | ✅ funciona (2.5 "perfeito", 3.0 em uso) | [04](docs/pt-BR/04-pokemon-fastforward.md) |
| 6 | Tela preta ao abrir a bag em batalha + uso de RAM nos hacks | 🔎 várias causas descartadas; o `smaps` mostrou **memória real**, não cache | [05](docs/pt-BR/05-diagnosis-black-screen-ram.md) |
| 7 | "00 Timer": alerta **fixo por 15 s**, jogo pausa e volta sozinho, qualquer botão fecha | ✅ resolvido (antes piscava) | [06](docs/pt-BR/06-timer.md) |
| 8 | Tela cheia 16:9 (`aspect_ratio_index = 1`) | ✅ nos jogos de GBA · ❓ nos outros consoles depende do cfg interno | [06](docs/pt-BR/06-timer.md) |
| 9 | **Segurar Start 3 s** na aba Histórico limpa o histórico e reinicia o menu | ✅ testado, em um aparelho só | [08](docs/pt-BR/08-history-button.md) |
| 10 | "00 Timer" dentro da lista de **arcade** | ❌ larguei (o menu travava); o timer vale para o stick todo | [06](docs/pt-BR/06-timer.md) |

As fotos que fui tirando ao longo dos testes estão em [`docs/fotos/`](docs/fotos) e comentadas em [09 – evolução em fotos](docs/pt-BR/09-photos-evolution.md).

## O que eu larguei

| Ideia | Por quê |
|---|---|
| Editar `gbx66.cfg` / `start_game.sh` **do cartão exFAT** | O stick usa o config interno em `/usr/local/share/minigui/`. Só o patch no squashfs e o `hook.sh` funcionaram. (Ver a dúvida sobre isso na seção "Pendente".) |
| Botão de avanço rápido (L / Start / códigos `_btn`) | O L já tem função em batalha, o Start não fez nada, e o controle manda teclas de teclado. A velocidade já estava boa |
| Avanço rápido automático por tempo ou lendo a memória do jogo | Recusei / exigiria um RetroArch customizado e um endereço por hack |
| mGBA novo, gpSP, governor `performance`, vídeo em thread etc. | Sem ganho, ou nenhum jogo abriu (o gpSP precisa de `gba_bios.bin`); revertido |
| Timer na lista de **arcade** (linha nova no `games.db`) | O menu travou na tela de loading duas vezes; restaurei o cartão |
| Usar **Select** como botão do histórico | Segurar Select abre o menu de configurações do aparelho |
| Contador de FPS, shaders, texturas em alta | O build não desenha / não compensa / o núcleo não suporta |

> **Correção minha:** antes eu tinha anotado que o `kill -STOP` no RetroArch "piorou" o timer e tinha sido revertido. Depois entendi o erro: na tentativa antiga eu congelava o jogo **depois** de abrir o `gtimer` e não havia nada garantindo o `kill -CONT`. Congelando **antes** e com `trap` para retomar, funciona. Detalhes no [doc 06](docs/pt-BR/06-timer.md).

## O que ainda falta

1. **Tela preta ao abrir a bag em batalha (Stone Dragon 3):** fazer o Teste A (`fastforward_ratio = 0`), anotar o resultado do Teste B (remap desativado) e o segundo em que a tela apaga.
2. **Timer sobre jogo de arcade:** só vi por cima de GBA. Deve funcionar igual, mas é hipótese.
3. **Tela cheia fora do GBA:** conferir se o cfg interno (`/usr/local/share/minigui/gbx66.cfg`) também precisa do patch.
4. **Capas no menu** e **saves antigos** (Stone Dragon 3, PK GS) depois da mudança de pasta.
5. **Enhanced Resolution:** custo de CPU (Castlevania ~2 min ligado/desligado) e comparação visual justa; conferir a aspa final do `no_main`.
6. **RAM do PK GS:** ~78 MB ou ~110 MB? (problema de atribuição no log). Rodar o mesmo `smaps` do SD3 nele.
7. **PBP multidisco** (Tales of Destiny II): ver [doc 10](docs/pt-BR/10-psxpackager-fixes.md); o script corrigido ainda precisa entrar no repositório.
8. **Limite automático de 15 jogos no histórico**, direto no aparelho.
9. **Escolher o `fastforward_ratio` final** (2.5 ou 3.0) e, se quiser, restringir só aos Pokémon.
10. **Limpar** arquivos de teste e medidores do cartão.

## Estrutura do repositório

```
docs/pt-BR/  docs/en/     capítulos 01–10 (mesmo conteúdo nos dois idiomas)
docs/fotos/               fotos dos testes, na ordem em que as tirei
scripts/ps1/              convert_ps1.sh, multidisc_pbp.sh
scripts/covers/           check_covers.py, missing_covers_manual.py
scripts/config/           set_fastforward.sh, set_enhanced_resolution.sh, eject.sh
scripts/debug/            avg_per_game.sh, per_session.sh, diag_swap.sh
scripts/timer/            hook.sh, run.sh (novo), run_original.sh, hook_timer_restaurado.sh
assets/timer_covers/      10 capas feitas com IA para as entradas do "00 Timer"
```

## Arquivos que ainda vou adicionar

- `capas_gamestick.py` (baixa capas em massa; o `missing_covers_manual.py` depende do cache dele)
- `gbx_mod.cfg` e `ra_wrap.sh` (config de GBA e o wrapper com o medidor de RAM/CPU)
- a versão **GBA** do `hook.sh` (a de `scripts/timer/hook.sh` é a do timer; falta juntar as duas)
- os scripts do histórico: `hist.py`, `make_mold.py`, `sel_limpa.sh` (ver [doc 08](docs/pt-BR/08-history-button.md))
- o `gtimer` **não entra** de propósito (binário ARM fechado, sem fonte e sem licença conhecida)

## Scripts: começo rápido

> Guia completo, passo a passo: **[docs/pt-BR/07-scripts-guide.md](docs/pt-BR/07-scripts-guide.md)**

```
lsblk; ls /run/media/$USER/                # descobrir o nome do cartão
export SD=/run/media/$USER/<NOME>          # ponto de montagem (partição de dados)
export PSX=$HOME/Downloads/psxpackager/psxpackager-linux-x64/psxpackager   # só para converter PS1
```

| Quero... | Rodo |
|---|---|
| Converter PS1 para PBP (mantém os originais) | `scripts/ps1/convert_ps1.sh --dry-run` e depois sem `--dry-run` |
| Apagar os originais (depois de testar no stick) | `scripts/ps1/convert_ps1.sh --delete` |
| Ver quais jogos estão sem capa | `python3 scripts/covers/check_covers.py` |
| Mudar a velocidade das batalhas | `scripts/config/set_fastforward.sh 2.5` |
| Ligar/desligar a Enhanced Resolution | `scripts/config/set_enhanced_resolution.sh enabled` |
| Ejetar o cartão | `lsblk` e depois `scripts/config/eject.sh /dev/sdb` |
| Ler RAM/CPU do log | `scripts/debug/avg_per_game.sh` |

## Regras que sigo

1. Não instalo o RetroArch no PC e não rodo binário ARM no x86_64.
2. Só mexo no firmware com backup completo e caminho de volta testado.
3. Confiro o nome do dispositivo com `lsblk` antes de qualquer `dd` (já mudou de `sda` para `sdb`).
4. Não apago o que não está copiado em outro lugar; testo no stick antes de apagar originais.
5. O relógio do stick está errado (arquivos saem com data de 1979). Não confio em datas e uso `cp -n` ao devolver saves.
6. **Nunca sobrescrevo o `timer/hook.sh` sem guardar o original.** Foi assim que o timer parou de abrir (ver [doc 06](docs/pt-BR/06-timer.md)).
7. Scripts `.sh` editados no Windows ganham `\r`: rodo `sed -i 's/\r//g'` antes de copiar para o cartão.

## Licença

MIT, veja o [LICENSE](LICENSE). As capas de `assets/` eu gerei com IA. ROMs, BIOS e imagens de firmware **não** fazem parte deste repositório.
