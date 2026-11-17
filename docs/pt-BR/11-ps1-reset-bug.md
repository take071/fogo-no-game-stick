# 11 – Erro: "Reiniciar o jogo" fecha os jogos de PS1

## Status

**Problema não resolvido.** A correção fica para um projeto futuro. Por enquanto vale o contorno descrito abaixo.

## Resumo

Nos jogos de PS1, ao escolher **Reiniciar o jogo** no menu do RetroArch, o jogo não reinicia. Em vez disso, o RetroArch fecha e o aparelho volta para a tela de escolha de jogos de PS1.

## O que funciona normalmente

- Abrir e jogar os jogos de PS1.
- **Salvar estado** (save state).
- **Carregar estado** (load state).
- As demais funções do menu do RetroArch.
- **Reiniciar o jogo** nos jogos de GBA (core `mgba`): reinicia normal.

O problema aparece só no reset dos jogos de PS1.

## Ambiente

| Item | Valor |
|---|---|
| RetroArch | 1.7.4 (compilado em 22/12/2021, GCC 6.5.0, 32 bits) |
| Core de PS1 | `pcsx_rearmed_libretro.so` (slot 9 do `start_game.sh`) |
| Core de GBA (referência) | `mgba_libretro.so` (slot 7) |
| Memória | 246 MB de RAM, sem swap |
| Formato dos jogos de PS1 | `.PBP` (único formato de PS1 que roda no Game Stick) |

## Como reproduzir

1. Abra um jogo de PS1 pela lista de jogos.
2. Abra o menu do RetroArch.
3. Escolha **Reiniciar o jogo**.
4. O RetroArch fecha e volta para a lista de jogos de PS1.

## Contorno (funciona)

- Salve um estado no começo do jogo e use **Carregar estado** quando quiser recomeçar. Não faz reset do core.
- Ou use **Fechar conteúdo** e abra o jogo de novo pela lista.

## Causa

**Ainda não confirmada.** O que se sabe:

- GBA e PS1 são iniciados pelo mesmo comando. Só o core muda, então a diferença vem do `pcsx_rearmed` ou do consumo de memória dele.
- Nenhum log registra como o RetroArch termina (não há código de saída gravado). O `ra_wrap.sh` e o `amostra_ps1.sh` existem na pasta `timer`, mas não são chamados hoje.
- O `hook.sh` atual não interfere: para qualquer jogo ele sai com `exit 1`, e o script cai direto no comando do RetroArch.

Hipóteses em aberto:

1. O core `pcsx_rearmed` cai ao receber o reset (os jogos são `.PBP`, o único formato de PS1 que roda no aparelho, então não dá para comparar com outro formato).
2. Falta de memória durante o reset, por causa dos 246 MB de RAM e da ausência de swap.

## Como descobrir a causa

Gravar o código de saída do RetroArch em `timer/hook.log` depois da execução (por exemplo, no `start_game_interno.sh`):

- `rc=0`: saída normal.
- `rc=139`: falha (segfault) no core.
- `rc=137`: processo morto, normalmente por falta de memória.

Testes que não alteram nada:

- Testar o reset em vários jogos de PS1 e anotar quais fecham.

## Observações

- O script que o aparelho realmente executa fica na memória interna (`/usr/local/share/minigui/start_game.sh`). A cópia no cartão em `timer/start_game_interno.sh` serve de referência.
- O RetroArch usa o config interno (`/usr/local/share/minigui/gbx66.cfg`), não o `gbx66.cfg` da raiz do cartão.
