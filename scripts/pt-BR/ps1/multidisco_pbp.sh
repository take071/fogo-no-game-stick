#!/usr/bin/env bash
# Junta vários PBPs de disco único em UM PBP multi-disco (via .m3u).
# STATUS: testado num jogo multi-disco real e funcionou (relato do autor; veja doc 01).
# No PSXPackager 1.6.2 NÃO existe flag de extração: passar um .pbp em -i já o
# extrai para .bin/.cue, e um .m3u em -i monta um PBP multi-disco.
# CUIDADO: "-x" significa "sobrescrever sem perguntar", NÃO "extrair".
# Guarde os PBPs originais até testar o resultado no stick.
#
# Uso:
#   SD=/run/media/user/<LABEL> PSX=/caminho/do/psxpackager \
#   NAME="Tales of Destiny II (USA)" DISCS=3 ./multidisco_pbp.sh
# Espera: "$SD/game/ps1/<NAME> (Disc 1).PBP" ... "(Disc N).PBP"
set -u
: "${SD:?defina SD}"; : "${PSX:?defina PSX}"; : "${NAME:?defina NAME}"
DISCS="${DISCS:-3}"
D="$SD/game/ps1"; TMP="$D/_tmp_multidisc"
cd "$D" || exit 1
mkdir -p "$TMP"

# 1) extrai cada disco para bin/cue
for n in $(seq 1 "$DISCS"); do
  mkdir -p "$TMP/d$n"
  "$PSX" -i "$D/$NAME (Disc $n).PBP" -o "$TMP/d$n" || { echo "[ERRO] disco $n"; exit 1; }
done
find "$TMP" -type f

# 2) monta o .m3u com os .cue, em ordem
: > "$TMP/$NAME.m3u"
for n in $(seq 1 "$DISCS"); do
  c=$(find "$TMP/d$n" -iname '*.cue' | head -n1)
  [ -n "$c" ] || { echo "[ERRO] sem .cue para o disco $n"; exit 1; }
  echo "$c" >> "$TMP/$NAME.m3u"
done
cat "$TMP/$NAME.m3u"

# 3) empacota em um PBP multi-disco
"$PSX" -i "$TMP/$NAME.m3u" -o "$TMP/out"
ls -lh "$TMP/out"
echo "Confira o resultado e depois mova-o você mesmo para $D. Nada foi apagado."
