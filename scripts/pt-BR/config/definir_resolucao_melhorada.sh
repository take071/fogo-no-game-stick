#!/usr/bin/env bash
# Liga/desliga a "Enhanced Resolution" (NEON) do PCSX-ReARMed. Faz backup antes.
# Uso: SD=/run/media/usuario/<NOME> ./definir_resolucao_melhorada.sh enabled|disabled|check
#   check  = só mostra as linhas neon e confere se cada uma está bem formada (chave = "valor")
#            (o doc 03 relatou uma linha que perdeu a aspa final: isto a encontra)
set -u
: "${SD:?defina SD}"; V="${1:?enabled|disabled|check}"
case "$V" in enabled|disabled|check) ;; *) echo "use enabled, disabled ou check"; exit 1 ;; esac
F="$SD/retro_lib/retroarch-core-options.cfg"
[ -f "$F" ] || { echo "[erro] $F não encontrado"; exit 1; }

check() {
  local bad
  grep -n 'neon' "$F"
  bad=$(grep 'neon' "$F" | grep -vcE '^[A-Za-z0-9_]+ = ".*"[[:space:]]*$')
  if [ "$bad" != 0 ]; then echo "[AVISO] $bad linha(s) neon não estão no formato chave = \"valor\" (aspa faltando?)"; return 1; fi
  echo "[ok] todas as linhas neon estão bem formadas"
}

[ "$V" = check ] && { check; exit $?; }
grep -q '^pcsx_rearmed_neon_enhancement_enable = ' "$F" || { echo "[erro] chave pcsx_rearmed_neon_enhancement_enable não encontrada; nada foi alterado"; exit 1; }
[ -e "$F.bak_pre_neon" ] || cp "$F" "$F.bak_pre_neon"
sed -i "s/^pcsx_rearmed_neon_enhancement_enable = .*/pcsx_rearmed_neon_enhancement_enable = \"$V\"/" "$F"
grep -q "^pcsx_rearmed_neon_enhancement_enable = \"$V\"\$" "$F" || { echo "[erro] a alteração não foi aplicada; backup: $F.bak_pre_neon"; exit 1; }
check; rc=$?; sync; exit $rc
