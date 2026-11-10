# Histórico do game stick: limpar com um botão e gerenciar pelo PC

[← voltar](../../README.pt-BR.md) · 🇺🇸 [English version](../en/game_stick_history.md)

Documentação de uma engenharia reversa feita num **game stick retrô com Linux** (menu fechado em `/usr/bin/game`, baseado em MiniGUI, jogos rodando via RetroArch). O objetivo era controlar a aba **Histórico** do menu: apagar jogos e limitar o tamanho.

**Resultado:** segurando **Start por 3 s** na aba Histórico, o histórico é apagado e o menu reinicia na hora. Pelo PC, dá para listar, apagar um jogo, limpar tudo ou limitar a 15.

> ⚠️ Testado em **um** aparelho. Os códigos de botão, caminhos e o jeito de iniciar o menu podem ser diferentes no seu. Tudo aqui altera arquivos do cartão SD e do histórico **sem confirmação e sem backup**. Use por sua conta e risco.

---

## 1. O que descobrimos

| Pergunta | Resposta |
|---|---|
| Onde fica o histórico do menu? | `game/database.sqlite3`, tabela `History(ID, GameID, STATUS)` |
| O que são os números da tela (0026, 0010...)? | O `GameID`, não a posição do jogo na pasta |
| Onde ficam os nomes? | `game/games.db`, tabela `tbl_game` (só para os IDs de jogos cadastrados lá) |
| Qual a ordem da lista? | Pelo `ID` do maior para o menor (o mais recente fica em cima) |
| E o jogo repetido? | O próprio menu já o move para o topo (ganha um `ID` novo e a linha antiga some). Não precisa de script |
| O arquivo `parameter` (88 bytes)? | Configuração do menu, não é histórico |
| `retroarch/content_history.lpl`? | É do RetroArch. O menu **não** usa esse arquivo |
| Dá para criar um botão novo no menu? | Não. O menu é um programa fechado, num sistema somente leitura |
| O aparelho tem `sqlite3`? | Não encontramos nenhum. Por isso a edição do banco dentro do aparelho é feita trocando o arquivo inteiro por um molde |
| O menu relê o banco depois que ele muda? | Não. Ele guarda a lista na memória. A solução foi reiniciar o menu |

### Como o histórico foi achado
1. Um script de diagnóstico só de leitura, disparado pelo hook que o aparelho já executa ao abrir um jogo, listou os processos e os arquivos abertos por cada um.
2. O processo do menu mantinha abertos `database.sqlite3` e `games.db`, dentro da pasta `game/`, que tinha sido excluída das buscas por engano.
3. Abrir a cópia dos bancos com Python (`sqlite3`) mostrou a tabela `History`.

---

## 2. Como funciona a solução

```
[PC]  make_mold.py  ->  cria histtools/hist_vazio.sqlite3 (cópia do banco com History vazia)
[PC]  hist.py       ->  show / trim / del / clear direto no cartão

[Aparelho] hook (linha única) ──> sel_limpa.sh (fica em segundo plano)
    escuta os botões com evtest
    Start segurado 3 s  e  RetroArch NÃO está rodando:
        1. copia o molde por cima de database.sqlite3 (no mesmo arquivo, com cat >)
        2. kill -9 no menu (para ele não regravar o histórico antigo)
        3. sobe o menu de novo com o mesmo ambiente do boot
        4. registra em sel.log
```

Detalhes que importam:
- **Por que `cat >` e não `mv`/`cp`?** O menu mantém o arquivo aberto. Trocar o arquivo por outro faria o menu continuar olhando o antigo.
- **Por que reiniciar o menu?** Sem isso o histórico só aparece vazio depois de religar o aparelho.
- **Por que `kill -9`?** Um encerramento normal deixaria o menu regravar o histórico antigo na saída.
- **Variáveis do menu no boot** (lidas de `/proc/<pid>/environ` e do script de inicialização): `HOME=/`, `XDG_CONFIG_HOME=/sdcard/`, `MG_CFG_PATH=/usr/local/share/minigui/hdmicfg`, `storagemedia=sd`, diretório `/mnt`.
- **Trava de 8 s** para não reiniciar duas vezes com um clique.
- **Ignora o botão durante um jogo** (se `retroarch` está rodando).

---

## 3. Instalação

Troque `USER` pelo seu usuário e `MEUCARTAO` pelo nome do seu cartão em `/run/media/USER/`.

### 3.1 No PC (cartão montado)

```bash
cd /run/media/USER/MEUCARTAO
mkdir -p histtools
# copie para histtools/ o arquivo scripts/config/sel_limpa.sh deste repositório
python3 scripts/config/make_mold.py       # cria histtools/hist_vazio.sqlite3 (precisa estar com o cartão montado)
```

Se houver mais de um cartão, indique qual: `SD=/run/media/USER/MEUCARTAO python3 scripts/config/make_mold.py`

### 3.2 Descobrir o código do seu botão

O código `28` (Start) e `54` (Select) valem para o aparelho testado. No seu, confira:
- no arquivo de configuração do RetroArch do aparelho: `input_player1_start_btn` e `input_player1_select_btn`;
- ou rode `evtest /dev/input/event0` dentro do aparelho e aperte o botão (procure `code NN`).

Depois edite a linha `SEL=` do `sel_limpa.sh`.

### 3.3 Ligar o script ao aparelho

Seu aparelho precisa ter algum **hook**, um script que ele executa ao abrir um jogo. No aparelho testado, é um `hook.sh` chamado pelo `start_game.sh`. Se o seu não tiver, este método não serve, e é preciso outro jeito de iniciar o `sel_limpa.sh` (por exemplo, pelo script de boot).

