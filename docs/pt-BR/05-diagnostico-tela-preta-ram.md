# 05 · Diagnóstico: tela preta e RAM nos hacks de Pokémon

[← anterior](04-pokemon-avanco-rapido.md) · [← voltar](../../README.pt-BR.md) · [próximo: timer →](06-timer.md)

Legenda: **[medido]** · **[hipótese]**.

## Problemas relatados

1. Stone Dragon 3 (SD3) lento nas batalhas; queria fluidez em todos os jogos de Pokémon.
2. Ao abrir a bag **durante uma batalha** no SD3, a imagem fica preta na hora; o som continua, mas engasga. Fora da batalha a bag funciona.
3. PK GS ficava lento depois de sair do SD3.
4. A imagem "TEMPO ACABOU" do timer pisca (cap. 06).
5. Sprout Tower (PK GS) estava em velocidade normal.

## Sistema [medido]

- RetroArch 1.7.4, 1 núcleo a 1008 MHz, ~230 MB de RAM úteis, sem swap.
- mGBA em `retro_lib/mgba_libretro.so` (710052 bytes, de 2018), listado como "ORIGINAL" no `readme.txt` do fabricante.
- O frontend `game` (menuguide) fica na RAM o tempo todo: **~64 MB**.
- As duas ROMs são FireRed (`BPRE`) v0, save `FLASH1M_V103`, 32 MB cada. A do SD3 tem checksum de cabeçalho correto; a do PK GS não (o mGBA ignora).

## Descartado

| Hipótese | Resultado |
|---|---|
| Cartão com defeito | `fsck.exfat` limpo, leitura de 4,4 GB sem erro. Os erros de I/O vieram de **quedas de USB** (`sda` → `sdb`) |
| Algo "preso" entre um jogo e outro | `procs` vazio após cada jogo, config com mesmo checksum, memória livre volta a ~163 MB |
| ROM corrompida | Cabeçalho íntegro no SD3, mesmo tipo de save (não prova ausência de bug no hack) |
| Botão Start ligado ao avanço | Esquecido a pedido |
| `mgba_idle_optimization` | Trocado para `Remove Known` no `.opt` do SD3: **tela preta continuou** |
| Core mGBA mais novo (`mgba_new.so`) | Menu funcionou; **tela preta e velocidade iguais** |
| gpSP (`mame2003_libretro.so`) | **Nenhum jogo abriu** (procura `gba_bios.bin`, inexistente). Revertido |
| Frequência da CPU/GPU | Só há uma frequência; `performance` não tinha o que liberar |

Descartado na sessão de RAM (só leitura no cartão): patch em tempo de execução (`.ips/.bps/.ups`), ROM compactada (as duas são `.gba` puros de 33554432 bytes), rewind (`rewind_enable = "false"`), savestate auto-load/save (`false`), saves de tamanhos iguais (131072 bytes), opções do core no `.opt` do SD3 (nada que reserve memória; o PK GS nem tem `.opt`), e escrita de `performance` no `ra_wrap.sh` (não há; só lê governor/devfreq).

## Medições [medido]

| Jogo | RAM do RetroArch (`rss`) | RAM livre | CPU |
|---|---|---|---|
| PS1 (Castlevania) | ~43 MB (pico ~48) | ~17 a 49 MB | ~60–70% (`dtick` ~290–365) |
| PK GS (GBA) | ~78 MB | ~34 MB | ~93% (`dtick` ~467) |
| Stone Dragon 3 (GBA) | ~110–112 MB | **~3 a 6 MB** | ~93% |

- Hacks de GBA gastam mais RAM que o PS1 (PK GS ~1,8x; SD3 ~2,6x).
- SD3 usa ~33 MB a mais que o PK GS **com ROMs do mesmo tamanho**: causa desconhecida.
- Com ~93% de um núcleo, quase não há folga.
- O RetroArch **não cai** na tela preta: `rc=0`, `dtick` alto, `ra.err` limpo.
- No log do SD3: `rss` sobe de ~21 MB → ~75 MB → ~110 MB em ~10 s e **fica fixo** em ~110636 kB (parece alocação única, não vazamento); `livre` ~5,9 MB constante.

