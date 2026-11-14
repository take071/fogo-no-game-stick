#!/usr/bin/env bash
# Converte jogos de PS1 (.cue/.bin ou .chd) para .PBP no Game Stick, juntando jogos de
# vários discos em UM único PBP multidisco.
#
# Uso:
#   scripts/pt-BR/ps1/converter_ps1.sh [PASTA] [opções]
#     PASTA = pasta com os jogos de PS1 (busca recursiva). Se omitida, usa $SD/game/ps1.
#   O PSX é achado sozinho (~/Downloads/psxpackager/psxpackager-linux-x64/psxpackager ou
#   `psxpackager` no PATH); senão, defina PSX=/caminho/do/psxpackager.
#
#   --dry-run        só mostra o que aconteceria, não altera nada
#   --delete         depois de existir um .PBP VÁLIDO, apaga os originais (.cue/.bin/.chd e os
#                    PBPs de disco único que foram juntados). PERMANENTE: teste os PBPs no
#                    stick antes. Padrão: manter os originais.
#   --no-merge       não junta discos; converte cada disco no seu próprio PBP
#   --force-partial  junta mesmo com numeração de discos não contígua (ex.: só os discos 1 e 3)
#   --level N        nível de compressão do PBP 0-9 (padrão 5)
#   -h, --help       esta ajuda
#
# Ambiente (opcional):
#   CHDMAN   binário do chdman (padrão: chdman). Só é preciso para fontes .chd, porque o
#            PSXPackager 1.6.x não lê CHD. Fedora: sudo dnf install mame-tools
#   PSX_TMP  pasta de trabalho (padrão: ~/.cache/gamestick_psx). Precisa de espaço livre para
#            os discos extraídos; mantenha FORA do cartão SD e fora de um tmpfs pequeno.
#
# O que ele trata (tudo testado com o PSXPackager 1.6.2 real, veja tests/):
#   * .cue apontando para um .bin que não existe (nome/maiúsculas) -> corrige a linha FILE (seguro p/ UTF-8)
#   * disco único                                            -> Jogo.PBP
#   * "Jogo (Disc 1).cue", "(Disc 2)", ...                   -> UM "Jogo.PBP" com todos os discos
#   * fontes mistas: Disco 1 já em .PBP, Disco 2 em .cue     -> também junta
#   * arquivos de BIOS (scph*/bios*) nunca são convertidos nem apagados.
#
# NOTA (PSXPackager): "-x" significa "sobrescrever", NÃO "extrair". Extrair não precisa de flag:
# passar um .pbp em -i já o extrai para .bin/.cue (e "-d 1,2" escolhe os discos).
set -u
set -o pipefail

DRY=0; DELETE=0; MERGE=1; FORCE=0; LEVEL=5; DIRARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --delete) DELETE=1 ;;
    --no-merge) MERGE=0 ;;
    --force-partial) FORCE=1 ;;
    --level) shift; LEVEL="${1:?--level precisa de um número 0-9}" ;;
    -h|--help) sed -n '2,36p' "$0"; exit 0 ;;
    -*) echo "opção desconhecida: $1"; exit 1 ;;
    *) if [ -z "$DIRARG" ]; then DIRARG="$1"; else echo "só uma pasta é permitida (sobrou: $1)"; exit 1; fi ;;
  esac
  shift
done
case "$LEVEL" in [0-9]) ;; *) echo "[erro] --level deve ser de 0 a 9"; exit 1 ;; esac

if [ -n "$DIRARG" ]; then D="${DIRARG%/}"
else : "${SD:?Passe a PASTA dos jogos como argumento ou defina SD=/run/media/usuario/<NOME>}"; D="$SD/game/ps1"; fi
D="$(cd "$D" 2>/dev/null && pwd)" || { echo "[erro] pasta não encontrada: ${DIRARG:-$SD/game/ps1}"; exit 1; }
if [ -z "${PSX:-}" ]; then
  for c in "$HOME/Downloads/psxpackager/psxpackager-linux-x64/psxpackager" "$(command -v psxpackager 2>/dev/null)"; do
    [ -n "$c" ] && [ -x "$c" ] && { PSX="$c"; break; }
  done
