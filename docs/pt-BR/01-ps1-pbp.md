# 01 · PS1: conversão para PBP

[← voltar](../../README.pt-BR.md) · [próximo: saves e capas →](02-saves-e-capas.md)

## Problema

O PSXPackager falhava em todos os jogos com `Could not find file '...bin'`. Os `.cue` apontavam para nomes de `.bin` que não existiam na pasta (ex.: o `.cue` citava `A Bug's Life (Dublado).bin` e o arquivo era `A Bug's Life.bin`).

## Solução

`scripts/ps1/convert_ps1.sh`:

1. corrige a linha `FILE` de cada `.cue` de forma **conservadora**: mesmo nome ignorando maiúsculas ou, num `.cue` com um único `FILE`, o `.bin` com o nome-base do `.cue` (ou o único `.bin` da pasta). Sem casamento por similaridade, e o `.cue` é lido e gravado em UTF-8, então nomes com acento não são corrompidos;
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
- **Bug dos acentos corrigido.** A primeira versão lia e gravava os `.cue` em latin-1: um `.cue` **correto** chamado `Pokémon Cópia` era regravado com bytes latin-1 (`e9` em vez de `c3 a9`), corrompendo-o, e o passo de apagar podia deixar um `.bin` órfão **[medido numa sessão de revisão, disco sintético]**. A versão atual preserva os bytes; conferido offline com `.cue` sintéticos (nome com acento intacto, referência quebrada corrigida, `.cue` ambíguo deixado em paz).
- **Casamento por `difflib` removido:** ele podia ligar vários `FILE` ao mesmo `.bin`.
- **`.chd` não é suportado** pelo PSXPackager 1.6.2 **[medido]**. Agora o script imprime uma linha `[chd]` com o comando `chdman extractcd` em vez de falhar. Extraia antes (pacote `mame-tools`).

## Multi-disco (Tales of Destiny II): **testado no aparelho, funciona** [testado pelo autor]

`scripts/ps1/multidisc_pbp.sh` extrai cada disco de volta para bin/cue, monta um `.m3u` com os `.cue` na ordem e empacota em um PBP multi-disco.

A flag de extração era um palpite na primeira versão. Uma sessão de revisão posterior mediu o PSXPackager 1.6.2 real com discos sintéticos **[medido]**:

- **`-x` NÃO é "extrair":** significa *sobrescrever sem perguntar*. O script e os docs anteriores usavam `-x` como flag de extração, o que estava errado.
- Extrair **não precisa de flag**: passar um `.pbp` em `-i` já gera `.bin/.cue`; `-d 1,2` escolhe os discos.
- Um `.m3u` em `-i` (caminhos absolutos ou relativos) gera **um** PBP multi-disco, com o nome do `.m3u`.
- `-d N` num PBP de 1 disco ignora o `N` e extrai o único disco (rc=0). Para provar que um PBP tem mesmo vários discos, confira o sufixo ` - Disc N` no nome extraído; "gerou um `.cue`" não basta.
- O código de saída é confiável: `0` sucesso, `1` falha.

O script foi corrigido (sem `EXTRACT_FLAG`). **O autor rodou o script com um jogo multi-disco real e abriu o PBP no stick: funciona** [testado pelo autor; sem log guardado]. Mesmo assim, mantenha os PBPs originais até conferir o seu próprio jogo.
