# 08 – Histórico do menu: limpar com um botão e gerenciar pelo PC

Fiz engenharia reversa no menu do stick (`/usr/bin/game`, fechado, baseado em MiniGUI) para controlar a aba **Histórico**: apagar jogos e limitar o tamanho.

**Resultado:** segurando **Start por 3 s** na aba Histórico (foto [17](../fotos/17-aba-historico.jpg)), o histórico é apagado e o menu reinicia na hora. Pelo PC dá para listar, apagar um jogo, limpar tudo ou limitar a 15.

> ⚠️ Testado em **um** aparelho. Códigos de botão, caminhos e o jeito de iniciar o menu podem ser diferentes no seu. Tudo aqui altera arquivos **sem confirmação e sem backup**.
>
> **Estado dos scripts:** `hist.py`, `make_mold.py` e `sel_limpa.sh` ainda **não estão neste repositório**; vou adicioná-los. Esta página documenta o que descobri e como funciona.

## 1. O que descobri

| Pergunta | Resposta |
|---|---|
| Onde fica o histórico? | `game/database.sqlite3`, tabela `History(ID, GameID, STATUS)` |
| O que são os números da tela (0026, 0010...)? | O `GameID`, não a posição do jogo na pasta |
| Onde ficam os nomes? | `game/games.db`, tabela `tbl_game` (só para os IDs cadastrados lá) |
| Ordem da lista? | Por `ID`, do maior para o menor |
| Jogo repetido? | O menu já o move para o topo (ganha `ID` novo, a linha antiga some) |
| O arquivo `parameter` (88 bytes)? | Configuração do menu, não é histórico |
| `retroarch/content_history.lpl`? | É do RetroArch; o menu **não** usa |
| Dá para criar um botão novo no menu? | Não: binário fechado em sistema somente leitura |
| O aparelho tem `sqlite3`? | Não achei. Então troco o banco inteiro por um molde |
| O menu relê o banco? | Não, guarda a lista na memória. A saída foi reiniciar o menu |

Como achei: um script de diagnóstico só de leitura, disparado pelo hook que o aparelho já executa ao abrir um jogo, listou os processos e os arquivos abertos. O menu mantinha `database.sqlite3` e `games.db` abertos, dentro de `game/`, pasta que eu tinha excluído das buscas por engano.

## 2. Como a solução funciona

```
[PC]  make_mold.py -> cria histtools/hist_vazio.sqlite3 (banco com History vazia)
[PC]  hist.py      -> show / trim / del / clear direto no cartão

[Aparelho] hook (uma linha) -> sel_limpa.sh (fica em segundo plano, escuta com evtest)
    Start segurado 3 s e RetroArch NÃO rodando:
        1. copia o molde por cima de database.sqlite3 (mesmo arquivo, com cat >)
        2. kill -9 no menu (para não regravar o histórico antigo)
        3. sobe o menu de novo com o ambiente do boot
        4. registra em sel.log
```

- **`cat >` e não `mv`/`cp`:** o menu mantém o arquivo aberto; trocar o arquivo deixaria o menu olhando o antigo.
- **Reiniciar o menu:** sem isso o histórico vazio só aparece depois de religar.
- **`kill -9`:** um encerramento normal deixaria o menu regravar o histórico antigo.
- **Ambiente do menu no boot** (de `/proc/<pid>/environ`): `HOME=/`, `XDG_CONFIG_HOME=/sdcard/`, `MG_CFG_PATH=/usr/local/share/minigui/hdmicfg`, `storagemedia=sd`, diretório `/mnt`.
- **Trava de 8 s** para não reiniciar duas vezes com um clique; **ignora o botão durante um jogo**.

## 3. Instalação (resumo)

Troque `USER` e `MEUCARTAO`. Detalhes completos virão junto dos scripts.

