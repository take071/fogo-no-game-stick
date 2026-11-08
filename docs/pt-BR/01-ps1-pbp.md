# 01 · PS1: conversão para PBP

[← voltar](../../README.pt-BR.md) · [próximo: saves e capas →](02-saves-e-capas.md)

## Problema

O PSXPackager falhava em todos os jogos com `Could not find file '...bin'`. Os `.cue` apontavam para nomes de `.bin` que não existiam na pasta (ex.: o `.cue` citava `A Bug's Life (Dublado).bin` e o arquivo era `A Bug's Life.bin`).

## Solução

`scripts/ps1/convert_ps1.sh`:

1. corrige a linha `FILE` de cada `.cue` para o `.bin` de mesmo nome (ou o mais parecido, com `difflib`);
2. converte com o PSXPackager 1.6.2 o que ainda não tem PBP;
3. padroniza a extensão para `.PBP` (os PBPs que já funcionavam usavam maiúsculas; o PSXPackager gera `.pbp`; como o exFAT ignora maiúsculas, o `mv` passa por um nome temporário);
4. **opcional (`--delete`)**: apaga os originais só de quem tem PBP válido (> 0 bytes). BIOS (`scph*`, `bios*`) nunca é apagada.

## Resultado

6 jogos convertidos sem erro (A Bug's Life, Alundra, Alundra 2, Diablo, Castlevania SotN, Crash Bandicoot). Com os que já existiam, a pasta `ps1` tem 10 PBPs, **testados no aparelho** **[medido]**.

## Mudanças em relação ao script original do projeto

- Caminhos pessoais viraram variáveis `SD` e `PSX`.
- Novo `--dry-run` (nada é alterado).
- Apagar originais era automático; agora só com `--delete`, porque a remoção é definitiva.
- Proteção extra para BIOS no passo de apagar.
- O script original existia em três cópias idênticas; ficou uma só.

## Multi-disco (Tales of Destiny II): **não testado** [pendente]

`scripts/ps1/multidisc_pbp.sh` extrai cada disco de volta para bin/cue, monta um `.m3u` com os `.cue` na ordem e empacota em um PBP multi-disco.
A flag de extração (`-x`) estava marcada "ajuste conforme o `--help`" e **nunca foi confirmada**. Rode `psxpackager --help`, ajuste `EXTRACT_FLAG` e mantenha os PBPs originais até funcionar.
