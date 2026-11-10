# 08 · Consumo medido (RAM e CPU por jogo)

[← voltar](../../README.pt-BR.md)

> **Ainda não gerado.** Este arquivo é um espaço reservado: o relatório real é criado a partir do `timer/hook.log` do **seu** cartão e **substitui** este texto. Nenhum número foi inventado aqui; os valores já medidos e documentados estão no [capítulo 03](03-graficos-e-consumo.md).

## Como gerar

Com o cartão montado no PC (depois de jogar ~2 min e sair pelo menu):

```bash
export SD=/run/media/$USER/<LABEL>
scripts/debug/consumption_report.sh --lang pt      # em português: scripts/pt-BR/debug/relatorio_consumo.sh
```

O comando só **lê** o cartão. Ele reescreve este arquivo (e o equivalente em inglês, `docs/en/08-measured-consumption.md`) com:

- RAM e CPU médias por jogo e por sessão (inclui Castlevania e Crash Bandicoot 2 no PS1, PK GS e Stone Dragon 3 no GBA);
- o estado atual da Enhanced Resolution (`grep neon`) e dos backups do arquivo de opções;
- a checagem de integridade do `retroarch-core-options.cfg` (linhas fora do formato `chave = "valor"`, como uma aspa sem fechar);
- sessões marcadas com ⚠ quando a RAM máxima do mesmo jogo varia mais de 25% (o problema de atribuição do PK GS, [capítulo 03](03-graficos-e-consumo.md)).

Depois revise e faça o commit: `git add docs && git commit -m "Relatório de consumo"`.
