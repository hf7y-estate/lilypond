#!/usr/bin/env bash
# Chord symbols from the source PDFs' text layer (#6). muertos/chords.sh
# reads each source PDF's chords with muertos/tools/pdfchords.py, places
# them on the card and is red when a committed chords/<song>.ily is not
# what the PDF says; build.sh builds the book with them (the main one,
# mellophone-*.pdf) and without (mellophone-nochords-*.pdf).
# This test needs no source PDFs (other people's arrangements, never in
# this repo) and no PyMuPDF: it runs pdfchords.py's spelling and placement
# on made-up readings. Green: a card that matches its source, and one a
# fifth lower with a pickup. Injected, each must not pass: a chord symbol
# it cannot spell (BLIND), a chord over music the card leaves out (left
# out and listed, not moved), two chords on one moment (BLIND), chords.sh
# with no sources (BLIND), publish.sh run for real while chords.sh is red
# or BLIND (refused, site repo untouched), index.sh naming a chords
# PDF the build lacks, chords.tsv out of step with Songs.ily and chords/.
# With lilypond and gs on PATH it also compiles a card both ways: chords
# in the written key with ddlmChords = ##t, none with ##f, and never the
# notes read as chords (a song whose music makes no Staff of its own).
set -uo pipefail
root=$(git rev-parse --show-toplevel)
m="$root/muertos"
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
fail=0
ok()   { echo "ok: $*"; }
bad()  { echo "FAIL: $*"; fail=1; }

# ---- spelling: the symbols the 2026 PDFs print -> \chordmode
want='B♭-	bes:m
D7/G	d:7/g
C#o	cis:dim
Abmin6	as:m6
Ebmaj7	es:maj7
Cmin7	c:m7
F-	f:m
Bb	bes
Dmin	d:m
G7	g:7'
got=$(python3 -I "$m/tools/pdfchords.py" --parse $(cut -f1 <<<"$want") 2>&1)
[ "$got" = "$want" ] && ok "chord spelling" || { bad "chord spelling:"; diff <(echo "$want") <(echo "$got"); }
for sym in 'C7#9' 'H7' 'Cmaj7/X'; do
  out=$(python3 -I "$m/tools/pdfchords.py" --parse "$sym" 2>&1); rc=$?
  if [ $rc = 2 ] && grep -q '^BLIND: chord symbol' <<<"$out"; then ok "unknown symbol $sym is BLIND"
  else bad "unknown symbol $sym: rc=$rc: $out"; fi
done

# ---- placement on made-up readings
cat >"$t/place.py" <<'PY'
import sys
from fractions import Fraction as F
sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[1])
import pdfchords as pc
case, tsv = sys.argv[2], sys.argv[3]
q = F(1, 4)
bars = [(60, 64, 67, 72), (65, 69, 72, 77), (67, 71, 74, 79)]
src = [(i + k * q, "n", (p,), q) for i, b in enumerate(bars) for k, p in enumerate(b)]
chords = [(F(0), "C"), (F(1), "F"), (F(2), "G7")]
if case in ("same", "twice"):
    rows = [(i + k * q, i + 1, p) for i, b in enumerate(bars) for k, p in enumerate(b)]
elif case == "fifth-pickup":      # concert pitch of an F part, after a 1/4 pickup rest
    rows = [(q + i + k * q, i + 1, p - 7) for i, b in enumerate(bars) for k, p in enumerate(b)]
elif case == "no-m2":             # the card leaves the source's m2 out
    rows = [(j + k * q, j + 1, p) for j, b in enumerate([bars[0], bars[2]]) for k, p in enumerate(b)]
with open(tsv, "w") as f:
    if case == "fifth-pickup":
        f.write(f"0\t1\trest\t-\t1/4\tVoice:a\n")
    for at, bar, p in rows:
        f.write(f"{at}\t{bar}\tnote\t{p}\t1/4\tVoice:a\n")
voices, end = pc.read_onsets(tsv)
card = list(voices.values())[0]
shift = pc.best_shift(src, card)
placed, skipped = pc.place(chords, pc.anchors(src, card, shift), end)
if case == "twice":
    placed = [(F(0), "C"), (F(0), "F")]
