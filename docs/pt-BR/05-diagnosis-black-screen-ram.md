# 05 – Tela preta na bag em batalha e uso de RAM nos hacks

Legenda: **[medido]** visto em log/comando · **[inferido]** deduzido · **[hipótese]** sem prova · **[pendente]** não testei

## O que me incomoda

1. No Stone Dragon 3 (SD3), ao abrir a bag **durante uma batalha** a imagem fica preta na hora. O som continua, mas engasga. Fora da batalha a bag funciona.
2. O PK GS ficava lento depois de sair do SD3.
3. O SD3 usa ~33 MB de RAM a mais que o PK GS, com ROMs do mesmo tamanho (32 MB).

## Descartado

| Hipótese | Resultado |
|---|---|
| Cartão com defeito | `fsck.exfat` limpo, 4,4 GB lidos sem erro. Os "erros de entrada/saída" vieram de **quedas de USB** (o dispositivo mudava de `sda` para `sdb`) |
| Algo "preso" entre um jogo e outro | `procs` vazio depois de cada jogo, mesmo checksum de config, memória livre volta a ~163 MB |
| ROM corrompida | Cabeçalho íntegro no SD3 e mesmo tipo de save (`FLASH1M_V103`) nos dois. Não prova que o hack não tenha bug |
| `mgba_idle_optimization` | Troquei para `Remove Known`. A tela preta continuou |
| mGBA mais novo (buildbot) | O menu funcionou; tela preta e velocidade iguais |
| gpSP | Nenhum jogo de GBA abriu (procura `gba_bios.bin`, que não existe no cartão). Revertido |
| Frequência de CPU/GPU | Só existe uma; o `performance` não tinha o que liberar |
| Patch em tempo de execução, ROM compactada, rewind, savestate automático, diferença de save, opções do core | Verifiquei no cartão: nada disso explica a RAM |
| `performance` ainda escrito no `ra_wrap.sh` | Não há mais; o script só lê governor/devfreq |

## Medição nova: `smaps` do Stone Dragon 3 **[medido]**

Rodei o diagnóstico com o SD3 aberto (amostras a cada 10 s, kernel 4.4.194, sem swap, sem zram).

| Momento (uptime) | RSS do RetroArch | Memória anônima | MemFree | MemAvailable |
|---|---|---|---|---|
| 306 s (abrindo) | ~2 MB | 0,3 MB | 160 MB | 168 MB |
| 316 s | ~55 MB | ~51 MB | 75 MB | 120 MB |
| 326 s | ~112 MB | ~104,5 MB | 6,5 MB | 49,9 MB |
| 337–377 s | ~112 MB (fixo) | ~104,9 MB | ~6 MB | ~49,5 MB |

O que isso mostra:

- **A RAM é real, não é cache.** Dos ~112 MB de RSS, cerca de **105 MB são memória anônima** (`Anonymous` = `Private_Dirty`); só ~5,6 MB são arquivo limpo. Isso **derruba** a minha hipótese anterior de que a diferença de 33 MB era só página de arquivo mapeada.
- **"3–6 MB livres" enganava.** O `MemFree` fica em ~6 MB, mas o `MemAvailable` fica em ~49 MB. O `Cached` (~72 MB) inclui ~28 MB de `Shmem`, que não se libera sem swap.
- **A pressão de memória aconteceu só no carregamento.** Entre 316 s e 326 s houve `allocstall` = 10 e ~2800 páginas varridas em *direct reclaim* (`pgscan_direct_normal`). Depois, os contadores ficaram parados. `pswpin/pswpout` = 0 (sem swap).
- **Ainda não sei** por que o SD3 gasta 33 MB mais que o PK GS. Preciso do mesmo `smaps` no PK GS **[pendente]**.
- **Limite desta medição:** nenhuma das amostras pegou uma batalha ou a bag aberta, então ela **não explica a tela preta**. Só mostra que, parado, não há aperto sustentado de memória **[inferido]**.

## Hipóteses ainda abertas

1. **[hipótese]** Um pico de memória ao abrir a bag em batalha (como o pico do carregamento) faria o kernel reclamar páginas e travar o vídeo. Combina com o som continuando, mas não está provado.
2. **[hipótese]** Sobrecarga de CPU na bag em batalha (o som engasga). Com ~93% de um núcleo não há folga.
3. **[hipótese]** O `fastforward_ratio` agrava o problema: só age em batalha e a tela preta só ocorre em batalha. **O Teste A não foi feito.**
4. **[hipótese]** Algo no remap do SD3 (`input_libretro_device_p1 = "5"`, que o PK GS não tem). Já renomeei o `Stone Dragon 3.rmp` para `.rmp.off`, mas **não anotei se repeti a bag depois**.
5. **[hipótese]** O próprio hack tem esse comportamento no hardware do stick.
6. **[hipótese]** O `performance` causou os `rc=139` (crash do menu). Os crashes sumiram quando eu reverti vários ajustes juntos; a causa exata não foi isolada.

## Próximos testes (uma variável por vez)

1. **Teste A:** `fastforward_ratio = "0.000000"` e abrir a bag em batalha no SD3.
2. **Teste B:** repetir com o `.rmp` desativado e **anotar o resultado**.
3. **Anotar o segundo** em que a tela apaga (desde que abri o jogo) para cruzar com as amostras.
4. **`smaps` do PK GS** (~2 min no mapa) e do SD3 **dentro de uma batalha**.
5. Opções do jogo que cortam trabalho: Battle Scene: Off, Text Speed: Fast, Battle Style: Set.

## O erro que cometi ao medir

Para rodar o diagnóstico eu criei um `hook.sh` novo que só chamava o `diag_swap.sh` e terminava com `exit 1`. **Isso apagou o `hook.sh` real do timer** e o Timer passou a abrir e fechar na hora (ver [doc 06](06-timer.md)). Daí a regra: nunca sobrescrever o `hook.sh` sem guardar o original. O swap não teve relação com esse problema.

## Limpar os medidores no fim

```bash
cd /run/media/take/CD6F-EC8D
sed -i '/# smaps_ini/,/# smaps_fim/d' timer/ra_wrap.sh
sed -i 's#sh /sdcard/timer/ra_wrap.sh -y#/usr/bin/retroarch -y#' timer/hook.sh
sed -i '/amostra_ps1/d' timer/hook.sh
sync
```

## Ejetar com segurança

Confira o nome com `lsblk` (já mudou de `sda` para `sdb`):

```bash
cd ~
sync
udisksctl unmount -b /dev/sdb5
udisksctl power-off -b /dev/sdb
```

A pasta `saves/` é a única coisa insubstituível no cartão.
