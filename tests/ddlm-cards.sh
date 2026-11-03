#!/usr/bin/env bash
# The lyre cards (hf7y-estate/lilypond#21): muertos/build.sh builds the
# book as 5.5x4.25in cards and imposes them 2-up on the top half of
# landscape letter, bottom half blank (Zach, 2026-11-02: "quarter sheets
# but printed 2 up with the bottom half blank? that's better so I have
# room for my lyre to clip"). Reads the built PDFs back with gs: every card
# 396x306pt, every sheet 792x612pt with nothing drawn below y=306, two
# cards a sheet. Injected: a card with more systems than it holds, the old
# 5.5x8.5in paper, and the old full-sheet imposition must each be red.
# Needs lilypond and gs. Without lilypond on PATH it says SKIP and checks
# nothing: LilyPond 2.24 is on the dexter host, not in the agent image.
set -uo pipefail
root=$(git rev-parse --show-toplevel)
m="$root/muertos"
if ! command -v lilypond >/dev/null || ! command -v gs >/dev/null; then
  echo "SKIP: no lilypond/gs on PATH; nothing checked"
  exit 0
fi
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
fail=0
ok()  { echo "ok: $*"; }
bad() { echo "FAIL: $*"; fail=1; }
want() {  # want WHAT GOT EXPECTED
  if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got [$2], want [$3]"; fi
}
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
    want "$b-cards: every card 5.5x4.25in" "$(sizes "$cards")" "396x306 "
    want "$b-letter: every sheet landscape letter" "$(sizes "$letter")" "792x612 "
    n=$(pages "$cards")
    want "$b-letter: two cards a sheet ($n cards)" "$(pages "$letter")" $(( (n + 1) / 2 ))
    low=$(lowest "$letter")
    [ -n "$low" ] && [ "$low" -ge 305 ] && ok "$b-letter: nothing below y=$low (bottom half blank)" \
      || bad "$b-letter: drawn down to y=[$low], want nothing below 305"
  done
  for f in "$t"/out/*.pdf; do
    case $f in *-letter.pdf) continue ;; esac
    [ "$(sizes "$f")" = "396x306 " ] || bad "$(basename "$f"): pages [$(sizes "$f")], want 396x306"
  done
  ok "every card PDF checked for 396x306"
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

inject oldpaper Phone.ly 's/#(set-paper-size "quarter")/#(set-paper-size "card")/'
rc=$?
if [ $rc != 0 ] && grep -q 'has a page that is not 5.5x4.25in' "$t/oldpaper.out"; then
  ok "injected: 5.5x8.5in paper is refused"
else bad "injected: 5.5x8.5in paper: rc=$rc"; tail -5 "$t/oldpaper.out"; fi

# ---- injected: the cards on the bottom half of the sheet
if [ -f "$t/out/mellophone-cards.pdf" ]; then
  sed 's/k 396 mul 306 translate/k 396 mul 0 translate/' "$m/letter-2up.ps" >"$t/bottom.ps"
  gs -q -dBATCH -dNOPAUSE -dSAFER --permit-file-read="$t/out/mellophone-cards.pdf" \
    -sDEVICE=pdfwrite -dDEVICEWIDTHPOINTS=792 -dDEVICEHEIGHTPOINTS=612 -dFIXEDMEDIA \
    -sIN="$t/out/mellophone-cards.pdf" -o "$t/bottom.pdf" "$t/bottom.ps"
  low=$(lowest "$t/bottom.pdf")
  [ -n "$low" ] && [ "$low" -lt 305 ] && ok "injected: cards on the bottom half are seen (drawn down to y=$low)" \
    || bad "injected: cards on the bottom half not seen: lowest y [$low]"
fi

[ $fail = 0 ] && echo "ddlm-cards: all ok"
exit $fail
