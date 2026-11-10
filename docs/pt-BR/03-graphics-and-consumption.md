# 03 – Gráficos do PS1 e consumo de RAM/CPU

Legenda: **[medido]** · **[inferido]** · **[pendente]**

## Como o cartão está organizado (resumo)

- `gbx66.cfg` na raiz do cartão e `retro_lib/retroarch-core-options.cfg`: o segundo guarda as opções dos núcleos (`core_options_path`, com `global_core_options = "true"`) **[medido]**.
- `retro_lib/pcsx_rearmed_libretro.so` é o núcleo de PS1.
- A pasta `retroarch/` e o `timer/retroarch-core-options.cfg` parecem sobras de outro sistema e provavelmente não são lidos **[inferido]**.
- Hardware: 1 núcleo a 1008 MHz **[medido, `hook.log`]**.

## Enhanced Resolution do PS1

**Antes** **[medido]**: `video_smooth = "true"`, sem shader, `pcsx_rearmed_dithering = "disabled"`, `neon_enhancement_enable = "disabled"` e `neon_enhancement_no_main = "disabled"`. O `.bak_original` do arquivo de opções tinha as duas opções `neon_enhancement` ligadas; alguém (eu) desligou depois.

**O que mudei:**

```bash
sed -i 's/^pcsx_rearmed_neon_enhancement_enable = .*/pcsx_rearmed_neon_enhancement_enable = "enabled"/' retro_lib/retroarch-core-options.cfg
```

**O que vi no jogo:** no Crash Bandicoot 2 as linhas horizontais da primeira foto sumiram, mas as bordas continuam serrilhadas e as texturas pixeladas (fotos 13, 14 e 16 em [docs/fotos](../fotos)). A Enhanced Resolution não aumenta a resolução das texturas, e numa tela pequena o ganho é modesto **[inferido]**. As fotos mostram cenas diferentes, então a comparação **não é rigorosa** **[pendente]**.

**Desfazer** (eu não fiz backup antes):

```bash
sed -i 's/^pcsx_rearmed_neon_enhancement_enable = .*/pcsx_rearmed_neon_enhancement_enable = "disabled"/' retro_lib/retroarch-core-options.cfg
```

Na saída que colei do `grep`, o `no_main` apareceu sem a aspa final. Provavelmente foi erro de cópia, mas ainda não conferi: `grep neon retro_lib/retroarch-core-options.cfg` **[pendente]**.

## Como eu meço o consumo

- `timer/ra_wrap.sh` grava no `hook.log`, a cada 5 s: `dtick` (CPU), `livre` (MemFree) e `rss` (RAM do RetroArch). Só vale para GBA (slot 7).
- `timer/amostra_ps1.sh` faz o mesmo para PS1 (slot 9) e grava também `pico` (`VmHWM`).
- `dtick` em 5 s: ~500 é um núcleo inteiro; CPU % = `dtick / 5`.
- `livre` é MemFree e **não** conta cache descartável. Veja o [doc 05](05-diagnosis-black-screen-ram.md): isso importa.

## Resultados por jogo **[medido]**

| Jogo | RAM média | RAM máx | Pico | Menor folga (MemFree) | CPU média |
|---|---|---|---|---|---|
| Castlevania (PS1) | 41 MB | 42 MB | 47 MB | 17,1 MB | 49% |
| Crash Bandicoot 2 (PS1) | 40 MB | 41 MB | 46 MB | 58,8 MB | 75% |
| PK GS (GBA) | 94 MB* | 110 MB* | n/d | 2,6 MB* | 80%* |
| Stone Dragon 3 (GBA) | 107 MB | 110 MB | n/d | 2,4 MB | 82% |

\* Valores do PK GS contaminados por erro de atribuição (abaixo).

- **PS1:** ~40 MB e 49 a 75% de um núcleo. Com a Enhanced Resolution ligada o Crash 2 usou a mesma RAM que o Castlevania sem ela.
- **GBA:** ~93% de um núcleo nas amostras estáveis (`dtick` ~467), quase sem margem. O RetroArch não cai (`rc=0`, `ra.err` limpo).
- **Stone Dragon 3:** 107–110 MB fixos depois de carregar, em 7 sessões.

### Problema de atribuição do PK GS

O script de média liga cada amostra ao último `hook` lido. Listando sessão por sessão, a 1ª sessão (limpa) do PK GS dá ~78 MB; as de 109–110 MB coincidem com o Stone Dragon 3 **[inferido]**. Por isso a média de 94 MB do PK GS não é confiável. A correção segura é gravar o nome do jogo dentro de cada linha `[amostra]` no `ra_wrap.sh`.

## Pendente

1. Custo de CPU da Enhanced Resolution (Castlevania ~2 min ligado/desligado).
2. PK GS sozinho por ~2 min e `tail -30 timer/hook.log` para confirmar os ~78 MB.
3. `grep neon ...` para conferir o arquivo de opções.
4. Fotos do mesmo ponto do jogo com a opção ligada e desligada.
