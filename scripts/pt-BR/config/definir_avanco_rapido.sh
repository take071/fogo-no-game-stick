#!/usr/bin/env bash
# Altera o fastforward_ratio usado nos jogos de GBA (arquivo timer/gbx_mod.cfg no cartão).
# Uso: SD=/run/media/usuario/<NOME> ./definir_avanco_rapido.sh 2.5      (0 = desligado)
# Aceita "2.5" ou "2,5". O número é sempre gravado com ponto, seja qual for o idioma do sistema
# (em pt_BR o printf pode usar vírgula, o que quebraria o .cfg).
set -u
: "${SD:?defina SD}"; V="${1:?informe um valor, ex.: 2.5}"
[[ $V =~ ^[0-9]+([.,][0-9]+)?$ ]] || { echo "[erro] '$V' não é um número (use por ex. 2.5)"; exit 1; }
V="${V/,/.}"
F="$SD/timer/gbx_mod.cfg"
[ -f "$F" ] || { echo "[erro] $F não encontrado"; exit 1; }
grep -q '^fastforward_ratio = ' "$F" || { echo "[erro] não há linha 'fastforward_ratio = ' em $F; nada foi alterado"; exit 1; }
[ -e "$F.bak_pre_ff" ] || cp "$F" "$F.bak_pre_ff"
VAL=$(LC_ALL=C printf '%.6f' "$V")
sed -i "s/^fastforward_ratio = .*/fastforward_ratio = \"$VAL\"/" "$F"
grep -q "^fastforward_ratio = \"$VAL\"\$" "$F" || { echo "[erro] a alteração não foi aplicada; backup: $F.bak_pre_ff"; exit 1; }
grep -n '^fastforward_ratio' "$F"; sync