## Hipóteses em aberto

1. **Pressão de memória causa a tela preta.** Coerente com RAM baixa e som continuando, mas o log não mostra o instante da tela preta.
2. **Sobrecarga de CPU** na bag em batalha (o som engasga). Sem prova: não houve anotação de horário.
3. **`fastforward_ratio` agrava o problema** (só age em batalha e a tela preta só ocorre em batalha). **Teste A (`0.000000`) não foi feito.**
4. **Algo no remap do SD3** (`input_libretro_device_p1 = "5"`, ausente no PK GS). O remap já está como `Stone Dragon 3.rmp.off` (Teste B aplicado), mas **o resultado da bag não foi anotado**.
5. **O hack em si** tem esse comportamento no hardware do stick. Teste no PC com `mgba-qt` foi recusado.
6. **`performance` causou os `rc=139`** (crash do menuguide). Sumiram depois de reverter `performance`, `video_threaded`, `video_font_enable`, `history_list_enable` e `drop_caches` **juntos**; a causa exata não foi isolada.
7. **A "conta" da RAM:** base ~43 MB + ROM sugere uma cópia da ROM no PK GS e duas no SD3. Bate numericamente, mas nenhum mecanismo foi achado.
8. **O `rss` inclui cache de arquivo mapeado (descartável).** Se for isso, os "3–6 MB livres" enganam e a falta de RAM provavelmente **não** causa a tela preta. O `smaps` separa memória anônima de memória de arquivo.

## Medidor `smaps` (inserido, ainda NÃO testado no stick)

Entrou no `ra_wrap.sh` entre as marcas `# smaps_ini` e `# smaps_fim` (linhas 26 a 41), antes de `/usr/bin/retroarch "$@"`. Faz 8 amostras a cada 15 s (~2 min) em `timer/smaps_log.txt`: `MemFree`, `MemAvailable`, `Cached`, `AnonPages`, `Mapped`, `VmRSS`/`RssAnon`/`RssFile` e os 8 maiores mapeamentos. Sem backup do `ra_wrap.sh` (decisão do autor); o bloco marcado se remove sem cópia.

## Próximos testes (uma variável por vez)

1. **`smaps`:** ejetar; PK GS ~2 min no mapa; SD3 em batalha → abrir bag → **anotar em quantos segundos fica preto** → ~2 min; sair pelo menu. No PC: `cat timer/smaps_log.txt` e `tail -15 timer/hook.log`.
2. **Ler:** `RssAnon` do SD3 ~33 MB maior = memória real extra (investigar core/hack); diferença só em `RssFile` = cache (RAM provavelmente não é a causa); `MemAvailable` de poucos MB na hora da bag = pressão real. Se o kernel não tiver `RssAnon/RssFile`, ignore essas linhas. Se o `smaps_log.txt` não nascer, conferir `[inicio]`/`[amostra]` no `hook.log` e o caminho `/sdcard/timer/`.
3. **Teste A:** `scripts/config/set_fastforward.sh 0` e abrir a bag em batalha no SD3.
4. Repetir a bag com o `.rmp` desativado, anotando o resultado.
5. **Escolher o ratio:** medir `dtick` nas batalhas com 2.0, 2.5, 3.0. ~500 nos três = escolha de gosto; queda com ratio menor = sobra CPU.

## Limpar medidores no fim

```bash
cd /run/media/user/<LABEL>
sed -i '/# smaps_ini/,/# smaps_fim/d' timer/ra_wrap.sh
sed -i 's#sh /sdcard/timer/ra_wrap.sh -y#/usr/bin/retroarch -y#' timer/hook.sh
sed -i '/amostra_ps1/d' timer/hook.sh
sync
```

## Cuidados

- Ejetar sempre antes de tirar cartão/cabo (`scripts/config/eject.sh /dev/sdX`); houve quedas de USB e aviso de volume não desmontado.
- O governor alterado por script só volta ao normal desligando da tomada.
- Savestates (`.state1`) podem não carregar entre cores diferentes; os `.srm` não são afetados.
- Sem backup geral; **`saves/` é a única coisa insubstituível** no cartão. Sair dos jogos pelo menu.
