#!/usr/bin/env bash
# muertos/tools/pdf2ly.py reads a MuseScore-drawn PDF into LilyPond. It
# reads tests/pdf2ly-fixture.py's two-measure PDF (the real sources are other
# people's arrangements and stay out of the repo), and is red on each
# injected failure: a dropped beam must show as a "% CHECK" measure that
# does not add up (never silently fixed), a dropped sharp as the natural
# note, a dropped dot as a CHECK; --compare must give 100% for a part
# against itself and less for an altered one. The ddlm song files must carry
# no CHECK measure.
# Needs python3 with PyMuPDF (python3-pymupdf). Without it, it says SKIP and
# checks nothing.
set -uo pipefail
root=$(git rev-parse --show-toplevel)
if ! python3 -I -c 'import pymupdf' 2>/dev/null; then
  echo "SKIP: no PyMuPDF (python3-pymupdf); nothing checked"
  exit 0
fi
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
fail=0
fx="$root/tests/pdf2ly-fixture.py"
r="$root/muertos/tools/pdf2ly.py"
has()  { if grep -qF -- "$2" "$3"; then echo "ok: $1"; else echo "FAIL: $1: no [$2] in $3:"; cat "$3"; fail=1; fi; }
hasnt(){ if grep -qF -- "$2" "$3"; then echo "FAIL: $1: [$2] in $3"; fail=1; else echo "ok: $1"; fi; }

read_fx() {  # read_fx NAME [--no-X]: fixture -> $t/NAME.ly, stderr $t/NAME.err
  python3 -I "$fx" "$t/$1.pdf" "${@:2}" || { echo "FAIL: fixture $1"; fail=1; return; }
  python3 -I "$r" "$t/$1.pdf" --name fx >"$t/$1.ly" 2>"$t/$1.err" || { echo "FAIL: pdf2ly on $1"; cat "$t/$1.err"; fail=1; }
}

# Green: key, time, pitches from key and accidental, dotted half, beam, rest.
read_fx good
has  "good: m1"  "\\clef \"treble\" \\key f \\major \\time 4/4 g'4 bes'2. |" "$t/good.ly"
has  "good: m2"  "c''8 d''8 r4 fis'2 |" "$t/good.ly"
has  "good: final bar" '\bar "|."' "$t/good.ly"
hasnt "good: no CHECK" "CHECK" "$t/good.ly"
python3 -I "$r" "$t/good.pdf" --name fx --to-concert f >"$t/horn.ly" 2>/dev/null
has  "--to-concert wraps" "fx-accompaniment = \\transpose c' f {" "$t/horn.ly"

# Injected: no beam -> the eighths read as quarters; m2 is 5/4 and says so.
read_fx nobeam --no-beam
has  "no beam: CHECK in file" "% CHECK m2: sums to 5/4, time is 4/4" "$t/nobeam.ly"
has  "no beam: CHECK on stderr" "CHECK m2: sums to 5/4" "$t/nobeam.err"
has  "no beam: notes as read, not fixed" "c''4 d''4 r4 fis'2 |" "$t/nobeam.ly"

# Injected: no sharp -> F natural.
read_fx nosharp --no-sharp
has  "no sharp: f'2" "c''8 d''8 r4 f'2 |" "$t/nosharp.ly"

# Injected: no dot -> m1 is 3/4; a short first measure is a pickup.
read_fx nodot --no-dot
has  "no dot: pickup, reported" "m1: pickup of 3/4" "$t/nodot.err"
has  "no dot: \\partial" "\\partial 2." "$t/nodot.ly"

# --compare: same part, interval 0 -> 100%; altered part -> less.
python3 -I "$r" --compare "$t/good.pdf" "$t/good.pdf" --interval 0 >"$t/same.txt" 2>&1
has  "compare: same part 100%" "matched 6 = 100.0%" "$t/same.txt"
python3 -I "$r" --compare "$t/good.pdf" "$t/nosharp.pdf" --interval 0 >"$t/diff.txt" 2>&1
hasnt "compare: altered part below 100%" "= 100.0% (pitch+duration" "$t/diff.txt"

# The ddlm songs read by pdf2ly carry no unresolved CHECK measure.
for f in "$root"/muertos/*.ly; do
  grep -q 'muertos/tools/pdf2ly.py' "$f" || continue
  hasnt "$(basename "$f"): no CHECK measure" "% CHECK" "$f"
done

exit $fail
