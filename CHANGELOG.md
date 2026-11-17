# Atualização de 16 de novembro de 2026: arquivos do aparelho

## Entraram no repositório (cópias exatas do cartão, sem alteração)
- `scripts/timer/ra_wrap.sh` e `scripts/timer/amostra_ps1.sh`: medidores de CPU e RAM (o de PS1 grava também o pico).
- `scripts/debug/tools_diag.sh`, `diag2.sh` e `start_game.sh`: registro da investigação do doc 04. O stick não os usa.
- `configs/card/` (mesma estrutura de pastas do cartão): `timer/gbx_mod.cfg`, `timer/cfg_interno.cfg`, `timer/ff.cfg`, `gbx66.cfg` e `retro_lib/retroarch-core-options.cfg`, com `configs/README.md`. O `gbx_mod.cfg` é o `cfg_interno.cfg` com 3 valores alterados (medido com `diff`).
- O `hook.sh` enviado é idêntico ao de `scripts/timer/`: nada a atualizar.
- **Novo capítulo 11** (`docs/pt-BR/11-ps1-reset-bug.md` e `docs/en/11-ps1-reset-bug.md`): "Reiniciar o jogo" fecha o RetroArch nos jogos de PS1. Problema **não resolvido**; o doc traz o contorno e como descobrir a causa. Entrou também como linha 11 da tabela do README.

## Correções
- `set_fastforward.sh` e `set_enhanced_resolution.sh` (e os gêmeos em português): trocam `cp -n`, que avisa "comportamento não portátil" nos coreutils novos, por um teste `[ -e ]`. Testados nos `.cfg` reais: só as linhas certas mudam e os valores originais voltam byte a byte.
- Docs: removida a referência solta ao doc "06-1" (apagado antes) no guia de scripts; README, doc 04, doc 07 e LEIA-ME atualizados. O CI não roda mais shellcheck em `ra_wrap.sh`, `amostra_ps1.sh` e `start_game.sh`, que precisam ficar idênticos aos do aparelho.

## Ainda pendente
- A versão de GBA do `hook.sh` (a que chama `ra_wrap.sh` com o `gbx_mod.cfg`).

---

# Atualização de 13 de novembro de 2026: scripts de PS1 e capas, testes e docs

## Scripts trocados pelos novos (cada um com gêmeo em `scripts/pt-BR/`)
- **`scripts/ps1/convert_ps1.sh`** agora também **junta jogos de vários discos** num único PBP (aceita `.cue`, `.chd` via `chdman`, PBPs soltos ou misturados), aceita a pasta como argumento, acha o `psxpackager` sozinho e só apaga (`--delete`) depois de provar que o PBP unificado tem os N discos. Novo gêmeo em Python: **`scripts/ps1/ps1_pbp.py`**. O `multidisc_pbp.sh` foi **removido** (substituído).
- **`scripts/covers/capas_gamestick.py`** (faltava): baixa as capas de todos os jogos. Ignora `&`/`_`/"and" ao comparar títulos e **segue links simbólicos do git** (os nomes `(Disc N)` do repositório do PS1 são links).
- **`scripts/covers/missing_covers_manual.py`:** confere se a capa já existe antes de baixar, segue os mesmos links e aceita a pasta como argumento.
- **`set_fastforward.sh`:** valida o número (aceita `2.5` ou `2,5`), grava sempre com ponto (`LC_ALL=C`) e falha se a chave não existir. **`set_enhanced_resolution.sh`:** modo novo `check` (acha linha `neon` sem a aspa final). **`eject.sh`:** mostra o erro do `unmount` e só desliga dispositivo removível.
- **`sel_limpa.sh`:** exige molde não vazio e guarda uma cópia única do banco do menu em `histtools/database.bak_pre_limpa` antes da primeira limpeza. **Não testado no aparelho.**

## Novo
- **`tests/`:** testes com o PSXPackager real e discos sintéticos (sem ROMs): conversor em 4 variantes (30 testes cada), scripts de config (13) e casamento de capas (12), em inglês e em português, mais `tests/check_docs.py` (links quebrados e paridade pt/en).
- **`requirements.txt`**, **`requirements-dev.txt`** e **`.github/workflows/tests.yml`** (ainda sem execução no GitHub Actions).

## Docs
- 12 links quebrados corrigidos (o README apontava para `02-saves-and-covers.md` e `07-scripts-guide.md`, que não existiam em `docs/pt-BR/`; docs antigos apontavam para o `README.pt-BR.md` removido).
- `docs/pt-BR/02-saves-e-capas.md` e `07-guia-de-scripts.md` renomeados para os mesmos nomes dos docs em inglês.
- Removidas as versões antigas que sobraram do upload anterior (substituídas pelas de 10/11): `03-graficos-e-consumo`, `04-pokemon-avanco-rapido`, `05-diagnostico-tela-preta-ram`, `06-1timer` (pt e en), `historico_do_game_stick` e `game_stick_history` (o doc 08 os cobre) e a cópia duplicada `registro_de_corre_es_fogo_no_game_stick(1).md`. Tudo continua no histórico do git.
- Docs 01, 02, 07 e 10, README e README.en atualizados para os scripts novos.

## Ainda pendente
- Abrir no stick um PBP multidisco gerado pelo fluxo automático novo (o mecanismo `.m3u` já funcionou com o script antigo).
- `gbx_mod.cfg`, `ra_wrap.sh` e a versão GBA do `hook.sh` seguem fora do repositório.

---

# O que mudou nesta atualização (10 de novembro de 2026)

Reescrevi os textos na primeira pessoa e juntei o que aprendi nas últimas sessões.

## Novo
- **Doc 08:** botão Start (3 s) que limpa o histórico e reinicia o menu.
- **Doc 09 + `docs/fotos/`:** 18 fotos dos testes (7 a 9 de novembro) com legenda.
- **Doc 10:** correções sobre o PSXPackager (`-x` não é extrair, `.chd`, acentos, `&`).
- **`scripts/timer/run.sh`** novo (aviso de 15 s, pausa o jogo, qualquer botão fecha), com o antigo em `run_original.sh`.
- **`scripts/timer/hook_timer_restaurado.sh`** e **`scripts/debug/diag_swap.sh`**.

## Corrigido
- **Timer piscando:** estava como "não resolvido"; agora está resolvido (congelar o RetroArch *antes* do `gtimer`, com `trap` para retomar). A nota de que o `kill -STOP` "piorou" foi corrigida.
- **Timer abrindo e fechando:** a causa foi eu ter sobrescrito o `hook.sh` (e `\r` do Windows), não a falta de swap.
- **RAM do Stone Dragon 3:** o `smaps` mostrou ~105 MB de memória **anônima** (real), não cache. `MemAvailable` ~49 MB; a pressão só aconteceu no carregamento. Isso não explica a tela preta (nenhuma amostra pegou a bag em batalha).
- **`start_game.sh` / `gbx66.cfg` do cartão:** registrei a dúvida de que o stick usa os internos, o que afeta a tela cheia fora do GBA.
- **Timer no arcade:** documentei a tentativa e a decisão de largar.

## Ainda não está no repositório
`hist.py`, `make_mold.py`, `sel_limpa.sh`, `capas_gamestick.py`, `ps1_pbp.py`, o `convert_ps1.sh` corrigido, `gbx_mod.cfg`, `ra_wrap.sh`, a versão GBA do `hook.sh`.

## Arquivos renomeados
`README.md` agora é o principal em português; o inglês virou `README.en.md` (o antigo `README.pt-BR.md` pode ser removido).
