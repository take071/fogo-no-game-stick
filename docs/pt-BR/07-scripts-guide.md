# 07 · Guia de uso dos scripts

[← voltar](../../README.md)

Todos os scripts ficam em `scripts/`. **Versões em português** (comentários e mensagens traduzidos, mesmo comportamento) ficam em `scripts/pt-BR/`; veja `scripts/pt-BR/LEIA-ME.md` para a tabela de nomes. As marcas da saída também são traduzidas nessas versões (ex.: `[corrigido]`, `[SEM BIN]`, `[converter]`, `[pular]`, `[ERRO]` no lugar de `[fix]`, `[NO BIN]`, `[conv]`, `[skip]`, `[ERROR]`). Os de `ps1/`, `covers/`, `config/` e `debug/` rodam **no seu PC Linux** com o cartão do stick conectado. Os de `timer/` rodam **dentro do stick**.

## 1. Preparação (uma vez)

**Requisitos no PC (Fedora):**

```bash
sudo dnf install python3 python3-pillow   # Pillow só é preciso para as capas
# udisks2 e lsblk já vêm no Fedora
```

Para converter PS1 você também precisa do **PSXPackager** (binário `psxpackager` para Linux x64, baixado do projeto no GitHub).

**Descobrir onde o cartão foi montado:**

```bash
lsblk                         # a partição exFAT grande (ex.: 58 GB) é a de dados
ls /run/media/$USER/          # o nome da pasta é o label do cartão
```

**Definir as variáveis** (valem só para o terminal aberto):

```bash
export SD=/run/media/$USER/<LABEL>      # troque <LABEL> pela pasta que apareceu acima
export PSX=$HOME/Downloads/psxpackager/psxpackager-linux-x64/psxpackager
ls "$SD/game"                           # deve listar atari, cps, fc, gb, gba, gbc, md, n64, ps1, sfc
```

Se o `ls` não listar as pastas de jogos, o `SD` está errado. Nada abaixo deve ser rodado antes disso.

Entre na pasta do repositório (`cd ~/Downloads/fogo-no-game-stick`) e, se necessário, dê permissão de execução: `chmod +x scripts/*/*.sh scripts/*/*.py`.

> **Regra de ouro:** rode sempre primeiro com `--dry-run` quando existir, confira a saída e só então rode de verdade.

---

## 2. Converter jogos de PS1 para PBP: `scripts/ps1/convert_ps1.sh`

Coloque os jogos em `$SD/game/ps1/` (ou passe a pasta como argumento) e rode. Ele corrige os `.cue`, converte cada jogo e **junta os jogos de vários discos num único PBP**. O `.chd` **não** é lido pelo PSXPackager 1.6.2: o script usa o `chdman` (pacote `mame-tools`) se estiver instalado; senão imprime `[chd]` com o comando para extrair à mão. Há um gêmeo em Python, `scripts/ps1/ps1_pbp.py`, com as mesmas opções.

```bash
scripts/ps1/convert_ps1.sh --dry-run    # mostra o que faria, não altera nada
scripts/ps1/convert_ps1.sh              # corrige os .cue, converte e junta discos; MANTÉM os originais
scripts/ps1/convert_ps1.sh /outra/pasta # ou aponte a pasta com os jogos (busca nas subpastas)
python3 scripts/ps1/ps1_pbp.py          # o gêmeo em Python: mesmas opções
```

Leitura da saída:

| Marca | Significado |
|---|---|
| `[fix] X.cue: A.bin -> B.bin` | o `.cue` apontava para um `.bin` inexistente e foi corrigido |
| `[NO BIN] X.cue` | não achou `.bin` correspondente; esse jogo não será convertido |
| `[conv] arquivo` | vai converter (ou convertendo) |
| `[skip] arquivo` | já existe um `.PBP` com o mesmo nome |
| `[chd] arquivo` | `.chd` sem o `chdman` instalado: a linha mostra o comando `chdman` para extrair à mão |
| `[ERROR] arquivo` | o PSXPackager falhou nesse jogo |
| `[merge] Jogo (N discos)` | juntando os discos num PBP único |
| `[WARN] Jogo: discos encontrados...` | conjunto incompleto (ex.: discos 1 e 3): não junta; `--force-partial` só se for de propósito |
| `[bios] arquivo` | BIOS ignorada (nunca é convertida nem apagada) |
| `[cover] A -> B` | a capa do Disco 1 foi copiada para o nome do jogo unificado |
| `[keep] ...` | PBP inválido ou incompleto: os originais foram mantidos |
| `[deleted]` / `[would delete]` | arquivo apagado / que seria apagado (`--delete`) |

**Teste os PBPs no stick.** Só quando tiver certeza:

