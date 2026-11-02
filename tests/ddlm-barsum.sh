#!/usr/bin/env bash
# Every measure of each song read from PDF adds up to its time signature
# (#4: "Every measure must sum to its time signature"), counted from the
# notes by muertos/tools/barsum.py -- stdlib only, so it runs in dexter/tests,
# which has neither PyMuPDF nor LilyPond. It does not take pdf2ly.py's word
# for it: a "% CHECK" comment is the reader's own report, and a hand edit
# can drop it. A song is checked when it is one of the five #4 read, or when
# it says it came from muertos/tools/pdf2ly.py; a named song that is missing
# is red, not skipped.
#
# Red on each injected failure, which must also be red with the checker
# removed: a short measure with no CHECK comment, a dropped \tuplet, a bad
# multi-measure rest, a token the checker cannot read (BLIND, never a pass).
set -uo pipefail
root=$(git rev-parse --show-toplevel)
bs="$root/muertos/tools/barsum.py"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
fail=0
expect() {  # expect NAME RC FILE [GREP]: barsum.py on FILE exits RC (and says GREP)
  python3 -I "$bs" "$3" >"$t/out" 2>&1; local rc=$?
  if [ "$rc" != "$2" ]; then echo "FAIL: $1: rc=$rc, want $2:"; cat "$t/out"; fail=1
  elif [ -n "${4:-}" ] && ! grep -qF -- "$4" "$t/out"; then echo "FAIL: $1: no [$4]:"; cat "$t/out"; fail=1
  else echo "ok: $1"; fi
}

# The songs: the five #4 read, plus any other file pdf2ly.py wrote.
songs=()
for s in get_my_sound le_chant_des_partisans rin_de_angelito tabu voodoo; do
  songs+=("$root/muertos/$s.ly")
done
for f in "$root"/muertos/*.ly; do
  grep -qF 'muertos/tools/pdf2ly.py' "$f" || continue
  case " ${songs[*]} " in *" $f "*) ;; *) songs+=("$f") ;; esac
done
for f in "${songs[@]}"; do
  expect "$(basename "$f"): every measure adds up" 0 "$f" "measures add up"
  if grep -qF '% CHECK' "$f" 2>/dev/null; then echo "FAIL: $(basename "$f"): carries a % CHECK measure"; fail=1; fi
done

# Injected failures, built from a small song in the shape pdf2ly.py writes.
cat >"$t/good.ly" <<'EOF'
x-accompaniment = \transpose c' f {
  \compressEmptyMeasures
  % m1
  \clef "treble" \key f \major \time 4/4 \partial 4 \tempo 4 = 120 c'4^\markup "go" |
  % m2
  \mark \markup \box "A" g'4 bes'2. |
  % m3
  c''8 d''8 r4 fis'2~ |
  \bar ".|:"
  % m4
  \set Score.repeatCommands = #'((volta "1.")) fis'4 \tuplet 3/2 { g'8 a' bes' } <c' e' g'>2\mf |
  % m5-7
  R1*3 |
  % m8
  \time 3/4 c'4 d' e'-. |
  \bar "|."
}
EOF
expect "good: adds up (partial, tuplet, R1*3, duration memory, 3/4)" 0 "$t/good.ly" "8 measures add up"

sed 's/ g.4 bes.2\. |$/ g'"'"'4 bes'"'"'2 |/' "$t/good.ly" >"$t/short.ly"
expect "short measure, no CHECK comment: red" 1 "$t/short.ly" "m2 (line 6): sums to 3/4, time is 4/4"

sed 's/\\tuplet 3\/2 { \(g.8 a. bes.\) }/\1/' "$t/good.ly" >"$t/notuplet.ly"
expect "dropped tuplet: red" 1 "$t/notuplet.ly" "m4 (line 11): sums to 9/8"

sed 's/R1\*3/R2*3/' "$t/good.ly" >"$t/mrest.ly"
expect "multi-measure rest of 3/2: red" 1 "$t/mrest.ly" "sums to 3/2, time is 4/4"

sed 's/\\partial 4 //' "$t/good.ly" >"$t/nopartial.ly"
expect "short first measure without \\partial: red" 1 "$t/nopartial.ly" "m1 (line 4): sums to 1/4"

sed 's/\\compressEmptyMeasures/\\unknownThing/' "$t/good.ly" >"$t/blind.ly"
expect "unknown token: BLIND, not a pass" 2 "$t/blind.ly" "BLIND:"

expect "missing song: BLIND, not a pass" 2 "$t/no-such-song.ly" "BLIND:"

# The deploy path: muertos/build.sh (which publish.sh runs) stops on a song
# read from PDF whose measure does not add up, before LilyPond runs -- whose
# bar check only warns. Built from a copy, one measure of tabu.ly cut short.
cp -r "$root/muertos" "$t/m"
sed -i '0,/^  c.1 |$/s//  c'"'"'2 |/' "$t/m/tabu.ly"
if cmp -s "$root/muertos/tabu.ly" "$t/m/tabu.ly"; then
  echo "FAIL: build gate: could not inject the short measure into tabu.ly"; fail=1
else
  bash "$t/m/build.sh" "$t/out" >"$t/build.out" 2>&1; rc=$?
  if [ "$rc" != 0 ] && grep -qF 'tabu.ly: m3 (line 19): sums to 1/2, time is 4/4' "$t/build.out" \
     && grep -qF 'does not add up' "$t/build.out"; then
    echo "ok: build gate: build.sh stops on tabu.ly m3"
  else
    echo "FAIL: build gate: build.sh rc=$rc without naming tabu.ly m3:"; cat "$t/build.out"; fail=1
  fi
fi

exit $fail
