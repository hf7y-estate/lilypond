#!/usr/bin/env bash
# The lyre cards (hf7y-estate/lilypond#21, #25): muertos/build.sh builds
# the book as 5.5x6in cards (Zach, 2026-11-02: "treat the page height as 6
# inches including margin") and imposes them 2-up at the top of landscape
# letter, the bottom 2.5in blank for the lyre clip (#21: "room for my lyre
# to clip"). Reads the built PDFs back with gs: every card 396x432pt,
# every sheet 792x612pt with nothing drawn below the cut at y=180, two
# cards a sheet; one card a song but Zeina, which may take two (#25:
# "generally pieces on 2 pages now should aim for 1 page"); a 2nd card
# carries the song's name ("print small title where possible on 2nd
# pages"). Injected: a card with more systems than it holds, the old
# 5.5x8.5in paper, the cards on the bottom of the sheet, a card that starts
# away from a rehearsal mark, and a 2nd card without the title must each
# be red; and build.sh's page-size check must say BLIND and refuse a PDF it
# cannot read.
# Needs gs. Without lilypond on PATH it checks only that last part and says
# SKIP for the build: LilyPond 2.24 is on the dexter host, not in the agent
# image.
set -uo pipefail
root=$(git rev-parse --show-toplevel)
m="$root/muertos"
if ! command -v gs >/dev/null; then
  echo "SKIP: no gs on PATH; nothing checked"
  exit 0
fi
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
fail=0
ok()  { echo "ok: $*"; }
bad() { echo "FAIL: $*"; fail=1; }
want() {  # want WHAT GOT EXPECTED
  if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got [$2], want [$3]"; fi
}

# ---- build.sh's card_size fails closed (needs gs only). An empty file and
# a PDF with no pages both read back as "0 0" with gs exiting 0, so a check
# that only compares "pages" with "pages that are 396x432" passes them; a
# missing file and junk must be refused too. Each must say BLIND.
sed -n '/^card_size() {/,/^}/p' "$m/build.sh" >"$t/card_size.sh"
grep -q '^card_size() {' "$t/card_size.sh" || bad "no card_size() in build.sh"
: >"$t/empty.pdf"
echo junk >"$t/junk.pdf"
printf '%%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n2 0 obj<</Type/Pages/Kids[]/Count 0>>endobj\ntrailer<</Root 1 0 R>>\n%%%%EOF\n' >"$t/zero.pdf"
for f in empty junk zero missing; do
  if (work=$t; . "$t/card_size.sh"; card_size "$t/$f.pdf") >"$t/cs-$f.out" 2>&1; then
    bad "card_size passed an unreadable PDF ($f)"
  elif grep -q 'BLIND' "$t/cs-$f.out"; then ok "card_size: $f PDF is BLIND and refused"
  else bad "card_size refused $f but did not say BLIND: $(tail -1 "$t/cs-$f.out")"; fi
done
# ... and ly()'s over-full check: a LilyPond log it cannot read is BLIND,
# not "nothing over-full". The stub lilypond removes its own log.
sed -n '/^ly() {/,/^}/p' "$m/build.sh" >"$t/ly.sh"
grep -q '^ly() {' "$t/ly.sh" || bad "no ly() in build.sh"
if (work=$(mktemp -d -p "$t"); out=$(mktemp -d -p "$t"); here=$m; . "$t/ly.sh"
    lilypond() { rm -f "$work/x.log"; : >"$work/x.pdf"; }
    ly x /dev/null) >"$t/ly-gone.out" 2>&1; then
  bad "ly() passed a build whose log it could not read"
elif grep -q 'BLIND' "$t/ly-gone.out"; then ok "ly(): an unreadable LilyPond log is BLIND and refused"
else bad "ly() refused an unreadable log but did not say BLIND: $(tail -1 "$t/ly-gone.out")"; fi

if ! command -v lilypond >/dev/null; then
  echo "SKIP: no lilypond on PATH; the build is not checked"
  [ $fail = 0 ] && echo "ddlm-cards: all ok (card_size only)"
  exit $fail
