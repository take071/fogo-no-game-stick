# 🔥 fogo no game stick

🇺🇸 [Read in English](README.md)

Anotações, scripts e descobertas da modificação de um **Game Stick 4K Lite** genérico (placa vermelha, firmware "V5 Base TG", menu MiniGUI + RetroArch 1.7.4). Tudo foi feito a partir de um PC com Linux Fedora, sem instalar RetroArch e sem rodar código ARM no x86_64.

> **Projeto em andamento.** Este repositório registra o que funcionou, o que foi tentado e abandonado e o que ainda está pendente. As afirmações são marcadas:
> **[medido]** visto em log/comando · **[inferido]** deduzido, sem confirmação · **[hipótese]** suspeita sem prova · **[pendente]** ainda não testado.

> **Sobre as "batalhas":** neste repositório, "batalhas" sempre significa as **batalhas por turnos dos hacks de Pokémon para GBA** (PK GS Chronicles 2.7.4 e Stone Dragon 3, ambos baseados em FireRed). O ajuste de velocidade (`fastforward_ratio`) é aplicado aos jogos de GBA abertos pelo hook, mas o efeito visível é só nessas batalhas; mapa, menus e texto ficam na velocidade normal. O Pokémon Mystery Dungeon não tem batalhas por turnos, e os outros consoles (PS1, arcade) não são afetados.

> ⚠️ Use por sua conta e risco. Faça backup antes de mexer na partição do firmware. Os caminhos usam `/run/media/user/<LABEL>` como ponto de montagem do cartão; troque pelo seu.

## Visão geral do aparelho

| Item | Valor |
|---|---|
| Aparelho | Game Stick 4K Lite, placa vermelha, V5 Base TG |
| CPU / RAM | 1 núcleo a 1008 MHz (única frequência), ~230 MB de RAM úteis, sem swap **[medido]** |
| Emulador | RetroArch 1.7.4 (ARM 32 bits hard-float, glibc 2.29) **[medido]** |
| Cores | `pcsx_rearmed` (PS1), `mgba` (GBA, slot 7) |
| Partições do cartão | `p1–p3` boot (não mexer) · `p4` squashfs 65 MB (sistema, somente leitura) · `p5` exFAT (dados, aparece como `/sdcard`) |
| Jogos | `game/<console>/` (`atari cps fc gb gba gbc md n64 ps1 sfc`) |

## O que foi feito

| # | Tema | Resultado | Doc |
|---|---|---|---|
| 1 | PS1: conversão CUE/BIN → PBP (corrigindo referências quebradas nos `.cue`) | ✅ 6 jogos convertidos, 10 PBPs no total, testado no aparelho | [01](docs/pt-BR/01-ps1-pbp.md) |
| 2 | Saves/states redirecionados para `saves/` e `states/` alterando o squashfs | ✅ saves novos caem nas pastas novas **[medido]** | [02](docs/pt-BR/02-saves-e-capas.md) |
| 3 | Capas (libretro-thumbnails) para todos os jogos reconhecidos | ✅ baixadas · ❓ exibição no menu não confirmada | [02](docs/pt-BR/02-saves-e-capas.md) |
| 4 | "Enhanced Resolution" do PS1 + ferramentas de medição de RAM/CPU | ✅ aplicada · ❓ efeito/custo reais não isolados | [03](docs/pt-BR/03-graficos-e-consumo.md) |
| 5 | **Batalhas de Pokémon** mais rápidas nos hacks de GBA (`fastforward_ratio` via `hook.sh`) | ✅ funciona (2.5 "perfeito", 3.0 em uso) | [04](docs/pt-BR/04-pokemon-avanco-rapido.md) |
| 6 | Diagnóstico da tela preta ao abrir a bag **durante uma batalha de Pokémon** e do uso de RAM nos hacks | 🔎 várias causas descartadas, causa raiz em aberto | [05](docs/pt-BR/05-diagnostico-tela-preta-ram.md) |
| 7 | "00 Timer" (falso jogo que vira cronômetro) + capas feitas por IA | ✅ funciona · ✅ aviso fixo por 15 s, jogo pausado, qualquer botão fecha · ❌ fora da lista do arcade | [06](docs/pt-BR/06-timer.md), [06-1](docs/pt-BR/06-1timer.md) |
| 8 | **Aba Histórico** do console: segurar **Start por 3 s** apaga e reinicia o menu; listar/limitar/apagar pelo PC | ✅ funciona no aparelho testado (só um aparelho) | [histórico](docs/pt-BR/historico_do_game_stick.md) |
| 9 | **Tela cheia** nos jogos (`aspect_ratio_index` de 18 para 1 em três configs) | ❓ aplicada; efeito **não confirmado** (conflita com o doc 04) | [06-1](docs/pt-BR/06-1timer.md) |

