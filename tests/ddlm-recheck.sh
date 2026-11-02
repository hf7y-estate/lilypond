#!/usr/bin/env bash
# muertos/tools/recheck.py says whether a card voice still matches its
# source (#7). This test runs it on event lists in ly-events.ily's TSV form
# (stdlib only: no LilyPond, no PyMuPDF, no source PDFs, which are other
# people's arrangements and stay off this repo). Green: the same notes, the
# card a fifth and an octave away, and a card that carries only part of the
# source. Each injected failure must be red and name the card measure: a
# changed pitch, a changed rhythm, a rest where the source has a note, an
# extra card note. Unreadable input is BLIND (exit 2), never green.
# It also checks muertos/recheck.tsv names only songs that are in the book,
# and that muertos/recheck.sh with no sources says BLIND.
set -uo pipefail
root=$(git rev-parse --show-toplevel)
r="$root/muertos/tools/recheck.py"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
fail=0

expect() {  # expect NAME RC PATTERN -- recheck.py ARGS...
  local name=$1 want=$2 pat=$3; shift 4
  python3 -I "$r" "$@" >"$t/out" 2>&1; local got=$?
  if [ "$got" = "$want" ] && grep -qE -- "$pat" "$t/out"; then
    echo "ok: $name"
  else
    echo "FAIL: $name: rc=$got (want $want), want /$pat/ in:"; sed 's/^/  /' "$t/out"; fail=1
  fi
}

ev() {  # ev FILE VOICE [SHIFT]: write the stdin rows "bar pos kind midi len" as TSV
  local shift=${3:-0}
  awk -v v="$2" -v s="$shift" 'NF { p = ($4 == "-") ? "-" : $4 + s;
    printf "%s\t%s\t1\t%s\t%s\t%s\t%s\n", $1, $2, $3, p, $5, v }' >"$1"
}

src='1 0 note 67 1/4
1 1/4 note 70 3/4
2 0 note 72 1/8
2 1/8 note 74 1/8
2 1/4 rest - 1/4
2 1/2 note 66 1/2
3 0 note 67 1
4 0 note 62 1/4
4 0 note 65 1/4
4 1/4 rest - 3/4'
echo "$src" | ev "$t/src.tsv" pdf

# Green
echo "$src" | ev "$t/same.tsv" Voice:a
expect "same notes" 0 "^ok: card voice 1: 9/9 tokens" -- "$t/same.tsv" 1 "$t/src.tsv"
echo "$src" | ev "$t/fifth.tsv" Voice:a 19
expect "a fifth and an octave up" 0 "^ok: .*9/9 tokens match the source \(transposed 5 semitones" -- "$t/fifth.tsv" 1 "$t/src.tsv"
echo "$src" | sed -n 1,6p | ev "$t/part.tsv" Voice:a
expect "card carries part of the source" 0 "^pdf only: pdf m3-4" -- "$t/part.tsv" 1 "$t/src.tsv"
echo "$src" | ev "$t/vb.tsv" Voice:b; echo "$src" | ev "$t/va.tsv" Voice:a 2
cat "$t/vb.tsv" "$t/va.tsv" >"$t/two.tsv"
expect "voice 2 of two" 0 "^ok: card voice 2: 9/9" -- "$t/two.tsv" 2 "$t/src.tsv"