try:
    print(pc.emit("song", "test.pdf", placed, skipped, shift, end, card))
except pc.Blind as e:
    print(f"BLIND: {e}")
PY
place() { python3 -I "$t/place.py" "$m/tools" "$1" "$t/$1.tsv" 2>&1; }
body() { place "$1" | sed -n '/chordmode {$/,/^}$/p' | sed 's/  % / %/' | tr '\n\t' '| '; }

got=$(body same)
want='song-chords = \chordmode {| c1 %m1 C| f1 %m2 F| g1:7 %m3 G7|}|'
[ "$got" = "$want" ] && ok "same notes: chords on m1-3" || bad "same notes: got [$got] want [$want]"
got=$(body fifth-pickup)
want='song-chords = \transpose c f \chordmode {| s4| c1 %m1 C| f1 %m2 F| g1:7 %m3 G7|}|'
[ "$got" = "$want" ] && ok "a fifth lower, after a pickup" || bad "fifth-pickup: got [$got] want [$want]"
out=$(place no-m2)
if grep -q '^% left out: F at source moment 1: ' <<<"$out" && grep -q '1 left out' <<<"$out" \
   && [ "$(body no-m2)" = 'song-chords = \chordmode {| c1 %m1 C| g1:7 %m2 G7|}|' ]; then
  ok "chord over music the card leaves out: left out and listed, the rest placed"
else bad "chord over left-out music:"; echo "$out"; fi
out=$(place twice)
grep -q '^BLIND: two chords at card moment 0' <<<"$out" && ok "two chords on one moment is BLIND" \
  || { bad "two chords on one moment:"; echo "$out"; }

# ---- chords.sh without sources is BLIND; publish.sh refuses before any push
DDLM_SOURCES="$t/none" bash "$m/chords.sh" >"$t/sh.out" 2>&1; rc=$?
if [ $rc = 2 ] && grep -q '^BLIND: no sources' "$t/sh.out"; then ok "chords.sh without sources is BLIND"
else bad "chords.sh without sources: rc=$rc"; cat "$t/sh.out"; fi
# ---- publish.sh refuses while chords.sh is red or BLIND, before any push.
# The adversary is a checkout whose chord symbols no longer match their PDF,
# or a host that cannot read the PDFs at all. In a committed copy of
# muertos/, recheck.sh and build.sh are stubbed green, so only chords.sh
# decides; publish.sh runs for real against a local bare site repo. With
# the chords.sh line taken out of publish.sh, both cases push and fail here.
c="$t/pub"; mkdir -p "$c"; cp -r "$m" "$c/muertos"
printf '#!/usr/bin/env bash\nexit 0\n' >"$c/muertos/recheck.sh"
printf '%s\n' '#!/usr/bin/env bash' 'mkdir -p "$1" && cd "$1" || exit 1' \
  'touch mellophone-cards.pdf mellophone-letter.pdf mellophone-range.txt x.pdf' \
  "printf 'x.pdf\\tX\\t-\\n' >songs.tsv" >"$c/muertos/build.sh"