## O que desistimos de fazer

| Ideia | Motivo |
|---|---|
| Editar `gbx66.cfg` / `start_game.sh` no cartão exFAT | O aparelho usa os internos em `/usr/local/share/minigui/` (só o patch no squashfs funcionou) |
| Botão de avanço rápido (L / Start / códigos `_btn`) | O L já tem função na batalha, o Start não fez nada, o controle manda teclas de teclado; a velocidade já estava boa |
| Avanço automático por tempo ou lendo a memória do jogo | Recusado / exigiria build próprio do RetroArch e endereços por hack |
| Core mGBA novo, gpSP, governor `performance`, vídeo em thread etc. | Sem ganho, ou nenhum jogo abriu (o gpSP precisa de `gba_bios.bin`); revertido |
| `kill -STOP` no RetroArch como primeira tentativa no aviso do timer | Travou o jogo ~25 s, sem som. Funciona quando feito **antes** de iniciar o `gtimer` (agora no `run.sh`, [doc 06-1](docs/pt-BR/06-1timer.md)) |
| "00 Timer" dentro da lista do **arcade** (nova linha no `games.db`) | O menu travou duas vezes na tela de loading; cartão restaurado |
| Contador de FPS, shaders, texturas em alta resolução | Esta build não desenha / não vale a pena / o core não suporta |

## O que ainda está pendente

1. **Tela preta ao abrir a bag durante uma batalha de Pokémon (Stone Dragon 3):** rodar o Teste A (`fastforward_ratio = 0`), confirmar o Teste B (remap desativado) e anotar em que segundo a tela fica preta; rodar o medidor `smaps`.
2. **Timer, detalhes restantes:** estalo de áudio quando o jogo retoma, um botão apertado durante a pausa pode chegar ao jogo, e o `killall aplay` também para outros `aplay` ([06-1](docs/pt-BR/06-1timer.md), seção 8).
3. **Timer por cima de um jogo de arcade** não testado (só sobre GBA).
4. **Confirmar que as capas aparecem no menu** e que os **saves antigos** (Stone Dragon 3, PK GS) carregam depois da troca de pasta.
5. **Enhanced Resolution:** custo de CPU (Castlevania ~2 min ligado/desligado) e comparação visual justa; conferir a integridade do arquivo de opções.
6. **RAM do PK GS:** ~78 MB ou ~110 MB? (problema de atribuição no log).
7. **PBP multi-disco** (Tales of Destiny II): `-x` era a flag errada (significa *sobrescrever*; extrair não precisa de flag). Script corrigido, ainda não testado num jogo real ([doc 01](docs/pt-BR/01-ps1-pbp.md)).
8. **Escolher o `fastforward_ratio` final** (2.5 ou 3.0) e, se quiser, limitar só aos jogos de Pokémon.
9. **Limpar** arquivos de teste e medidores do cartão (lista nos docs [04](docs/pt-BR/04-pokemon-avanco-rapido.md) e [05](docs/pt-BR/05-diagnostico-tela-preta-ram.md)).
10. Capas de hacks/traduções e dos nomes do arcade (feitas à mão, de propósito).
11. **Tela cheia:** o [06-1](docs/pt-BR/06-1timer.md) diz que os jogos que não são GBA leem o `gbx66.cfg` do cartão, mas o [04](docs/pt-BR/04-pokemon-avanco-rapido.md) mediu que o stick o ignora; o [03](docs/pt-BR/03-graficos-e-consumo.md) também anotou um viewport de 480x272 contra a saída de 1280x720 do 06-1. Confirmar no stick qual está certo (o GBA usa o `gbx_mod.cfg`, que é realmente lido, então comece por ele).
12. **Aba Histórico:** limite automático de 15 jogos e apagar um jogo só no aparelho, gancho no boot (hoje o botão só funciona depois que um jogo é aberto), etapa de confirmação, outros aparelhos/firmwares ([doc do histórico](docs/pt-BR/historico_do_game_stick.md), seção 5).

## Estrutura do repositório