# Injected
echo "$src" | sed 's/^2 1\/2 note 66 1\/2$/2 1\/2 note 65 1\/2/' | ev "$t/pitch.tsv" Voice:a
expect "changed pitch is red" 1 "^DIFF: card m2 / pdf m2: card \[f:1/2\] pdf \[fis:1/2\]" -- "$t/pitch.tsv" 1 "$t/src.tsv"
expect "changed pitch: verdict" 1 "^RED: card voice 1: 8/9" -- "$t/pitch.tsv" 1 "$t/src.tsv"
echo "$src" | sed 's/^1 1\/4 note 70 3\/4$/1 1\/4 note 70 1\/2/' | ev "$t/rhythm.tsv" Voice:a
expect "changed rhythm is red" 1 "^DIFF: card m1 / pdf m1: card \[bes:1/2\] pdf \[bes:3/4\]" -- "$t/rhythm.tsv" 1 "$t/src.tsv"
echo "$src" | sed 's/^3 0 note 67 1$/3 0 rest - 1/' | ev "$t/rest.tsv" Voice:a
expect "rest for a note is red" 1 "^DIFF: card m3 / pdf m3" -- "$t/rest.tsv" 1 "$t/src.tsv"
{ echo "$src"; echo '5 0 note 60 1'; } | ev "$t/extra.tsv" Voice:a
expect "extra card note is red" 1 "^DIFF: card m5 / pdf -" -- "$t/extra.tsv" 1 "$t/src.tsv"
expect "--allow 1 takes one known difference" 0 "^ok: .*1 differ, 1 allowed" -- "$t/pitch.tsv" 1 "$t/src.tsv" --allow 1
echo "$src" | sed 's/^2 1\/2 note 66 1\/2$/2 1\/2 note 65 1\/2/; s/^1 1\/4 note 70 3\/4$/1 1\/4 note 70 1\/2/' | ev "$t/two-diffs.tsv" Voice:a
expect "--allow 1 is not two" 1 "^RED: .*2 differ, 1 allowed" -- "$t/two-diffs.tsv" 1 "$t/src.tsv" --allow 1

# Blind
expect "missing card file" 2 "^BLIND: .*No such file" -- "$t/nope.tsv" 1 "$t/src.tsv"
expect "missing source PDF" 2 "^BLIND: .*no such file" -- "$t/same.tsv" 1 "$t/nope.pdf:1"
expect "no voice 2" 2 "^BLIND: .*no voice 2" -- "$t/same.tsv" 2 "$t/src.tsv"
printf '1\t0\t1\tnote\t60\n' >"$t/short.tsv"
expect "short line" 2 "^BLIND: .*5 fields" -- "$t/short.tsv" 1 "$t/src.tsv"
echo '1 0 rest - 1' | ev "$t/rests.tsv" Voice:a
expect "no notes" 2 "^BLIND: no notes" -- "$t/rests.tsv" 1 "$t/src.tsv"

# recheck.tsv rows name songs in the book; recheck.sh without sources is BLIND.
rows=0
while IFS=$'\t' read -r song pdf staff voice allow extra; do
  case $song in ''|'#'*) continue ;; esac
  rows=$((rows + 1))
  if [ -z "$allow" ] || [ -n "${extra:-}" ] || ! [[ $staff$voice$allow =~ ^[0-9]+$ ]] || [ "${pdf%.pdf}" = "$pdf" ]; then
    echo "FAIL: recheck.tsv row $rows: bad fields: $song|$pdf|$staff|$voice|$allow"; fail=1
  elif [ ! -f "$root/muertos/$song.ly" ] || ! grep -qx "\\\\$song-card" "$root/muertos/Book.ly"; then
    echo "FAIL: recheck.tsv row $rows: $song is not a card in muertos/Book.ly"; fail=1
  fi
done <"$root/muertos/recheck.tsv"
if [ "$rows" -ge 9 ]; then echo "ok: recheck.tsv has $rows rows"; else echo "FAIL: recheck.tsv has $rows rows"; fail=1; fi
DDLM_SOURCES="$t/none" bash "$root/muertos/recheck.sh" >"$t/sh.out" 2>&1; rc=$?
if [ $rc = 2 ] && grep -q '^BLIND: no sources' "$t/sh.out"; then echo "ok: recheck.sh without sources is BLIND"
else echo "FAIL: recheck.sh without sources: rc=$rc"; cat "$t/sh.out"; fail=1; fi

[ $fail = 0 ] && echo "ddlm-recheck: all ok"
exit $fail