fi
: "${PSX:?psxpackager não encontrado: defina PSX=/caminho/do/psxpackager}"
[ -x "$PSX" ] || { echo "[erro] $PSX não é executável"; exit 1; }
CHDMAN="${CHDMAN:-chdman}"
TMPROOT="${PSX_TMP:-${XDG_CACHE_HOME:-$HOME/.cache}/gamestick_psx}"
mkdir -p "$TMPROOT" || { echo "[erro] não foi possível criar $TMPROOT"; exit 1; }
WORK="$(mktemp -d "$TMPROOT/run.XXXXXX")" || exit 1
trap 'rm -rf "$WORK"' EXIT
case "$D/" in "$WORK"/*) echo "[erro] PSX_TMP não pode ficar dentro da pasta dos jogos"; exit 1 ;; esac

N_OK=0; N_SKIP=0; N_ERR=0; N_DEL=0

# ---------------------------------------------------------------- funções auxiliares
lower() { printf '%s' "${1,,}"; }

protected() {                     # arquivos de BIOS nunca são convertidos nem apagados
  local n; n="$(lower "$1")"
  [[ $n == *scph* || $n == *bios* ]]
}

valid_pbp() {                     # não vazio E começa com a assinatura do PBP (00 'P' 'B' 'P')
  [ -f "$1" ] && [ -s "$1" ] || return 1
  [ "$(head -c4 "$1" | od -An -tx1 | tr -d ' \n')" = "00504250" ]
}

existing_pbp() {                  # imprime o caminho do "<base>.PBP|.pbp" existente, se houver
  local b="$1"
  if [ -f "$b.PBP" ]; then printf '%s' "$b.PBP"; return 0; fi
  if [ -f "$b.pbp" ]; then printf '%s' "$b.pbp"; return 0; fi
  return 1
}

avail_kb() { df -Pk "$WORK" | awk 'NR==2{print $4}'; }

rm_file() {
  if [ "$DRY" = 1 ]; then echo "  [apagaria] ${1##*/}"; return; fi
  if rm -f -- "$1"; then echo "  [apagado] ${1##*/}"; N_DEL=$((N_DEL+1)); fi
}

# Imprime os destinos FILE de um .cue (seguro por bytes: funciona com nomes UTF-8 e latin-1).
cue_files() {
  local LC_ALL=C line re='^[[:space:]]*[Ff][Ii][Ll][Ee][[:space:]]+"([^"]+)"'
  while IFS= read -r line || [ -n "$line" ]; do
    [[ $line =~ $re ]] && printf '%s\n' "${BASH_REMATCH[1]}"
  done < "$1"
}

# 1) corrige linhas FILE que apontam para um .bin que não existe -------------------------
fix_cue() {
  local cue="$1" dir base nfile bins=() b bn tmp name cand line out changed=0 pre post
  local LC_ALL=C
  local re='^([[:space:]]*[Ff][Ii][Ll][Ee][[:space:]]+")([^"]+)(".*)$'
  dir="$(dirname "$cue")"; base="$(basename "${cue%.*}")"
  nfile=$(cue_files "$cue" | wc -l)
  while IFS= read -r -d '' b; do bins+=("${b##*/}"); done \
    < <(find "$dir" -maxdepth 1 -type f -iname '*.bin' -print0)
  out="$(mktemp "$WORK/cue.XXXXXX")"
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line =~ $re ]]; then
      pre="${BASH_REMATCH[1]}"; name="${BASH_REMATCH[2]}"; post="${BASH_REMATCH[3]}"
      if [ ! -e "$dir/$name" ]; then
        cand=""
        for bn in "${bins[@]}"; do                       # (a) mesmo nome, maiúsculas diferentes
          [[ "${bn,,}" == "${name,,}" ]] && { cand="$bn"; break; }
        done
        if [ -z "$cand" ] && [ "$nfile" = 1 ]; then       # (b)/(c) só para .cue com um único FILE
          for bn in "${bins[@]}"; do
            tmp="${bn%.*}"
            [[ "${tmp,,}" == "${base,,}" ]] && { cand="$bn"; break; }
          done
          [ -z "$cand" ] && [ "${#bins[@]}" = 1 ] && cand="${bins[0]}"
        fi
        if [ -n "$cand" ]; then
          echo "[corrigido] ${cue##*/}: $name -> $cand"; changed=1
          line="$pre$cand$post"
        else
          echo "[SEM BIN] ${cue##*/} (referencia '$name')"
        fi
      fi
    fi
    printf '%s\n' "$line" >> "$out"
  done < "$cue"
  if [ "$changed" = 1 ] && [ "$DRY" = 0 ]; then cat "$out" > "$cue"; fi
  rm -f "$out"
}

