# 10 – Correções sobre o PSXPackager (PS1 e multidisco)

Estas coisas eu **medi** com o PSXPackager 1.6.2 real, em discos PS1 sintéticos (sem ROMs). Elas corrigem erros dos meus scripts antigos.

## O que mudou no meu entendimento

1. **`-x` não é "extrair".** No 1.6.2, `-x` significa *sobrescrever sem perguntar*. O antigo `multidisc_pbp.sh` deste repositório (e scripts antigos meus) usava `-x` como extração: o **significado estava errado** (na prática a extração com `-x` rodou normalmente nos meus testes, porque ele só sobrescreve).
2. **Extrair não precisa de flag:** passar um `.pbp` em `-i` já gera `.bin/.cue`. `-d 1,2` escolhe os discos.
3. **`.m3u` funciona** (caminhos absolutos e relativos) e gera **um** PBP multidisco, com o nome do `.m3u`.
4. **`.chd` não é suportado.** É preciso extrair antes com `chdman` (pacote `mame-tools`).
5. **O código de saída é confiável:** `0` em sucesso, `1` em falha.
6. **`-d N` num PBP de um disco ignora o `N`** e extrai o único disco (rc=0). Para conferir um multidisco, exijo o sufixo ` - Disc N` no nome extraído; só checar "gerou um `.cue`" daria falso positivo.
7. **Bug dos acentos (reproduzido):** o passo que corrige `.cue` reescrevia com latin-1 um `.cue` correto em UTF-8 (`Pokémon Cópia`: `e9` no lugar de `c3 a9`), corrompendo-o e podendo deixar `.bin` órfão.
8. **Bug do `&` nas capas:** o repositório de capas grava `&` como `_`, e o script antigo só trocava o `&` do título. Perdia "Mega Man & Bass" e "Mother 1 & 2".
9. **Links simbólicos no libretro-thumbnails [medido, download real]:** no repositório do PS1, nomes como `(Disc 1)` são links simbólicos do git; o servidor devolve só o caminho do destino em texto (27 bytes para o Final Fantasy VII) e o script tentava abrir isso como imagem. Agora ele segue o link.

**Não consegui reproduzir** o problema do `printf '%.6f'` com locale pt_BR (meu ambiente de teste não tinha o locale). Apliquei a correção porque é barata, mas o bug em si **não está confirmado**.

## Como ficou o conversor corrigido

Faz tudo numa passada: corrige `.cue` sem mexer nos bytes de nomes UTF-8, converte jogo de disco único, junta `Jogo (Disc 1)`, `(Disc 2)`... num só `Jogo.PBP`, aceita fontes misturadas e `.chd` (via `chdman`), copia a capa do Disc 1 e **nunca** mexe em BIOS (`scph*`, `bios*`). Recusa juntar conjuntos incompletos (discos 1 e 3, por exemplo) sem `--force-partial`. Opções: `--dry-run`, `--delete`, `--no-merge`, `--force-partial`, `--level 0-9`.

O ajuste de `.cue` ficou **mais conservador**: tirei o `difflib` por similaridade (podia ligar vários `FILE` ao mesmo `.bin`). Agora só corrige por nome igual (ignorando maiúsculas) ou, em `.cue` com um `FILE`, pelo `.bin` de mesmo nome base ou o único `.bin` da pasta; nos demais casos avisa `[NO BIN]`.

Ao apagar, só apago depois de existir um PBP válido (não vazio e com cabeçalho `PBP`); em multidisco, antes **extraio o último disco** para provar que os N discos estão lá.

O conversor aceita a pasta como argumento (`convert_ps1.sh /pasta/dos/jogos`) e acha o `psxpackager` sozinho. Os scripts estão em `scripts/ps1/` (bash e Python) e há gêmeos em português em `scripts/pt-BR/`.

Observação: a área de trabalho padrão é `~/.cache/gamestick_psx` (`PSX_TMP`). Extrair discos ocupa muito espaço; mantenha fora do cartão e fora de um `/tmp` pequeno.

## Testes (com discos sintéticos)

Em `tests/` (`bash tests/run_tests.sh`; precisa do PSXPackager e de `pip install pycdlib pillow`): 30/30 no conversor, nas quatro variantes (bash e Python, em inglês e em português), 13/13 nos scripts de configuração (en e pt), 12/12 no casamento de capas (en e pt), `shellcheck` limpo. Usam o PSXPackager 1.6.2 real e discos sintéticos. **Nenhum jogo real nem o aparelho** foram usados: falta abrir no stick um PBP gerado pelo fluxo automático novo, principalmente a troca de disco. O `eject.sh` só foi validado em sintaxe. O download de capas foi testado com rede real em 3 capas; a listagem completa pela API do GitHub não foi exercitada.

## Pendente

- Abrir no stick um PBP multidisco gerado pelo `convert_ps1.sh` (o mecanismo `.m3u` já funcionou com o script antigo; o fluxo automático novo ainda não foi aberto no aparelho).
- Conferir a primeira execução do workflow `.github/workflows/tests.yml` no GitHub: as etapas foram testadas localmente, mas ele nunca rodou no Actions.
- Registrar o `amostra_ps1.sh` na lista de pendências do README.
- Instalar `mame-tools` onde eu for converter `.chd`.