```bash
scripts/ps1/convert_ps1.sh --dry-run --delete   # lista o que seria apagado
scripts/ps1/convert_ps1.sh --delete             # apaga .cue/.bin/.chd de quem tem PBP válido
```

O apagar é definitivo. A BIOS (`scph*`, `bios*`) nunca é apagada. Em jogos multidisco, antes de apagar o script **extrai o último disco** do PBP unificado para provar que os N discos estão lá.

### Jogos de vários discos (o mecanismo foi testado no aparelho; o fluxo automático novo ainda não)

O próprio `convert_ps1.sh` junta os discos: ele agrupa os nomes com `(Disc N)`, `[Disk N]`, `(CD N)`, `(Disco N)` ou `(Disc N of M)` e gera **um** `Nome.PBP` na mesma pasta. Aceita discos em `.cue`, `.chd` (com `chdman`) ou já convertidos em PBPs separados, inclusive misturados.

```bash
scripts/ps1/convert_ps1.sh --dry-run    # mostra os grupos e o que seria juntado
scripts/ps1/convert_ps1.sh              # junta; mantém os originais
```

- `Part 1` / `Part 2` **não** são tratados como discos.
- Se faltar um disco (ex.: só os 1 e 3), ele avisa `[WARN]` e não junta.
- A capa do Disco 1 é copiada para o nome do jogo unificado.
- Extrair discos ocupa espaço: a área de trabalho é `~/.cache/gamestick_psx` (`PSX_TMP`), fora do cartão, e o script confere o espaço livre antes.
- O antigo `multidisc_pbp.sh` (um jogo por vez, via `NAME=` e `DISCS=`) foi **substituído** por isso; veja o doc 10.
---

## 3. Capas

**Ver quem está sem capa:**

```bash
python3 scripts/covers/check_covers.py
```

Imprime `[NO COVER] pasta/jogo` e o total no fim. A capa é um `.png`/`.jpg` com o **mesmo nome do jogo**, na mesma pasta (hipótese, veja o doc 02).

**Baixar as capas de todos os jogos:** `scripts/covers/capas_gamestick.py` (aceita a raiz do cartão ou a pasta `game`; sem argumento usa `$SD`):

```bash
python3 scripts/covers/capas_gamestick.py --dry-run   # só mostra o que baixaria
python3 scripts/covers/capas_gamestick.py             # baixa; nunca sobrescreve uma capa existente
```

Precisa do Pillow (`pip install -r requirements.txt`). Guarda o cache da API em `~/.cache/capas_gamestick` e grava os jogos sem capa em `~/capas_relatorio.txt`.

**Baixar algumas capas à mão:** `scripts/covers/missing_covers_manual.py`. Edite a lista `TASKS` no topo do arquivo (repositórios, destino sem extensão e palavras do nome) e rode:

```bash
python3 scripts/covers/missing_covers_manual.py
```

Esse script depende do cache gerado pelo `capas_gamestick.py` (`~/.cache/capas_gamestick`): rode-o uma vez antes. Sem o cache, ele responde `[no candidate]`. Nunca sobrescreve uma capa existente.

**Capas do "00 Timer":** copie os PNGs de `assets/timer_covers/` para a pasta de cada console, com o mesmo nome do "jogo" falso (ex.: `gba.png` vira `00 Timer.png` em `$SD/game/gba/`).

---

## 4. Ajustes de configuração

Os dois fazem **backup automático** (`.bak_pre_...`) na primeira execução.

**Velocidade das batalhas de Pokémon** (`timer/gbx_mod.cfg`, valores usados: 2.5 e 3.0; `0` desliga):

```bash
scripts/config/set_fastforward.sh 2.5
```

Vale para os jogos de GBA abertos pelo `hook.sh`, mas o efeito aparece só nas **batalhas de Pokémon** (mapa, menus e texto ficam normais). Isso exige o `gbx_mod.cfg` no cartão (será adicionado ao repositório).

**Enhanced Resolution do PS1:**

```bash
scripts/config/set_enhanced_resolution.sh enabled      # ou: disabled
scripts/config/set_enhanced_resolution.sh check        # só confere se alguma linha neon perdeu a aspa final
```

Depois de qualquer ajuste, ejete o cartão (abaixo) e teste no stick.

---

## 5. Ejetar o cartão com segurança: `scripts/config/eject.sh`

O nome do dispositivo muda (`sda`, `sdb`...). **Confira com `lsblk` antes.**

```bash
lsblk
scripts/config/eject.sh /dev/sdb      # o disco inteiro, sem número no fim
```

O script recusa dispositivos que não sejam removíveis, desmonta as partições e desliga o cartão.

---

