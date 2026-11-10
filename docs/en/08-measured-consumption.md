# 08 · Measured consumption (RAM and CPU per game)

[← back](../../README.md)

> **Not generated yet.** This file is a placeholder: the real report is created from **your** card's `timer/hook.log` and **replaces** this text. No number was invented here; the values already measured and documented are in [chapter 03](03-graphics-and-consumption.md).

## How to generate it

With the card mounted on the PC (after playing ~2 min and quitting through the menu):

```bash
export SD=/run/media/$USER/<LABEL>
scripts/debug/consumption_report.sh --lang en      # in Portuguese: scripts/pt-BR/debug/relatorio_consumo.sh
```

The command only **reads** the card. It rewrites this file (and its Portuguese twin, `docs/pt-BR/08-consumo-medido.md`) with:

- average RAM and CPU per game and per session (including Castlevania and Crash Bandicoot 2 on PS1, PK GS and Stone Dragon 3 on GBA);
- the current Enhanced Resolution state (`grep neon`) and the options-file backups;
- an integrity check of `retroarch-core-options.cfg` (lines outside the `key = "value"` format, such as an unclosed quote);
- sessions flagged ⚠ when the max RAM of the same game varies by more than 25% (the PK GS attribution problem, [chapter 03](03-graphics-and-consumption.md)).

Then review and commit: `git add docs && git commit -m "Consumption report"`.