# 2) marcas de disco ---------------------------------------------------------------------
# define DISC_N / DISC_KEY. Retorna 1 quando o nome não tem a marca "(Disc N)".
disc_parse() {
  local b="$1" re saved
  re='^(.*[^[:space:]_-])?[[:space:]_-]*[([](disc|disco|disk|cd)[[:space:]]*([0-9]+)([[:space:]]*(of|de)[[:space:]]*[0-9]+)?[])](.*)$'
  saved="$(shopt -p nocasematch)"; shopt -s nocasematch
  if [[ $b =~ $re ]]; then
    DISC_N=$((10#${BASH_REMATCH[3]}))
    DISC_KEY="${BASH_REMATCH[1]}${BASH_REMATCH[6]}"
    DISC_KEY="${DISC_KEY#"${DISC_KEY%%[![:space:]]*}"}"; DISC_KEY="${DISC_KEY%"${DISC_KEY##*[![:space:]]}"}"
    eval "$saved"; return 0
  fi
  eval "$saved"; return 1
}

# Prepara um .cue para a conversão e imprime o caminho. Para .chd, extrai com o chdman.
prep_source() {                    # tipo caminho marca
  local type="$1" path="$2" tag="$3" dd
  case "$type" in
    cue) printf '%s' "$path" ;;
    chd)
      command -v "$CHDMAN" >/dev/null 2>&1 || { echo "[chd] $path: o PSXPackager não lê .chd e o chdman não foi encontrado; instale o mame-tools ou rode: chdman extractcd -i \"$path\" -o \"${path%.*}.cue\" -ob \"${path%.*}.bin\"" >&2; return 1; }
      dd="$WORK/$tag"; mkdir -p "$dd"
      "$CHDMAN" extractcd -i "$path" -o "$dd/disc.cue" -ob "$dd/disc.bin" >&2 || { echo "[ERRO] chdman falhou em $path" >&2; return 1; }
      printf '%s' "$dd/disc.cue" ;;
    pbp)                           # extrair NÃO precisa de flag: um .pbp como entrada é extraído
      dd="$WORK/$tag"; mkdir -p "$dd"
      "$PSX" -i "$path" -o "$dd" -x -v 1 >"$dd/.log" 2>&1 || { echo "[ERRO] falha ao extrair: $path" >&2; sed 's/^/    /' "$dd/.log" >&2; return 1; }
      local c; c="$(find "$dd" -maxdepth 1 -iname '*.cue' | sort | head -n1)"
      [ -n "$c" ] || { echo "[ERRO] nenhum .cue extraído de $path" >&2; return 1; }
      printf '%s' "$c" ;;
  esac
}

# Roda o psxpackager em $1 (cue ou m3u) e move o resultado para $2 (caminho final do .PBP).
pack() {
  local input="$1" final="$2" out="$WORK/out.$RANDOM" produced
  mkdir -p "$out"
  if ! "$PSX" -i "$input" -o "$out" -l "$LEVEL" -x -v 1 >"$out.log" 2>&1; then
    echo "[ERRO] o psxpackager falhou: ${final##*/}"; sed 's/^/    /' "$out.log"; rm -rf "$out" "$out.log"; return 1
  fi
  rm -f "$out.log"
  produced="$(find "$out" -maxdepth 1 -iname '*.pbp' | head -n1)"
  if [ -z "$produced" ] || ! valid_pbp "$produced"; then
    echo "[ERRO] nenhum PBP válido gerado: ${final##*/}"; rm -rf "$out"; return 1
  fi
  cp -- "$produced" "$final.part" && mv -f -- "$final.part" "$final" || { echo "[ERRO] não foi possível gravar $final"; rm -f "$final.part"; rm -rf "$out"; return 1; }
  rm -rf "$out"; valid_pbp "$final"
}