## 6. Medir RAM e CPU: `scripts/debug/`

Servem para ler `timer/hook.log`, que o stick preenche enquanto você joga (os medidores `ra_wrap.sh` e `amostra_ps1.sh` precisam estar instalados no cartão). Fluxo: jogue ~2 min, saia pelo menu, ejete, plugue no PC, `export SD=...` e rode:

```bash
scripts/debug/avg_per_game.sh      # média de RAM/CPU por jogo
scripts/debug/per_session.sh       # RAM máxima por sessão de jogo
```

`rss` é a RAM do RetroArch; `cpu_avg` é `dtick/5` (~100% = um núcleo inteiro). Cuidado com a atribuição errada de amostras do PK GS (doc 03).

**Gerar o relatório em Markdown** (substitui ler esses números na mão; também confere o arquivo de opções e mostra o estado do NEON):

```bash
scripts/debug/consumption_report.sh               # gera docs/pt-BR/08-consumo-medido.md e docs/en/08-measured-consumption.md
scripts/debug/consumption_report.sh --lang pt     # só o de português
```

Só lê o cartão. Sessões com RAM máxima muito diferente para o mesmo jogo saem marcadas com ⚠ (possível atribuição errada). Depois revise e faça o commit dos arquivos gerados.

---

## 7. Scripts do timer no stick: `scripts/timer/hook.sh` e `run.sh`

Não rodam no PC. Eles ficam em `timer/` **no cartão** e o stick os executa sozinho.

O **`run.sh`** é a versão final (aviso de 15 s, jogo pausado enquanto ele aparece, qualquer botão fecha). Pode ser copiado sozinho; ele não mexe no `hook.sh`:

```bash
cp "$SD/timer/run.sh" "$SD/timer/run.sh.bak"      # backup antes
cp scripts/timer/run.sh "$SD/timer/run.sh"
sync
```

`DUR` (segundos) e `PAUSAR` ficam no topo do arquivo. Com `PAUSAR=0` o pisca-pisca volta. Detalhes e comandos de conferência: doc 06-1. Para restaurar: `cp "$SD/timer/run.sh.bak" "$SD/timer/run.sh"`.

O **`hook.sh`** é a versão do timer:

```bash
cp "$SD/timer/hook.sh" "$SD/timer/hook.sh.bak_antes_update3"   # backup OBRIGATÓRIO
```

⚠️ **Não copie o `hook.sh` deste repositório por cima do seu** sem ler o doc 06: ele é a versão do timer e pode tirar o avanço rápido dos jogos de GBA. Una os dois antes. Restaurar: `cp "$SD/timer/hook.sh.bak_antes_update3" "$SD/timer/hook.sh"`.

O `gtimer` (binário) não está no repositório; ele precisa estar em `$SD/timer/gtimer`.

---

## 8. Aba Histórico: `scripts/config/hist.py`, `make_mold.py`, `sel_limpa.sh`

Explicação completa, instalação e avisos: [08-history-button.md](08-history-button.md). **Pelo PC** (precisa de `SD`):

```bash
python3 scripts/config/hist.py show        # lista, mais recente primeiro (só lê)
python3 scripts/config/hist.py trim        # mantém só os 15 mais recentes (um por jogo)
python3 scripts/config/hist.py del 55      # remove um jogo pelo GameID
python3 scripts/config/hist.py clear       # apaga tudo
```

`show` só lê; os outros **escrevem no cartão** sem confirmação e sem backup: ejete com segurança antes de usá-lo no stick. **No stick**, o `sel_limpa.sh` apaga o histórico quando você segura o **Start por 3 s** na aba Histórico. Preparação única: `python3 scripts/config/make_mold.py` (cria o molde vazio), copie o `sel_limpa.sh` para `$SD/histtools/`, adicione uma linha ao hook e confira o código do botão (`SEL=`). Testado em **um** aparelho só; só funciona depois que um jogo foi aberto desde que o aparelho ligou.

---

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| `Set SD to the mount point...` | variável `SD` não definida nesse terminal |
| `[error] .../game/ps1 not found` | `SD` aponta para o lugar errado ou o cartão não está montado |
| `psxpackager: Permission denied` | `chmod +x "$PSX"` |
| `ModuleNotFoundError: PIL` | `sudo dnf install python3-pillow` |
| `[erro] não achei a raiz do repositório` | rode o relatório de dentro do repositório ou defina `OUT=/caminho/do/repo` |
| `[refused] ... is not a removable device` | você passou o disco errado; use o do cartão, conferido com `lsblk` |
| Erro de entrada/saída no terminal | o cartão caiu e voltou com outro nome; `cd ~`, confira com `lsblk` e redefina `SD` |