1. No PC, copie `sel_limpa.sh` para `histtools/` no cartão e rode `python3 scripts/make_mold.py` (cartão montado; com mais de um, `SD=/run/media/USER/MEUCARTAO`).
2. **Código do botão:** `28` (Start) e `54` (Select) valem para o meu aparelho. No seu, veja `input_player1_start_btn` no cfg do RetroArch ou rode `evtest /dev/input/event0` e aperte o botão; depois edite a linha `SEL=`.
3. **Hook:** seu aparelho precisa de um script que ele execute ao abrir um jogo (no meu, o `hook.sh`). Adicione **uma linha perto do começo**, antes de qualquer `exit`:

   ```sh
   [ -f /sdcard/histtools/sel_limpa.sh ] && sh /sdcard/histtools/sel_limpa.sh </dev/null >/dev/null 2>&1 &
   ```

   Antes de gravar: `sh -n hook.sh`. Um erro no hook pode impedir os jogos de abrir (e lembre da regra: guarde o original do `hook.sh`).
4. **Teste:** abra qualquer jogo (é o que inicia o script), volte, vá à aba Histórico e segure Start ~3 s. O esperado em `histtools/sel.log`: `sel_limpa started`, `history wiped`, `menu restarted`.
5. **Desinstalar:** `sed -i '/sel_limpa/d' <seu hook.sh>`, `rm -rf histtools`, `sync`.

## 4. Pelo PC: `hist.py`

```bash
python3 scripts/hist.py show        # lista (mais recente primeiro)
python3 scripts/hist.py trim        # mantém os 15 mais recentes (um por jogo)
python3 scripts/hist.py trim 10
python3 scripts/hist.py del 55      # remove um jogo pelo GameID
python3 scripts/hist.py clear       # apaga tudo
```

`show` só lê; os outros **escrevem no cartão** (ejete com segurança antes de usar no aparelho). Nomes só aparecem para `GameID` cadastrados em `games.db`; os outros saem como `(name not found)`.

## 5. O que ainda falta

- **Limite de 15 automático no aparelho** (hoje só pelo PC): precisaria de um `sqlite3` compilado para o processador dele ou reescrever o `.sqlite3` por script.
- **Apagar só um jogo pelo aparelho:** o menu não expõe qual item está destacado.
- **O botão só funciona depois de abrir um jogo desde que o aparelho ligou** (o hook é quem inicia o script). Um gancho no boot resolveria, mas o sistema é somente leitura.
- **Nomes de `GameID` fora do `games.db`:** não achei de onde o menu os tira.
- **Ver se o Start faz outra coisa em outras telas** e testar em outros aparelhos.
- **Confirmação antes de apagar** (por exemplo, um segundo botão).

## 6. O que tentei e larguei

| Ideia | Por quê |
|---|---|
| Ler `content_history.lpl` | O menu não usa |
| Registrar eu mesmo cada jogo aberto | O menu já faz e ainda move repetidos para o topo |
| Botão "apagar" dentro do menu | Binário fechado, sistema só de leitura |
| **Select** como botão | Segurar Select abre as configurações do aparelho (foto [18](../fotos/18-menu-configuracoes.jpg)) |
| Apagar só a linha destacada | O menu não expõe o item selecionado |
| Esperar o menu reler o banco | Ele não relê |
| Trocar o arquivo com `mv` ou `cp` | O menu mantém o arquivo aberto |
| Inserir a linha no hook com `awk` | Se o padrão não casar, o hook pode ser sobrescrito. Usei `sed` com checagem de linhas e `sh -n` |

## 7. Armadilhas e avisos

- Colar no terminal um bloco com `exit` **fecha o terminal**: rode blocos dentro de `( ... )`.
- Sem `xxd`: use `od -A d -t x1z arquivo`. Cuidado com `head -40` em diagnósticos: já escondeu arquivos importantes.
- Arquivos escritos pelo aparelho têm data de 1979/1980, o que ajuda a ver o que ele grava sozinho.
- Os nomes da tela podem vir de uma época em que o cartão tinha outros jogos; os `GameID` ficam e os arquivos mudam.
- Apagar o histórico **não pede confirmação** e **não dá para desfazer**. O menu volta à tela inicial depois de reiniciar.
- Se a tela ficar preta por mais de ~10 s depois do Start, desligo e ligo o aparelho (o cartão não é afetado).
- Isso é engenharia reversa para uso pessoal, sem relação com o fabricante.
