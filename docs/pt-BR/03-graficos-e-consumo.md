# 03 · Melhoria gráfica do PS1 e consumo

[← anterior](02-saves-e-capas.md) · [← voltar](../../README.pt-BR.md) · [próximo: Pokémon →](04-pokemon-avanco-rapido.md)

## Arquivos que o stick lê

- `retro_lib/retroarch-core-options.cfg`: opções dos cores (apontado por `core_options_path`, com `global_core_options = "true"`).
- `retro_lib/pcsx_rearmed_libretro.so`: core de PS1.
- `retroarch/` e `timer/retroarch-core-options.cfg` parecem sobras de outro sistema (Recalbox) e provavelmente não são lidos **[inferido]**.
- Observação: o capítulo 04 mostra que o `gbx66.cfg` do cartão não é usado. Se o arquivo de **opções de core** do cartão é mesmo o lido não foi confirmado isoladamente; o efeito observado abaixo é visual e discreto.

## Enhanced Resolution do PS1

Antes **[medido]**: `video_smooth = "true"`, shader desligado, `pcsx_rearmed_dithering = "disabled"`, `neon_enhancement_enable = "disabled"`, `neon_enhancement_no_main = "disabled"`. O `.bak_original` do arquivo tinha as duas opções NEON ligadas; alguém as desligou depois.

Mudança: `scripts/config/set_enhanced_resolution.sh enabled` (equivale a `sed` em `pcsx_rearmed_neon_enhancement_enable`). Conferido com `grep`.

Resultado:
- Crash Bandicoot 2 sem falhas gráficas visíveis; as linhas horizontais da primeira foto sumiram **[observado nas fotos]**.
- Bordas ainda serrilhadas e texturas pixeladas. A opção não aumenta a resolução das texturas do PS1; em 480x272 o ganho esperado é modesto **[inferido]**.
- A comparação não é rigorosa: as fotos eram de cenas diferentes.
- Não houve backup antes (o script novo faz). Para voltar: `set_enhanced_resolution.sh disabled`.
- Na saída colada do `grep`, `no_main` apareceu sem a aspa final. Provável erro de cópia, **integridade não confirmada** [pendente]: `grep neon retro_lib/retroarch-core-options.cfg`.

Não aplicado: shader leve (`sharp-bilinear`/`xbr`; a pasta `retroarch/shaders` existe mas não foi listada), texturas em alta (o PCSX-ReARMed não suporta).

## Como o consumo é medido

- `timer/ra_wrap.sh` (GBA, slot 7) registra no `hook.log`, a cada 5 s: `dtick` (CPU), `livre` (MemFree) e `rss` (RAM do RetroArch).
- `timer/amostra_ps1.sh` (PS1, slot 9) faz o mesmo e grava também `pico` (`VmHWM`).
- `dtick` em 5 s: ~500 = 1 núcleo inteiro (CPU% = `dtick/5`). `livre` não conta cache descartável: serve para comparar jogos, não como RAM total.
- O medidor `smaps` do `ra_wrap.sh` grava em `timer/smaps_log.txt`; o arquivo não existe porque o `hook.sh` só passa o GBA pelo `ra_wrap.sh` **[inferido]**.

Scripts: `scripts/debug/avg_per_game.sh` e `per_session.sh`.

## Consumo medido

| Jogo | RAM média | RAM máx | Pico | Menor folga | CPU média |
|---|---|---|---|---|---|
| Castlevania (PS1) | 41 MB | 42 MB | 47 MB | 17,1 MB | 49% |
| Crash Bandicoot 2 (PS1) | 40 MB | 41 MB | 46 MB | 58,8 MB | 75% |
| PK GS (GBA) | 94 MB* | 110 MB* | n/d | 2,6 MB* | 80%* |
| Stone Dragon 3 (GBA) | 107 MB | 110 MB | n/d | 2,4 MB | 82% |

\* contaminado por erro de atribuição (abaixo).

Os valores de CPU de outras sessões (cap. 05) ficam em ~60–70% para o PS1 e ~93% para GBA (`dtick` ~467); as médias diferem conforme a seleção de amostras.

- **PS1:** ~40 MB e 49–75% de um núcleo, com folga. Com Enhanced Resolution ligada, o Crash 2 usou a mesma RAM que o Castlevania sem ela (picos 46 e 47 MB).
- **Stone Dragon 3:** consistente em 7 sessões (107–110 MB, folga 2–6 MB). RAM fixa depois de carregar: parece alocação única, não vazamento. Por que usa ~33 MB a mais que o PK GS com ROMs do mesmo tamanho (32 MB) é **desconhecido**.
- **GBA em geral:** ~93% de um núcleo; o RetroArch não cai (`rc=0`, `ra.err` limpo).

## Problema de atribuição do PK GS

O script associa cada amostra ao último `hook` lido. Por sessão:

| PK GS | Amostras | RSS máx |
|---|---|---|
| 1ª | 25 | 78 MB |
| 2ª e 3ª | 1 cada | 75 MB |
| 4ª | 4 | 109 MB |
| 5ª | 12 | 109 MB |
| 6ª | 22 | 110 MB |

O valor real do PK GS parece ser ~78 MB (sessão limpa). As de 109–110 MB coincidem com o Stone Dragon 3: provável amostra do SD3 sob um `hook` do PK GS **[inferido]**. A alternativa (o PK GS realmente subir a ~110 MB) não dá para descartar com o log atual.

## Pendências

1. Custo de CPU da Enhanced Resolution: Castlevania ~2 min com a opção ligada vs. os 49% de antes.
2. PK GS: abrir só ele ~2 min, sair e rodar `tail -30 timer/hook.log`; `rss` ~78 MB confirma o erro de atribuição.
3. Integridade do arquivo de opções (`grep neon`).
4. Fotos do mesmo ponto do jogo, com a opção ligada e desligada.
5. `smaps_log.txt`: só nasce em jogo de GBA, após 15 s.
