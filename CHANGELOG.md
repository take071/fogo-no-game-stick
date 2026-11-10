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
