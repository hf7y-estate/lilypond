#!/usr/bin/env bash
# muertos/chords.sh [--write] [SONG...] -- are the cards' chord symbols
# still what this year's source PDFs say (#6)? For each row of chords.tsv
# it compiles the song's accompaniment at concert pitch with
# tools/ly-onsets.ily, has tools/pdfchords.py read the PDF's chord symbols
# and place them on that card, and compares the result with the committed
# chords/<song>.ily.
# Green (exit 0): every file matches. Red (exit 1): a file differs from the
# PDF (the diff is printed) or is missing; --write rewrites it, then commit
# the change. BLIND (exit 2): no sources, no LilyPond, no PyMuPDF, a song
# that does not compile or has no row, a chord symbol pdfchords.py cannot
# spell, or pdfchords.py failing in any other way.
# Needs the host that holds the sources: DDLM_SOURCES, default
# ~/ddlm-sources/2026/_DAY OF THE DEAD (never committed: other people's
# arrangements).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
src=${DDLM_SOURCES:-$HOME/ddlm-sources/2026/_DAY OF THE DEAD}
write=
[ "${1:-}" = --write ] && { write=1; shift; }
blind() { echo "BLIND: $*"; exit 2; }
[ -d "$src" ] || blind "no sources at $src"
command -v lilypond >/dev/null || blind "no lilypond"
python3 -I -c 'import pymupdf' 2>/dev/null || blind "no PyMuPDF (python3-pymupdf)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

onsets() {  # onsets SONG: $work/SONG.tsv, the accompaniment at concert pitch
  [ -f "$here/$1.ly" ] || blind "$1: no $1.ly"
  { printf '#(define ly-onsets-file "%s")\n' "$work/$1.tsv"
    printf '\\include "Phone.ly"\n\\include "Style.ily"\n\\include "%s.ly"\n' "$1"
    printf '\\include "tools/ly-onsets.ily"\n'
    printf "\\\\score { \\\\unfoldRepeats #'(percent) \\\\removeWithTag #'phone \\\\%s-accompaniment }\n" "$1"
  } >"$work/$1-onsets.ly"   # not $1.ly: it would \include itself
  if ! lilypond -I "$here" -o "$work/$1" "$work/$1-onsets.ly" >"$work/$1.log" 2>&1 \
     || grep -q 'error:' "$work/$1.log"; then
    tail -20 "$work/$1.log"; blind "$1: accompaniment does not compile"
  fi
}

rc=0 rows=0 done_songs=()
while IFS=$'\t' read -r song pdf staff voice; do
  case $song in ''|'#'*) continue ;; esac
  if [ $# -gt 0 ] && ! printf '%s\n' "$@" | grep -qx "$song"; then continue; fi
  rows=$((rows + 1)); done_songs+=("$song")
  echo "== $song / $pdf"
  onsets "$song"
  python3 -I "$here/tools/pdfchords.py" "$work/$song.tsv" "$voice" "$src/$pdf:$staff" \
    --song "$song" --label "\"$(basename "$pdf")\"" >"$work/$song.ily" 2>"$work/$song.err"
  r=$?
  sed 's/^/  /' "$work/$song.err"
  if [ $r != 0 ]; then
    cat "$work/$song.ily"; echo "BLIND: pdfchords.py exit $r on $song"; rc=2; continue
  fi
  have="$here/chords/$song.ily"
  if [ -f "$have" ] && cmp -s "$have" "$work/$song.ily"; then
    echo "ok: chords/$song.ily matches the PDF ($(grep -c '^	[a-g]' "$have") chords)"
  elif [ -n "$write" ]; then
    mkdir -p "$here/chords"; cp "$work/$song.ily" "$have"
    echo "WROTE: chords/$song.ily ($(grep -c '^	[a-g]' "$have") chords); commit it"
  else
    if [ -f "$have" ]; then diff -u "$have" "$work/$song.ily" | sed 's/^/  /'
    else echo "  no chords/$song.ily"; fi
    echo "RED: chords/$song.ily is not what the PDF says (chords.sh --write $song)"
    [ $rc = 2 ] || rc=1
  fi
done <"$here/chords.tsv"
[ $rows -gt 0 ] || blind "no row of chords.tsv matches: $*"
for s in "$@"; do
  printf '%s\n' "${done_songs[@]}" | grep -qx -- "$s" || blind "$s: no row in chords.tsv"
done
case $rc in 0) echo "chords.sh: $rows songs' chords match their source" ;;
            1) echo "chords.sh: RED, chords differ from their source (above)" ;; esac
exit $rc