Adicione **uma linha perto do começo** do hook, antes de qualquer `exit`:

```sh
[ -f /sdcard/histtools/sel_limpa.sh ] && sh /sdcard/histtools/sel_limpa.sh </dev/null >/dev/null 2>&1 &
```

No `scripts/timer/hook.sh` deste repositório (versão do timer), isso significa logo depois da linha `echo "hook ..."` e **antes** do bloco `case "$NAME"`, porque o ramo dos jogos que não são Timer termina em `exit 1`. Num hook unido GBA/timer, a regra é a mesma: antes do primeiro `exit`.

Antes de gravar, confira a sintaxe: `sh -n hook.sh`. Um erro no hook pode impedir os jogos de abrir.

### 3.4 Testar

1. Coloque o cartão no aparelho e **abra qualquer jogo** (é isso que inicia o script).
2. Volte ao menu, vá à aba Histórico e **segure o Start por uns 3 s**.
3. A tela pisca por alguns segundos e o menu volta com o histórico vazio.
4. No PC, abra `histtools/sel.log`. O esperado:
   ```
   sel_limpa started
   history wiped
   menu restarted
   ```

### 3.5 Desinstalar

```bash
(
S=/run/media/USER/MEUCARTAO
sed -i '/sel_limpa/d' "$S/caminho/do/seu/hook.sh"    # ajuste
rm -rf "$S/histtools"; sync
echo "DESFEITO"
)
```

---

## 4. Usar pelo PC: `hist.py`

```bash
python3 scripts/config/hist.py show        # lista (mais recente primeiro)
python3 scripts/config/hist.py trim        # mantém só os 15 mais recentes (um por jogo)
python3 scripts/config/hist.py trim 10     # idem, com outro limite
python3 scripts/config/hist.py del 55      # remove um jogo pelo GameID
python3 scripts/config/hist.py clear       # apaga tudo
```

`show` só lê. Os outros **escrevem no cartão**: ejete com segurança antes de usá-lo no aparelho. Os nomes só aparecem para os `GameID` cadastrados em `games.db`. Os outros aparecem como `(name not found)`.

---

## 5. O que ainda falta

- **Limite de 15 automático no aparelho.** Hoje só existe pelo PC (`hist.py trim`). Faltaria um jeito de editar o banco dentro do aparelho sem `sqlite3`: compilar um `sqlite3` pequeno para o processador dele, ou reescrever o arquivo `.sqlite3` por script, o que é trabalhoso.
- **Apagar só um jogo pelo aparelho.** Não dá para saber qual item está destacado no menu. Hoje o botão apaga tudo.
- **O botão só funciona depois que um jogo é aberto desde que o aparelho ligou**, porque quem inicia o script é o hook. Um gancho no boot resolveria, mas exige alterar o sistema, que é somente leitura.
- **Nomes dos jogos com `GameID` fora de `games.db`.** Não achamos de onde o menu tira esses nomes. Pode ser outro banco, ou o menu os monta a partir da pasta.
- **Verificar se o Start tem outra função em outras telas do menu.**
- **Teste em outros aparelhos e firmwares.**
- **Confirmação antes de apagar** (por exemplo, exigir um segundo botão).

## 6. O que tentamos e abandonamos

| Ideia | Por que abandonamos |
|---|---|
| Ler `content_history.lpl` (RetroArch) | O menu não usa esse arquivo |
| Registrar nós mesmos cada jogo aberto no histórico | O menu já faz isso, e ainda move o repetido para o topo |
| Criar um botão "apagar" dentro do menu | Programa fechado, sistema somente leitura |
| Usar **Select** como botão | Segurar o Select abre o menu de configurações do aparelho, e o Start funcionou |
| Apagar uma linha só, vendo o item destacado | O menu não expõe qual item está selecionado |
| Esperar o menu reler o banco sozinho | Ele não relê. A saída foi reiniciar o menu |
| Trocar o arquivo por `mv` ou `cp` | O menu mantém o arquivo aberto |
| Inserir a linha no hook com `awk` | Se o padrão não casar, o hook pode ser sobrescrito. Usamos `sed` com checagem de linhas e `sh -n` |

## 7. Armadilhas que encontramos

- Colar no terminal um bloco com `exit` **fecha o terminal**. Rode os blocos dentro de `( ... )`.
- Em algumas distros o `xxd` não vem instalado. Use `od -A d -t x1z arquivo`.
- `head -40` cortou listas e escondeu os arquivos mais importantes. Cuidado com limites de linhas em diagnósticos.
- Os arquivos escritos pelo aparelho têm data de 1979 ou 1980, o que ajuda a distinguir o que ele grava sozinho.
- Os nomes que a tela mostra podem vir de uma época em que o cartão tinha outros jogos. Os números (`GameID`) ficam, e os arquivos mudam.

## 8. Avisos

- Apagar o histórico **não pede confirmação** e **não há como desfazer** (nós não fazemos backup).
- O menu volta para a tela inicial depois de reiniciar.
- Se a tela ficar preta por mais de uns 10 s depois do Start, desligue e ligue o aparelho. O cartão não é afetado.
- Isso é engenharia reversa para uso pessoal, sem relação com o fabricante.

## 9. Arquivos

```
scripts/config/
  hist.py        gerencia o histórico pelo PC
  make_mold.py   cria o molde vazio no cartão
  sel_limpa.sh   roda no aparelho: Start segurado apaga e reinicia o menu
```

Para ler o código dos scripts, abra os arquivos acima. Eles são a versão genérica dos que foram testados (caminhos `histtools/` no lugar dos originais).