# Verificação real antes de apagar qualquer coisa: extrai o ÚLTIMO disco do PBP unificado.
# Medido com o PSXPackager 1.6.2: um PBP multidisco extrai como "<name> - Disc N.cue", enquanto um
# PBP de disco ÚNICO ignora "-d 2" e extrai seu único disco (sem esse sufixo). Portanto exigir
# o sufixo " - Disc N" é o que prova que o PBP realmente tem N discos.
verify_discs() {                   # final ndiscos
  local v="$WORK/verify.$RANDOM"; mkdir -p "$v"
  "$PSX" -i "$1" -o "$v" -d "$2" -x -v 1 >/dev/null 2>&1
  local ok=1
  [ -n "$(find "$v" -maxdepth 1 -iname "* - Disc $2.cue" | head -n1)" ] || ok=0
  rm -rf "$v"; [ "$ok" = 1 ]
}

delete_sources() {                 # lista de "tipo<TAB>caminho" na entrada padrão
  local type path f
  while IFS=$'\t' read -r type path; do
    [ -n "$path" ] || continue
    case "$type" in
      cue)
        while IFS= read -r f; do
          [ -f "${path%/*}/$f" ] && ! protected "$f" && rm_file "${path%/*}/$f"
        done < <(cue_files "$path")
        rm_file "$path" ;;
      chd|pbp) rm_file "$path" ;;
    esac
  done
}

delete_disc_covers() {             # pasta, depois os nomes-base dos discos juntados
  local dir="$1" b e; shift
  for b in "$@"; do
    for e in png jpg jpeg PNG JPG JPEG; do [ -f "$dir/$b.$e" ] && rm_file "$dir/$b.$e"; done
  done
}

move_cover() {                     # mantém a capa do Disco 1 como a capa do jogo unificado
  local dir="$1" key="$2" first="$3" e
  for e in png jpg jpeg PNG JPG JPEG; do
    if [ -f "$dir/$first.$e" ] && [ ! -e "$dir/$key.png" ] && [ ! -e "$dir/$key.jpg" ] && [ ! -e "$dir/$key.jpeg" ]; then
      echo "  [capa] $first.$e -> $key.$e"
      [ "$DRY" = 1 ] || cp -- "$dir/$first.$e" "$dir/$key.$e"
    fi
  done
}

# ---------------------------------------------------------------- lógica por jogo
convert_single() {                 # pasta base tipo caminho
  local dir="$1" base="$2" type="$3" path="$4" cue final="$1/$2.PBP"
  if existing_pbp "$dir/$base" >/dev/null && valid_pbp "$(existing_pbp "$dir/$base")"; then
    echo "[pular] $base (PBP já existe)"; N_SKIP=$((N_SKIP+1))
    [ "$DELETE" = 1 ] && delete_sources <<< "$type"$'\t'"$path"
    return
  fi
  echo "[converter] $base"
  [ "$DRY" = 1 ] && return
  cue="$(prep_source "$type" "$path" "s.$RANDOM")" || { N_ERR=$((N_ERR+1)); return; }
  if pack "$cue" "$final"; then
    N_OK=$((N_OK+1))
    [ "$DELETE" = 1 ] && delete_sources <<< "$type"$'\t'"$path"
  else
    N_ERR=$((N_ERR+1)); echo "[manter] originais de $base mantidos (sem PBP válido)"
  fi
}