fi
pages() { gs -q -dNODISPLAY -dSAFER --permit-file-read="$1" -c "($1) (r) file runpdfbegin pdfpagecount = quit"; }
sizes() {  # the distinct page sizes of $1, "WxH" in pt
  gs -q -dNODISPLAY -dSAFER --permit-file-read="$1" -c "($1) (r) file runpdfbegin
    1 1 pdfpagecount { pdfgetpage /MediaBox get dup 2 get round cvi =only (x) print 3 get round cvi = } for quit" \
    | sort -u | tr '\n' ' '
}
lowest() {  # the lowest y any page of $1 draws at, rounded down, in pt
  gs -q -dSAFER -dBATCH -dNOPAUSE -sDEVICE=bbox "$1" 2>&1 \
    | awk '/^%%HiResBoundingBox/{y=int($3); if (min=="" || y<min) min=y} END{print min}'
}

# ---- the build
if bash "$m/build.sh" "$t/out" >"$t/build.out" 2>&1; then
  ok "build.sh: $(tail -1 "$t/build.out")"
  for b in mellophone mellophone-chords; do
    cards="$t/out/$b-cards.pdf" letter="$t/out/$b-letter.pdf"
    want "$b-cards: every card 5.5x6in" "$(sizes "$cards")" "396x432 "
    want "$b-letter: every sheet landscape letter" "$(sizes "$letter")" "792x612 "
    n=$(pages "$cards")
    want "$b-letter: two cards a sheet ($n cards)" "$(pages "$letter")" $(( (n + 1) / 2 ))
    low=$(lowest "$letter")
    # the cut line at y=180 is 0.4pt wide: its bbox reaches 179.8
    [ -n "$low" ] && [ "$low" -ge 179 ] && ok "$b-letter: nothing below y=$low (bottom 2.5in blank)" \
      || bad "$b-letter: drawn down to y=[$low], want nothing below 179"
  done
  for f in "$t"/out/*.pdf; do
    case $f in *-letter.pdf) continue ;; esac
    [ "$(sizes "$f")" = "396x432 " ] || bad "$(basename "$f"): pages [$(sizes "$f")], want 396x432"
  done
  ok "every card PDF checked for 396x432"
  # one card a song; zeina may take two
  [ "$(wc -l <"$t/out/songs.tsv")" -ge 14 ] || bad "songs.tsv lists $(wc -l <"$t/out/songs.tsv") songs, want 14"
  long=$(cut -f1 "$t/out/songs.tsv" | while read -r f; do
    n=$(pages "$t/out/$f"); [ "$n" = 1 ] || echo "$f=$n"; done | tr '\n' ' ')
  case $long in
    ''|'zeina.pdf=2 ') ok "every song on one card, but [${long% }]" ;;
    *) bad "songs on more than one card: [$long], want at most zeina.pdf=2" ;;
  esac
else
  bad "build.sh failed:"; tail -20 "$t/build.out"
fi

# ---- injected: build.sh refuses a card that does not fit, and the old paper
inject() {  # inject NAME FILE SED: build.sh from a copy of muertos/ with SED applied to FILE
  rm -rf "$t/$1"; cp -r "$m" "$t/$1"
  sed -i "$3" "$t/$1/$2"
  grep -q . <(diff "$m/$2" "$t/$1/$2") || { bad "$1: the sed changed nothing in $2"; return 1; }
  bash "$t/$1/build.sh" "$t/$1-out" >"$t/$1.out" 2>&1
}
inject overfull player.ily 's/^#(define player-card-systems-first [0-9]*)$/#(define player-card-systems-first 1000)/; s/^#(define player-card-systems [0-9]*)$/#(define player-card-systems 1000)/'
rc=$?
if [ $rc != 0 ] && grep -q 'has a card with more than fits on it' "$t/overfull.out"; then
  ok "injected: one card per song is refused ($(grep -m1 -o 'compressing over-full page by [0-9.]* staff-spaces' "$t/overfull.out"))"
else bad "injected: one card per song: rc=$rc"; tail -5 "$t/overfull.out"; fi

inject oldpaper Phone.ly 's/#(set-paper-size "lyre")/#(set-paper-size "card")/'
rc=$?
if [ $rc != 0 ] && grep -q 'has a page that is not 5.5x6in' "$t/oldpaper.out"; then
  ok "injected: 5.5x8.5in paper is refused"
else bad "injected: 5.5x8.5in paper: rc=$rc"; tail -5 "$t/oldpaper.out"; fi

# 4 systems a card: songs go on 3 cards, and some card then starts away
# from a rehearsal mark, which build.sh refuses (#25 item 4)
inject offmark player.ily 's/^#(define player-card-systems-first [0-9]*)$/#(define player-card-systems-first 4)/; s/^#(define player-card-systems [0-9]*)$/#(define player-card-systems 4)/'
rc=$?
if [ $rc != 0 ] && grep -q 'a card that does not start at a rehearsal mark' "$t/offmark.out"; then
  ok "injected: a card starting away from a mark is refused ($(grep -m1 -o 'mark: [^;]*' "$t/offmark.out"))"
else bad "injected: a card starting away from a mark: rc=$rc"; tail -5 "$t/offmark.out"; fi

# ---- zeina's 2nd card carries its name; injected: Phone.ly's header out
zeina2() {  # zeina2 DIR: the text on page 2 of zeina's card built from DIR
  { sed '/^\\[A-Za-z_]*-card$/d' "$1/Book.ly"; echo '\zeina-card'; } >"$1/z2.ly"
  lilypond -I "$1" -o "$1/z2" "$1/z2.ly" >"$1/z2.log" 2>&1 || { echo "LILYPOND FAILED"; return; }
  gs -q -dSAFER -dBATCH -dNOPAUSE -sDEVICE=txtwrite -dFirstPage=2 -dLastPage=2 \
    --permit-file-read="$1/z2.pdf" -o - "$1/z2.pdf" 2>/dev/null | tr -s ' ' | head -3
}
rm -rf "$t/z"; cp -r "$m" "$t/z"
case $(zeina2 "$t/z") in
  *Zeina*) ok "zeina's 2nd card carries its name" ;;
  *) bad "zeina's 2nd card has no title: [$(zeina2 "$t/z" | head -1)]" ;;
esac
sed -i 's/\\fromproperty #.header:piece \\null/\\null \\null/' "$t/z/Phone.ly"
if ! grep -q . <(diff "$m/Phone.ly" "$t/z/Phone.ly"); then bad "notitle: the sed changed nothing in Phone.ly"
else
  case $(zeina2 "$t/z") in
    *Zeina*) bad "injected: no header, and zeina's 2nd card still reads Zeina" ;;
    *) ok "injected: without the header the 2nd card has no title" ;;
  esac
fi

# ---- injected: the cards on the bottom of the sheet
if [ -f "$t/out/mellophone-cards.pdf" ]; then
  sed 's/k 396 mul 180 translate/k 396 mul 0 translate/' "$m/letter-2up.ps" >"$t/bottom.ps"
  grep -q . <(diff "$m/letter-2up.ps" "$t/bottom.ps") || bad "bottom: the sed changed nothing in letter-2up.ps"
  gs -q -dBATCH -dNOPAUSE -dSAFER --permit-file-read="$t/out/mellophone-cards.pdf" \
    -sDEVICE=pdfwrite -dDEVICEWIDTHPOINTS=792 -dDEVICEHEIGHTPOINTS=612 -dFIXEDMEDIA \
    -sIN="$t/out/mellophone-cards.pdf" -o "$t/bottom.pdf" "$t/bottom.ps"
  low=$(lowest "$t/bottom.pdf")
  [ -n "$low" ] && [ "$low" -lt 179 ] && ok "injected: cards on the bottom of the sheet are seen (drawn down to y=$low)" \
    || bad "injected: cards on the bottom of the sheet not seen: lowest y [$low]"
fi

[ $fail = 0 ] && echo "ddlm-cards: all ok"
exit $fail
