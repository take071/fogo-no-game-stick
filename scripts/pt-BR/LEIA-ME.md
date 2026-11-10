# Scripts em português

Cópias dos scripts de `scripts/` com **comentários e mensagens em português**. O comportamento é o mesmo; só mudam os textos (e as marcas de saída, ex.: `[corrigido]` no lugar de `[fix]`).

| Português (aqui) | Original (inglês) |
|---|---|
| `ps1/converter_ps1.sh` | `ps1/convert_ps1.sh` |
| `ps1/multidisco_pbp.sh` | `ps1/multidisc_pbp.sh` |
| `covers/check_covers.py` | `covers/check_covers.py` |
| `covers/capas_faltantes_manual.py` | `covers/missing_covers_manual.py` |
| `config/definir_avanco_rapido.sh` | `config/set_fastforward.sh` |
| `config/definir_resolucao_melhorada.sh` | `config/set_enhanced_resolution.sh` |
| `config/ejetar.sh` | `config/eject.sh` |
| `config/hist.py`, `make_mold.py`, `sel_limpa.sh` | mesmos nomes |
| `debug/media_por_jogo.sh` | `debug/avg_per_game.sh` |
| `debug/por_sessao.sh` | `debug/per_session.sh` |
| `debug/relatorio_consumo.sh` | `debug/consumption_report.sh` |
| `timer/run.sh` | `timer/run.sh` (só comentários traduzidos; código idêntico) |

## Scripts que rodam no stick

- **`timer/run.sh`:** só os comentários foram traduzidos; as linhas de código e as mensagens do log são **idênticas** às do original.
- **`timer/hook.sh`:** não tem versão aqui de propósito. Ele não tem comentários e precisa continuar **idêntico byte a byte** ao que roda no aparelho; use o de `scripts/timer/hook.sh`.
- **`config/sel_limpa.sh`:** só os comentários estão em português; as mensagens do `sel.log` continuam iguais (`sel_limpa started`, `history wiped`, `menu restarted`), como descrito no doc do histórico.

## Uso

Igual ao guia [07](../../docs/pt-BR/07-guia-de-scripts.md), trocando o nome do comando pelo da tabela acima. Exemplo:

```bash
export SD=/run/media/$USER/<LABEL>
export PSX=$HOME/Downloads/psxpackager/psxpackager-linux-x64/psxpackager
scripts/pt-BR/ps1/converter_ps1.sh --dry-run
scripts/pt-BR/debug/relatorio_consumo.sh
```
