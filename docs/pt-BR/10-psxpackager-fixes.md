# 10 – Correções sobre o PSXPackager (PS1 e multidisco)

Estas coisas eu **medi** com o PSXPackager 1.6.2 real, em discos PS1 sintéticos (sem ROMs). Elas corrigem erros dos meus scripts antigos.

## O que mudou no meu entendimento

1. **`-x` não é "extrair".** No 1.6.2, `-x` significa *sobrescrever sem perguntar*. O `multidisc_pbp.sh` deste repositório (e scripts antigos meus) usam `-x` como extração, então **estão errados**.
2. **Extrair não precisa de flag:** passar um `.pbp` em `-i` já gera `.bin/.cue`. `-d 1,2` escolhe os discos.
3. **`.m3u` funciona** (caminhos absolutos e relativos) e gera **um** PBP multidisco, com o nome do `.m3u`.
4. **`.chd` não é suportado.** É preciso extrair antes com `chdman` (pacote `mame-tools`).
5. **O código de saída é confiável:** `0` em sucesso, `1` em falha.
6. **`-d N` num PBP de um disco ignora o `N`** e extrai o único disco (rc=0). Para conferir um multidisco, exijo o sufixo ` - Disc N` no nome extraído; só checar "gerou um `.cue`" daria falso positivo.
7. **Bug dos acentos (reproduzido):** o passo que corrige `.cue` reescrevia com latin-1 um `.cue` correto em UTF-8 (`Pokémon Cópia`: `e9` no lugar de `c3 a9`), corrompendo-o e podendo deixar `.bin` órfão.
8. **Bug do `&` nas capas:** o repositório de capas grava `&` como `_`, e o script antigo só trocava o `&` do título. Perdia "Mega Man & Bass" e "Mother 1 & 2".

**Não consegui reproduzir** o problema do `printf '%.6f'` com locale pt_BR (meu ambiente de teste não tinha o locale). Apliquei a correção porque é barata, mas o bug em si **não está confirmado**.

## Como ficou o conversor corrigido

Faz tudo numa passada: corrige `.cue` sem mexer nos bytes de nomes UTF-8, converte jogo de disco único, junta `Jogo (Disc 1)`, `(Disc 2)`... num só `Jogo.PBP`, aceita fontes misturadas e `.chd` (via `chdman`), copia a capa do Disc 1 e **nunca** mexe em BIOS (`scph*`, `bios*`). Recusa juntar conjuntos incompletos (discos 1 e 3, por exemplo) sem `--force-partial`. Opções: `--dry-run`, `--delete`, `--no-merge`, `--force-partial`, `--level 0-9`.

O ajuste de `.cue` ficou **mais conservador**: tirei o `difflib` por similaridade (podia ligar vários `FILE` ao mesmo `.bin`). Agora só corrige por nome igual (ignorando maiúsculas) ou, em `.cue` com um `FILE`, pelo `.bin` de mesmo nome base ou o único `.bin` da pasta; nos demais casos avisa `[NO BIN]`.

Ao apagar, só apago depois de existir um PBP válido (não vazio e com cabeçalho `PBP`); em multidisco, antes **extraio o último disco** para provar que os N discos estão lá.

Observação: a área de trabalho padrão é `~/.cache/gamestick_psx` (`PSX_TMP`). Extrair discos ocupa muito espaço; mantenha fora do cartão e fora de um `/tmp` pequeno.

## Testes (feitos antes, com discos sintéticos)

23/23 no conversor (bash e Python), 13/13 nos scripts de configuração, 9/9 no casamento de capas, `shellcheck` limpo. **Nenhum jogo real nem o aparelho** foram usados: falta abrir um PBP multidisco no stick, principalmente a troca de disco. O `eject.sh` só foi validado em sintaxe.

## Pendente

- Trazer para este repositório os scripts corrigidos (`convert_ps1.sh`, `ps1_pbp.py`, `capas_gamestick.py`) e substituir o `multidisc_pbp.sh` antigo. **Ainda não estão aqui.**
- `.gitignore` com `.psxtmp*`, `_tmp_*`, `*.m3u`, `*.part`; `requirements.txt` (`pillow`; `pycdlib` só para testes); CI com shellcheck + `py_compile` + testes.
- Registrar o `amostra_ps1.sh` na lista de pendências do README.
- Instalar `mame-tools` onde eu for converter `.chd`.
