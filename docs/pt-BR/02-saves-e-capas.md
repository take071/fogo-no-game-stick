# 02 · Saves em pasta própria e capas

[← anterior](01-ps1-pbp.md) · [← voltar](../../README.pt-BR.md) · [próximo: gráficos e consumo →](03-graficos-e-consumo.md)

## Parte A: saves e states em `saves/` e `states/`

### O que foi descoberto

- Os saves ficavam ao lado dos jogos (`game/gba/*.srm`, `game/ps1/*.srm`, `.state1`).
- Os `gbx66.cfg` do exFAT (raiz e `retro_lib/`) e o do squashfs tinham `savefile_directory = "default"`.
- Alterar **só** os cfgs do exFAT **não funcionou**: o aparelho não leu esse arquivo, gravou os saves ao lado dos jogos e não reconheceu os saves antigos. (Isso concorda com o que se descobriu depois: o stick usa o config interno em `/usr/local/share/minigui/`.)
- O relógio do aparelho está errado: arquivos que ele grava aparecem com data `1979-12-31`. Isso ajuda a identificar o que o aparelho gravou.

### O que foi feito (patch do squashfs)

> A partição `p4` é somente leitura: é preciso extrair, editar, reconstruir e regravar a imagem. Uma versão anterior de nossas anotações dizia que o sistema "não pode ser editado"; isso foi superado por este procedimento.

1. Backup: `dd if=/dev/sdX4 of=~/sdb4_original.img` (68157440 bytes, conferido contra o tamanho da partição). **Não apague este arquivo.**
2. Extração: `unsquashfs -d ~/sqfs_root /dev/sdX4`.
3. Em `usr/local/share/minigui/gbx66.cfg` e `gbx66_ko.cfg`:
   ```
   savefile_directory = "/sdcard/saves"
   savestate_directory = "/sdcard/states"
   savefiles_in_content_dir = "false"
   savestates_in_content_dir = "false"
   ```
4. Reconstrução com os mesmos parâmetros: `mksquashfs ~/sqfs_root ~/sdb4_novo.img -comp gzip -b 131072 -noappend` (19 MB, cabe nos 65 MB). A lista de arquivos foi comparada com a original: idêntica.
5. Gravação em `/dev/sdX4` e conferência com `cmp` ("GRAVACAO OK"); montagem para ler as duas linhas do cfg.
6. Saves existentes copiados para `saves/` e `states/` antes da mudança; os cfgs do exFAT foram restaurados do `.bak`.

> Nenhum script automatiza o `dd` de propósito: gravar no dispositivo errado apaga o disco. Confira sempre com `lsblk`.

### Verificado [medido]

Depois de jogar, arquivos com data de 1979 apareceram em `saves/` (`Resident Evil 2 Leon.srm`, `PK GS Chronicles 2.7.4.srm`, `Stone Dragon 3.srm`) e em `states/` (`Resident Evil 2 Leon.state1`). Nenhum `.srm` ficou solto em `game/`.

### Como desfazer

```bash
lsblk                                   # confirme que é o cartão (squashfs de 65 MB)
sudo dd if=$HOME/sdb4_original.img of=/dev/sdX4 bs=4M conv=fsync
```
Nunca grave no SSD do computador.

### Incidentes

| Incidente | Causa | Resolução |
|---|---|---|
| `lsblk: /dev/sda: not a block device` | O cartão reapareceu como `sdb` | Sempre `lsblk` antes de gravar |
| `OSError: Input/output error` no Python | Terminal dentro de uma pasta do cartão antes dele ser reconectado | `cd ~` e repetir |
| Firmware voltou ao original logo após gravar | O `dd` de restauração foi rodado em seguida, por engano | Gravar de novo e **não** rodar a restauração |
| `eject: unable to eject` | Partição montada/em uso | `sync`, desmontar, `udisksctl power-off` (veja `scripts/config/eject.sh`) |

### Cuidado com backups futuros

Como o relógio está errado, a data não diz qual cópia é a mais nova. Ao copiar saves de volta, use `cp -n` para não sobrescrever um progresso mais recente.

### Pendente

O progresso antigo (Stone Dragon 3, PK GS) **carrega** depois da troca de pasta **[testado pelo autor]**. Os saves antigos estão em `saves/` e também em `game/gba/`.

## Parte B: capas

### Como o menu parece achar as capas [hipótese]

A tabela `tbl_game` do `games.db` não tem coluna de imagem e a pasta `picture/` está vazia. Já em `game/md/` e `game/ps1/` havia imagens com o mesmo nome do jogo. **Confirmado no aparelho [testado pelo autor]:** a capa é o `.png`/`.jpg` com o mesmo nome do jogo, na mesma pasta, e aparece no menu. **Ainda não se sabe se isso vale para ROM hacks** (basta "jogo + nome" iguais?): teste um hack antes de contar com isso.

### O que foi feito

- Capas do repositório `libretro-thumbnails` (`Named_Boxarts`), preferindo USA, em 400x400 (tamanho mais comum em GBA e PS1), salvas como `<nome do jogo>.png`.
- PS1: A Bug's Life e Alundra receberam capa; duas imagens soltas sem jogo foram apagadas; a da BIOS foi mantida.
- Todas as pastas: o `capas_gamestick.py` (**a ser adicionado**) conferiu cada jogo e baixou **48 capas** (a maioria GBA). Já existiam 47; sobraram 3.
- As 3 restantes (Mega Man & Bass, Mother 1 & 2, `3wonders`) foram baixadas à mão: `scripts/covers/missing_covers_manual.py`.
- Conferência final: `scripts/covers/check_covers.py`.

### Limitações

- O repositório troca `&` por `_`; a primeira versão do script comparava de forma assimétrica e perdeu 2 jogos (corrigido).
- Hacks e traduções (ex.: "Super Mario World 3 - Hack") **ficam sem capa de propósito**, para não associar imagem errada. Coloque à mão com o nome exato `<jogo>.png`; **não está confirmado que o menu mostre a capa de um ROM hack** com essa regra.
- Arcade (`cps`) usa nomes curtos de `.zip`; a associação automática falha na maioria.
- O GitHub limita 60 consultas/hora sem login; o script guarda cache em `~/.cache/capas_gamestick`.
- Algumas ROMs europeias receberam a arte americana do mesmo jogo.

### Confirmado

O autor abriu o menu no aparelho e **as capas aparecem** [testado pelo autor]. Pendente apenas: **ROM hacks** (veja acima).