merge_group() {                    # pasta chave nums... (usa BEST_T / BEST_P)
  local dir="$1" key="$2"; shift 2
  local nums=("$@") n final="$dir/$key.PBP" m3u cue tag total
  total=${#nums[@]}
  local srcs="" need=0 sz first=""
  # contíguo 1..N?
  local want=1 contiguous=1
  for n in "${nums[@]}"; do [ "$n" = "$want" ] || contiguous=0; want=$((want+1)); done
  if [ "$contiguous" = 0 ] && [ "$FORCE" = 0 ]; then
    echo "[AVISO] $key: discos encontrados: ${nums[*]} (não é 1..$total). Não juntado. Use --force-partial para juntar mesmo assim."
    N_SKIP=$((N_SKIP+1)); return
  fi
  local bases=()
  for n in "${nums[@]}"; do
    srcs+="${BEST_T[$n]}"$'\t'"${BEST_P[$n]}"$'\n'
    bases+=("$(basename "${BEST_P[$n]%.*}")")
    [ -z "$first" ] && first="${bases[0]}"
  done

  if existing_pbp "$dir/$key" >/dev/null && valid_pbp "$(existing_pbp "$dir/$key")"; then
    final="$(existing_pbp "$dir/$key")"
    echo "[pular] $key (PBP unificado já existe)"; N_SKIP=$((N_SKIP+1))
    if [ "$DELETE" = 1 ]; then
      if [ "$DRY" = 1 ] || verify_discs "$final" "$total"; then
        delete_sources <<< "$srcs"; delete_disc_covers "$dir" "${bases[@]}"
      else
        echo "[manter] $key.PBP não contém $total discos; originais mantidos"
      fi
    fi
    return
  fi

  echo "[juntar] $key ($total discos: ${nums[*]})"
  for n in "${nums[@]}"; do echo "  disco $n <- ${BEST_P[$n]##*/} (${BEST_T[$n]})"; done
  [ "$DRY" = 1 ] && { move_cover "$dir" "$key" "$first"; return; }

  # checagem de espaço livre (extrair pbp/chd ocupa muito mais que o arquivo compactado)
  for n in "${nums[@]}"; do
    case "${BEST_T[$n]}" in
      cue) while IFS= read -r sz; do [ -f "$dir/$sz" ] && need=$((need + $(stat -c %s "$dir/$sz")/1024)); done < <(cue_files "${BEST_P[$n]}") ;;
      *) need=$((need + $(stat -c %s "${BEST_P[$n]}")/1024*3)) ;;
    esac
  done
  if [ "$(avail_kb)" -lt "$need" ]; then
    echo "[ERRO] $key: precisa de ~$((need/1024)) MB em $WORK, só $(( $(avail_kb)/1024 )) MB livres (defina PSX_TMP)"
    N_ERR=$((N_ERR+1)); return
  fi

  m3u="$WORK/$key.m3u"; : > "$m3u"
  for n in "${nums[@]}"; do
    tag="d$n.$RANDOM"
    cue="$(prep_source "${BEST_T[$n]}" "${BEST_P[$n]}" "$tag")" || { echo "[ERRO] $key: disco $n falhou"; N_ERR=$((N_ERR+1)); return; }
    printf '%s\n' "$cue" >> "$m3u"
  done
  if pack "$m3u" "$final"; then
    N_OK=$((N_OK+1)); move_cover "$dir" "$key" "$first"
    if [ "$DELETE" = 1 ]; then
      if verify_discs "$final" "$total"; then
        delete_sources <<< "$srcs"; delete_disc_covers "$dir" "${bases[@]}"
      else
        echo "[manter] $key.PBP falhou na verificação de $total discos; originais mantidos"
      fi
    fi
  else
    N_ERR=$((N_ERR+1)); echo "[manter] originais de $key mantidos (sem PBP válido)"
  fi
  rm -f "$m3u"
}