cp "$m/chords.sh" "$t/chords.sh.real"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
git -C "$c" init -q
git init -q --bare "$t/site.git"
git -C "$t/site.git" symbolic-ref HEAD refs/heads/master
git clone -q "$t/site.git" "$t/seed" 2>/dev/null
git -C "$t/seed" commit -q --allow-empty -m seed
git -C "$t/seed" push -q origin HEAD:master
for case in red blind; do
  if [ $case = red ]; then
    printf '#!/usr/bin/env bash\necho "RED: chords/x.ily is not what the PDF says"; exit 1\n' >"$c/muertos/chords.sh"
  else cp "$t/chords.sh.real" "$c/muertos/chords.sh"; fi
  chmod +x "$c"/muertos/*.sh
  git -C "$c" add -A && git -C "$c" commit -q -m "$case"
  before=$(git -C "$t/site.git" rev-parse master)
  DDLM_SOURCES="$t/none" DDLM_SITE="$t/site.git" DDLM_LIVE=http://127.0.0.1:9/ DDLM_TRIES=1 \
    bash "$c/muertos/publish.sh" >"$t/pub.out" 2>&1; rc=$?
  after=$(git -C "$t/site.git" rev-parse master)
  if [ $rc != 0 ] && grep -q 'chords.sh is not green' "$t/pub.out" && [ "$before" = "$after" ]; then
    ok "publish.sh refuses while chords.sh is $case; site untouched"
  else
    bad "publish.sh with chords.sh $case: rc=$rc, site $before -> $after"; cat "$t/pub.out"
  fi
done
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL

# ---- the main book has chords (#8): build.sh refuses a Book.ly that turns them
# off, before any compile (so this runs with no LilyPond too). The adversary is
# a Book.ly edited back to ddlmChords = ##f, which would publish a main
# mellophone-letter.pdf with no chords. With the grep taken out of build.sh
# the build goes on and does not say this.
rm -rf "$t/nochordsmain"; cp -r "$m" "$t/nochordsmain"
sed -i 's/^ddlmChords = ##t$/ddlmChords = ##f/' "$t/nochordsmain/Book.ly"
if cmp -s "$m/Book.ly" "$t/nochordsmain/Book.ly"; then bad "Book.ly has no 'ddlmChords = ##t' line to turn off"
elif bash "$t/nochordsmain/build.sh" "$t/nochordsmain-out" >"$t/nochordsmain.out" 2>&1; then
  bad "build.sh built a main book from a Book.ly with ddlmChords = ##f"
elif grep -q "Book.ly has no line 'ddlmChords = ##t'; the main book has chords" "$t/nochordsmain.out"; then
  ok "build.sh refuses a main book without chords"
else bad "build.sh on ddlmChords = ##f failed, but not for that:"; tail -3 "$t/nochordsmain.out"; fi
[ -e "$t/nochordsmain-out/mellophone-cards.pdf" ] && bad "a chordless main book was written"

# ---- index.sh: "without chords" links, and a missing alternate PDF is red
mkdir "$t/out"
for f in mellophone-cards mellophone-letter mellophone-nochords-cards mellophone-nochords-letter voodoo voodoo-nochords tabu; do
  : >"$t/out/$f.pdf"; done
: >"$t/out/mellophone-range.txt"
printf 'voodoo.pdf\tVoodoo\tvoodoo-nochords.pdf\ntabu.pdf\tTabu\t-\n' >"$t/out/songs.tsv"
if "$m/index.sh" "$t/out" 0123456789abcdef "2026-11-02 00:00 UTC" >"$t/page.html" 2>&1; then
  for w in 'href="mellophone-nochords-cards.pdf"' 'href="mellophone-nochords-letter.pdf"' \
           'href="voodoo.pdf">Voodoo</a> <a class="with" href="voodoo-nochords.pdf">without chords</a>' \
           'href="tabu.pdf">Tabu</a></li>'; do
    grep -qF -- "$w" "$t/page.html" && ok "page has $w" || bad "page lacks $w"
  done
else bad "index.sh failed:"; cat "$t/page.html"; fi
rm "$t/out/voodoo-nochords.pdf"
"$m/index.sh" "$t/out" 0123456789abcdef "2026-11-02 00:00 UTC" >"$t/page.html" 2>&1 \
  && bad "index.sh with voodoo-nochords.pdf missing was green" || ok "index.sh red on a missing no-chords PDF"

# ---- chords.tsv, chords/ and Songs.ily agree
rows=0
while IFS=$'\t' read -r song pdf staff voice extra; do
  case $song in ''|'#'*) continue ;; esac
  rows=$((rows + 1))
  [ -z "${extra:-}" ] && [[ $staff$voice =~ ^[0-9]+$ ]] && [ "${pdf%.pdf}" != "$pdf" ] \
    || bad "chords.tsv row $rows: bad fields: $song|$pdf|$staff|$voice"
  [ -f "$m/chords/$song.ily" ] || bad "chords.tsv names $song, no chords/$song.ily"
  grep -qx "\\\\include \"chords/$song.ily\"" "$m/Songs.ily" || bad "Songs.ily does not include chords/$song.ily"
  grep -q "withChords \\\\$song-chords \\\\$song-accompaniment" "$m/Songs.ily" || bad "$song's card has no \\withChords"
  grep -q "^$song-chords = " "$m/chords/$song.ily" || bad "chords/$song.ily does not define $song-chords"
done <"$m/chords.tsv"
for f in "$m"/chords/*.ily; do
  s=$(basename "$f" .ily)
  grep -q "^$s	" "$m/chords.tsv" || bad "chords/$s.ily has no row in chords.tsv (chords.sh would never check it)"
done
[ "$rows" -ge 8 ] && ok "chords.tsv has $rows rows, each with its chords/ file and card" || bad "chords.tsv has $rows rows"

# ---- LilyPond: the card both ways
if ! command -v lilypond >/dev/null || ! command -v gs >/dev/null; then
  echo "SKIP: no lilypond/gs on PATH; the cards were not compiled"
else
  card() {  # card NAME CHORDS(##t|##f) SONG: compile one card, print its text
    { sed "s/^ddlmChords = ##[tf]\$/ddlmChords = $2/; /^\\\\[A-Za-z_]*-card\$/d" "$m/Book.ly"
      printf '\\%s-card\n' "$3"; } >"$t/$1.ly"
    lilypond -I "$m" -o "$t/$1" "$t/$1.ly" >"$t/$1.log" 2>&1 || { echo "LILYPOND FAILED"; tail -5 "$t/$1.log"; return; }
    gs -q -dBATCH -dNOPAUSE -dSAFER -sDEVICE=txtwrite -o - "$t/$1.pdf" 2>/dev/null | tr -d '\0'
  }
  names() { grep -a -o '\bN\.C\.\|\b[A-G][a-z0-9]*' | tr '\n' ' '; }
  # get_my_sound: concert Dm F C Bb (Get_My_Sound.pdf), written a fifth up;
  # its music makes no Staff, so notes read as chords would show as N.C., C6...
  # The book as committed (Book.ly's own ddlmChords, no sed) is the main one: chords.
  { sed '/^\\[A-Za-z_]*-card$/d' "$m/Book.ly"; printf '\\get_my_sound-card\n'; } >"$t/main.ly"
  lilypond -I "$m" -o "$t/main" "$t/main.ly" >"$t/main.log" 2>&1
  got=$(gs -q -dBATCH -dNOPAUSE -dSAFER -sDEVICE=txtwrite -o - "$t/main.pdf" 2>/dev/null | tr -d '\0' | names)
  [ "$got" = "F Get Am C G F " ] && ok "the committed Book.ly is the main book: get_my_sound prints Am C G F" \
    || bad "the committed Book.ly: get_my_sound text [$got], want [F Get Am C G F ]"
  got=$(card gms-on '##t' get_my_sound | names)
  [ "$got" = "F Get Am C G F " ] && ok "with chords: get_my_sound prints Am C G F" \
    || bad "with chords: get_my_sound text [$got], want [F Get Am C G F ]"
  got=$(card gms-off '##f' get_my_sound | names)
  [ "$got" = "F Get " ] && ok "without chords: get_my_sound prints none" \
    || bad "without chords: get_my_sound text [$got], want [F Get ]"
  # Injected: the chords outside the card's \transpose f c' stay at concert
  # pitch (Dm F C Bb): the check above would be red on them.
  sed 's/^ddlmChords = ##[tf]$/ddlmChords = ##t/; /^\\[A-Za-z_]*-card$/d' "$m/Book.ly" >"$t/conc.ly"
  printf '\\bookpart { \\withChords \\get_my_sound-chords { \\transpose f c'"'"' \\get_my_sound-accompaniment } }\n' >>"$t/conc.ly"
  lilypond -I "$m" -o "$t/conc" "$t/conc.ly" >"$t/conc.log" 2>&1
  got=$(gs -q -dBATCH -dNOPAUSE -dSAFER -sDEVICE=txtwrite -o - "$t/conc.pdf" 2>/dev/null | tr -d '\0' | names)
  case $got in *"Dm F C B"*) ok "injected: chords outside the transpose print at concert pitch ($got), not Am C G F" ;;
    *) bad "injected: concert-pitch card text [$got], want Dm F C B in it" ;; esac
fi

[ $fail = 0 ] && echo "ddlm-chords: all ok"
exit $fail