```
docs/en/  docs/pt-BR/     capítulos 01–06 (+ 06-1 detalhes do timer), 07 guia de scripts, capítulo do histórico (mesmo conteúdo, dois idiomas)
scripts/ps1/              convert_ps1.sh, multidisc_pbp.sh
scripts/covers/           check_covers.py, missing_covers_manual.py
scripts/config/           set_fastforward.sh, set_enhanced_resolution.sh, eject.sh, hist.py, make_mold.py, sel_limpa.sh
scripts/debug/            avg_per_game.sh, per_session.sh (leem timer/hook.log)
scripts/timer/            hook.sh (versão do timer, "update 3"), run.sh (final: aviso de 15 s, jogo pausado)
assets/timer_covers/      10 capas geradas por IA para as entradas "00 Timer"
```

## Arquivos que serão adicionados depois

- `capas_gamestick.py` (baixador de capas em lote; o `missing_covers_manual.py` depende do cache dele)
- o conversor de PS1 melhorado (`ps1_pbp.py`, junção multi-disco, `.chd` via `chdman`) e a suíte `tests/`: escritos numa sessão de revisão (23/23 com discos sintéticos e o PSXPackager 1.6.2 real), mas **ainda não fazem parte deste repositório**
- `gbx_mod.cfg` e `ra_wrap.sh` (config de lançamento do GBA e wrapper com o amostrador de RAM/CPU)
- a versão do `hook.sh` para *GBA* (o de `scripts/timer/` é a versão do timer; os dois precisam ser unidos, veja o [doc 06](docs/pt-BR/06-timer.md))
- o `gtimer` **não** está incluído de propósito (binário ARM fechado, sem fonte, licença desconhecida)

## Scripts: início rápido

> Guia completo passo a passo (preparação, cada script, saída explicada, problemas comuns): **[docs/pt-BR/07-guia-de-scripts.md](docs/pt-BR/07-guia-de-scripts.md)**

Os scripts do PC precisam do cartão montado e de duas variáveis de ambiente:

```bash
lsblk; ls /run/media/$USER/                # descubra o label do seu cartão
export SD=/run/media/$USER/<LABEL>         # ponto de montagem do cartão (partição de dados)
export PSX=$HOME/Downloads/psxpackager/psxpackager-linux-x64/psxpackager   # só para converter PS1
```

| Quero... | Rode |
|---|---|
| Converter jogos de PS1 para PBP (mantém originais) | `scripts/ps1/convert_ps1.sh --dry-run`, depois sem `--dry-run` |
| Também apagar originais (depois de testar no aparelho) | `scripts/ps1/convert_ps1.sh --delete` |
| Ver quais jogos estão sem capa | `python3 scripts/covers/check_covers.py` |
| Mudar a velocidade das batalhas de Pokémon | `scripts/config/set_fastforward.sh 2.5` |
| Ligar/desligar a Enhanced Resolution do PS1 | `scripts/config/set_enhanced_resolution.sh enabled` |
| Ejetar o cartão com segurança | `lsblk`, depois `scripts/config/eject.sh /dev/sdb` |
| Ler RAM/CPU do log | `scripts/debug/avg_per_game.sh` |
| Ver a aba Histórico do console pelo PC | `python3 scripts/config/hist.py show` |
| Manter só os 15 mais recentes no Histórico | `python3 scripts/config/hist.py trim` |

Os scripts daqui são versões limpas dos usados no projeto: caminhos viraram variáveis, há `--dry-run` e apagar originais agora é opcional. O `convert_ps1.sh` não corrompe mais nomes de `.cue` com acento. No stick, `scripts/timer/run.sh` é a versão final (aviso de 15 s, jogo pausado) e o `scripts/timer/hook.sh` ficou **idêntico byte a byte** ao que roda lá, porque editar sem testar um hook de boot pode quebrar o menu.

## Regras de segurança mantidas

1. Não instalar RetroArch no PC; não rodar binários ARM no x86_64.
2. Só mexer no firmware com backup completo e caminho de volta testado.
3. Conferir o nome do dispositivo com `lsblk` antes de qualquer `dd` (já mudou de `sda` para `sdb`).
4. Não apagar o que não está copiado em outro lugar; testar no aparelho antes de apagar originais.
5. O relógio do aparelho está errado (arquivos ganham data de 1979): não confie em datas; use `cp -n` ao copiar saves de volta.

## Licença

MIT, veja [LICENSE](LICENSE). As capas em `assets/` foram geradas com IA pelo autor. ROMs, BIOS e imagens de firmware **não** fazem parte do repositório.