process_dir() {
  local dir="$1" f base ext lext type key n
  declare -A GROUP=()            # chave -> linhas "N<TAB>tipo<TAB>caminho"
  declare -A HASCUE=()           # base -> 1 (tem um .cue)
  local files=()
  while IFS= read -r -d '' f; do files+=("$f"); done < <(find "$dir" -maxdepth 1 -type f -print0 | sort -z)
  for f in "${files[@]}"; do
    base="$(basename "${f%.*}")"; ext="${f##*.}"; lext="${ext,,}"
    [[ "$base" == .* ]] && continue
    [ "$lext" = cue ] && HASCUE["$base"]=1
  done
  for f in "${files[@]}"; do
    base="$(basename "${f%.*}")"; ext="${f##*.}"; lext="${ext,,}"
    [[ "$base" == .* ]] && continue
    case "$lext" in cue|chd|pbp) ;; *) continue ;; esac
    if protected "$base"; then echo "[bios] ignorado ${f##*/}"; continue; fi
    type="$lext"
    [ "$type" = chd ] && [ -n "${HASCUE[$base]:-}" ] && continue   # o .cue vence o .chd
    if disc_parse "$base"; then key="$DISC_KEY"; n="$DISC_N"
    else
      [ "$type" = pbp ] && continue                                 # um PBP final de disco único: nada a fazer
      key="$base"; n=1
    fi
    GROUP["$key"]+="$n"$'\t'"$type"$'\t'"$f"$'\n'
  done

  local k
  [ "${#GROUP[@]}" -gt 0 ] || return 0          # pasta sem jogos
  while IFS= read -r -d '' k; do
    [ -n "$k" ] || continue
    local lines="${GROUP[$k]}" nums=() t p
    declare -A BEST_T=() BEST_P=()
    local curpri
    declare -A BEST_PRI=()
    while IFS=$'\t' read -r n t p; do
      [ -z "$n" ] && continue
      case "$t" in cue) curpri=3 ;; chd) curpri=2 ;; *) curpri=1 ;; esac
      if [ -z "${BEST_T[$n]:-}" ] || [ "$curpri" -gt "${BEST_PRI[$n]}" ]; then
        BEST_T[$n]="$t"; BEST_P[$n]="$p"; BEST_PRI[$n]=$curpri
      fi
    done <<< "$lines"
    mapfile -t nums < <(printf '%s\n' "${!BEST_T[@]}" | sort -n)
    if [ "${#nums[@]}" -ge 2 ] && [ "$MERGE" = 1 ]; then
      merge_group "$dir" "$k" "${nums[@]}"
    else
      for n in "${nums[@]}"; do
        [ "${BEST_T[$n]}" = pbp ] && continue
        p="${BEST_P[$n]}"
        convert_single "$dir" "$(basename "${p%.*}")" "${BEST_T[$n]}" "$p"
      done
    fi
    unset BEST_T BEST_P BEST_PRI
  done < <(printf '%s\0' "${!GROUP[@]}" | sort -z)
}

# ---------------------------------------------------------------- principal
echo "Pasta: $D  [dry-run=$DRY delete=$DELETE merge=$MERGE]"

# etapa 1: corrige as referências dos .cue (todas as pastas)
while IFS= read -r -d '' c; do fix_cue "$c"; done \
  < <(find "$D" -type f -iname '*.cue' -not -path '*/.*' -print0 | sort -z)

# etapa 2: converte / junta, pasta por pasta
while IFS= read -r -d '' d; do process_dir "$d"; done \
  < <(find "$D" -type d -not -path '*/.*' -print0 | sort -z)

# etapa 3: padroniza a extensão para .PBP (exFAT ignora maiúsculas, então passa por um nome temporário)
if [ "$DRY" = 0 ]; then
  while IFS= read -r -d '' f; do
    b="${f%.pbp}"; mv -- "$f" "$b.tmp_ren" && mv -- "$b.tmp_ren" "$b.PBP"
  done < <(find "$D" -type f -name '*.pbp' -not -path '*/.*' -print0)
fi

[ "$DELETE" = 1 ] || echo "[info] originais mantidos (use --delete para apagá-los depois de testar os PBPs)"
echo "== resumo: convertidos/juntados=$N_OK  ignorados=$N_SKIP  erros=$N_ERR  apagados=$N_DEL"
sync
ls -lh "$D"
[ "$N_ERR" = 0 ]
