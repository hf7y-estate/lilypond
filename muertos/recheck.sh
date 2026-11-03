#!/usr/bin/env bash
# muertos/recheck.sh [SONG...] -- check the hand-entered cards against this
# year's source PDFs (#7). For each row of recheck.tsv it compiles the
# song's card with tools/ly-events.ily, which lists every note LilyPond
# engraves, then has tools/recheck.py line that voice up with pdf2ly's
# reading of the source staff. Red (exit 1) names each card measure that
# no longer matches the PDF; fix it toward the PDF, or, if the reading is
# wrong, say why in recheck.tsv. BLIND (exit 2): no sources, no LilyPond,
# no PyMuPDF, a card that does not compile, a song not in the book or not
# in recheck.tsv, or recheck.py failing in any other way.
# Needs the host that holds the sources: DDLM_SOURCES, default
# ~/ddlm-sources/2026/_DAY OF THE DEAD (never committed: other people's
# arrangements).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src=${DDLM_SOURCES:-$HOME/ddlm-sources/2026/_DAY OF THE DEAD}
blind() { echo "BLIND: $*"; exit 2; }
[ -d "$src" ] || blind "no sources at $src"
command -v lilypond >/dev/null || blind "no lilypond"
python3 -I -c 'import pymupdf' 2>/dev/null || blind "no PyMuPDF (python3-pymupdf)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

events() {  # events SONG: $work/SONG.tsv from the song's card
  grep -qx "\\\\$1-card" "$here/Book.ly" || blind "$1: no \\$1-card in Book.ly"
  { printf '#(define ly-events-file "%s")\n' "$work/$1.tsv"
    sed '/^\\[A-Za-z_]*-card$/d' "$here/Book.ly"
    printf '\\include "tools/ly-events.ily"\n'
    # a song whose melody prints as a system of its own below the part
    # (santa_sangre, #25) has it in <song>-melody: its voices come after
    # the part's
    if grep -q "^$1-melody *=" "$here/$1.ly"; then music="<< \\$1-accompaniment \\$1-melody >>"
    else music="\\$1-accompaniment"; fi
    printf "\\\\score { \\\\unfoldRepeats #'(percent) \\\\removeWithTag #'phone \\\\transpose f c' %s }\n" "$music"
  } >"$work/$1.ly"
  if ! lilypond -I "$here" -o "$work/$1" "$work/$1.ly" >"$work/$1.log" 2>&1 \
     || grep -q 'error:' "$work/$1.log"; then
    tail -20 "$work/$1.log"; blind "$1: card does not compile"
  fi
}

rc=0 rows=0 done_songs=()
while IFS=$'\t' read -r song pdf staff voice allow; do
  case $song in ''|'#'*) continue ;; esac
  if [ $# -gt 0 ] && ! printf '%s\n' "$@" | grep -qx "$song"; then continue; fi
  [ -s "$work/$song.tsv" ] || events "$song"
  echo "== $song voice $voice / $pdf staff $staff"
  python3 -I "$here/tools/recheck.py" "$work/$song.tsv" "$voice" "$src/$pdf:$staff" --allow "$allow"
  r=$?
  case $r in 0|1) ;; *) echo "BLIND: recheck.py exit $r"; r=2 ;; esac
  [ $r -le $rc ] || rc=$r
  rows=$((rows + 1))
  done_songs+=("$song")
done <"$here/recheck.tsv"
[ $rows -gt 0 ] || blind "no row of recheck.tsv matches: $*"
for s in "$@"; do
  printf '%s\n' "${done_songs[@]}" | grep -qx -- "$s" || blind "$s: no row in recheck.tsv"
done
case $rc in 0) echo "recheck.sh: $rows voices match their source" ;;
            1) echo "recheck.sh: RED, a card no longer matches its source (above)" ;; esac
exit $rc
