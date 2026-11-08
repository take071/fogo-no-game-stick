# 🔥 fogo no game stick

🇺🇸 [Read in English](README.md)

Anotações, scripts e descobertas da modificação de um **Game Stick 4K Lite** genérico (placa vermelha, firmware "V5 Base TG", menu MiniGUI + RetroArch 1.7.4). Tudo foi feito a partir de um PC com Fedora, sem instalar RetroArch e sem rodar código ARM no x86_64.

> **Projeto em andamento.** Este repositório registra o que funcionou, o que foi tentado e abandonado e o que ainda está pendente. As afirmações são marcadas:
> **[medido]** visto em log/comando · **[inferido]** deduzido, sem confirmação · **[hipótese]** suspeita sem prova · **[pendente]** ainda não testado.

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
| 5 | Batalhas de Pokémon mais rápidas (`fastforward_ratio` via `hook.sh`) | ✅ funciona (2.5 "perfeito", 3.0 em uso) | [04](docs/pt-BR/04-pokemon-avanco-rapido.md) |
| 6 | Diagnóstico de tela preta / RAM nos hacks de Pokémon | 🔎 várias causas descartadas, causa raiz em aberto | [05](docs/pt-BR/05-diagnostico-tela-preta-ram.md) |
| 7 | "00 Timer" (falso jogo que vira cronômetro) + capas feitas por IA | ✅ funciona · ❌ aviso pisca · ❌ fora da lista do arcade | [06](docs/pt-BR/06-timer.md) |

## O que desistimos de fazer

| Ideia | Motivo |
|---|---|
| Editar `gbx66.cfg` / `start_game.sh` no cartão exFAT | O aparelho usa os internos em `/usr/local/share/minigui/` (só o patch no squashfs funcionou) |
| Botão de avanço rápido (L / Start / códigos `_btn`) | O L já tem função na batalha, o Start não fez nada, o controle manda teclas de teclado; a velocidade já estava boa |
| Avanço automático por tempo ou lendo a memória do jogo | Recusado / exigiria build próprio do RetroArch e endereços por hack |
| Core mGBA novo, gpSP, governor `performance`, vídeo em thread etc. | Sem ganho, ou nenhum jogo abriu (o gpSP precisa de `gba_bios.bin`); revertido |
| `kill -STOP` no RetroArch para congelar a tela no aviso do timer | Piorou (jogo travou ~25 s, sem som); revertido |
| "00 Timer" dentro da lista do **arcade** (nova linha no `games.db`) | O menu travou duas vezes na tela de loading; cartão restaurado |
| Contador de FPS, shaders, texturas em alta resolução | Esta build não desenha / não vale a pena / o core não suporta |

## O que ainda está pendente

1. **Tela preta ao abrir a bag em batalha (Stone Dragon 3):** rodar o Teste A (`fastforward_ratio = 0`), confirmar o Teste B (remap desativado) e anotar em que segundo a tela fica preta; rodar o medidor `smaps`.
2. **Aviso do timer ainda pisca** (`gtimer` é um binário ARM fechado). O resultado do `timer_update3` não foi registrado.
3. **Timer por cima de um jogo de arcade** não testado (só sobre GBA).
4. **Confirmar que as capas aparecem no menu** e que os **saves antigos** (Stone Dragon 3, PK GS) carregam depois da troca de pasta.
5. **Enhanced Resolution:** custo de CPU (Castlevania ~2 min ligado/desligado) e comparação visual justa; conferir a integridade do arquivo de opções.
6. **RAM do PK GS:** ~78 MB ou ~110 MB? (problema de atribuição no log).
7. **PBP multi-disco** (Tales of Destiny II): script não testado, flag de extração não confirmada.
8. **Escolher o `fastforward_ratio` final** (2.5 ou 3.0) e, se quiser, limitar só aos jogos de Pokémon.
9. **Limpar** arquivos de teste e medidores do cartão (lista nos docs [04](docs/pt-BR/04-pokemon-avanco-rapido.md) e [05](docs/pt-BR/05-diagnostico-tela-preta-ram.md)).
10. Capas de hacks/traduções e dos nomes do arcade (feitas à mão, de propósito).

## Estrutura do repositório

```
docs/en/  docs/pt-BR/     capítulos 01–06 (mesmo conteúdo, dois idiomas)
scripts/ps1/              convert_ps1.sh, multidisc_pbp.sh
scripts/covers/           check_covers.py, missing_covers_manual.py
scripts/config/           set_fastforward.sh, set_enhanced_resolution.sh, eject.sh
scripts/debug/            avg_per_game.sh, per_session.sh (leem timer/hook.log)
scripts/timer/            hook.sh, run.sh (scripts do timer no aparelho, "update 3")
assets/timer_covers/      10 capas geradas por IA para as entradas "00 Timer"
```

## Arquivos que serão adicionados depois

- `capas_gamestick.py` (baixador de capas em lote; o `missing_covers_manual.py` depende do cache dele)
- `gbx_mod.cfg` e `ra_wrap.sh` (config de lançamento do GBA e wrapper com o amostrador de RAM/CPU)
- a versão do `hook.sh` para *GBA* (o de `scripts/timer/` é a versão do timer; os dois precisam ser unidos, veja o [doc 06](docs/pt-BR/06-timer.md))
- o `gtimer` **não** está incluído de propósito (binário ARM fechado, sem fonte, licença desconhecida)

## Scripts: como usar

```bash
export SD=/run/media/user/<LABEL>          # ponto de montagem do cartão
export PSX=$HOME/Downloads/psxpackager/psxpackager-linux-x64/psxpackager
scripts/ps1/convert_ps1.sh --dry-run       # só mostra o que faria
scripts/ps1/convert_ps1.sh                 # converte, mantém os originais
scripts/ps1/convert_ps1.sh --delete        # também apaga os originais (só depois de testar no aparelho!)
python3 scripts/covers/check_covers.py     # jogos sem capa
```

Os scripts daqui são versões limpas dos usados no projeto: caminhos viraram variáveis, há `--dry-run` e apagar originais agora é opcional. Os dois scripts do timer que rodam no aparelho ficaram **idênticos byte a byte** ao que está no stick, porque editar sem testar um hook de boot pode quebrar o menu.

## Regras de segurança mantidas

1. Não instalar RetroArch no PC; não rodar binários ARM no x86_64.
2. Só mexer no firmware com backup completo e caminho de volta testado.
3. Conferir o nome do dispositivo com `lsblk` antes de qualquer `dd` (já mudou de `sda` para `sdb`).
4. Não apagar o que não está copiado em outro lugar; testar no aparelho antes de apagar originais.
5. O relógio do aparelho está errado (arquivos ganham data de 1979): não confie em datas; use `cp -n` ao copiar saves de volta.

## Licença

MIT, veja [LICENSE](LICENSE). As capas em `assets/` foram geradas com IA pelo autor. ROMs, BIOS e imagens de firmware **não** fazem parte do repositório.
