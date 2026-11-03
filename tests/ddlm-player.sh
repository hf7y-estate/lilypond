#!/usr/bin/env bash
# The player profile (muertos/player.ily, hf7y-estate/lilypond#8):
# \mellophonePart's top-note reduction and whole-phrase range fit, the
# fingering rules in muertos/mellophone.ily (top note only, spelled pitch,
# "12" not "1-2") and the card layout (5.5x4.25in cards, #21), on small
# fixtures and on the book.
# Reads the notes back with muertos/tools/ly-events.ily and the systems
# and fingerings from the <output>-layout.txt player.ily writes.
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
ly() {  # ly NAME: compile $t/NAME.ly; 1 if lilypond fails
  lilypond -I "$m" -o "$t/$1" "$t/$1.ly" >"$t/$1.log" 2>&1 \
    || { bad "lilypond failed on $1:"; tail -5 "$t/$1.log"; return 1; }
}
pages() { gs -q -dNODISPLAY -dNOSAFER -c "($1) (r) file runpdfbegin pdfpagecount = quit"; }

# fixture NAME EXTRA MUSIC: MUSIC written at the mellophone's written pitch
# (the \transpose c' f undoes \mellophonePart's \transpose f c'), its notes
# to $t/NAME.tsv. EXTRA goes after the includes.
fixture() {
  cat >"$t/$1.ly" <<EOF
\\version "2.24.1"
\\include "mellophone.ily"
#(define ly-events-file "$t/$1.tsv")
\\include "tools/ly-events.ily"
$2
\\header { tagline = ##f }
\\score { \\new Staff \\mellophonePart \\transpose c' f { \\time 4/4 $3 } }
EOF
  ly "$1"
}
notes() { awk -F'\t' '$4=="note"{printf "%s ", $5}' "$t/$1.tsv" | sed 's/ $//'; }

# ---- range fit: whole phrases, at breaths
# Phrase 1 spans C4-G5 and cannot move; phrase 2, after a rest, crosses
# C6 in the middle (E6 D6 C6 | B5 A5): all of it goes down an octave,
# B5 and A5 too, so no octave changes inside it.
fixture phrase "" "c'4( e' g' c'' | g''1) | r1 | e'''4( d''' c''' b'' | a''1) |"
want "a phrase crossing C6 moves whole" "$(notes phrase)" "60 64 67 72 79 76 74 72 71 69"
grep -q 'mellophone:' "$t/phrase.log" && bad "range warning on a line the fit puts in range"

# Two phrases, no rest between: C4 E4 G5 C6, then D6 E6. Either octave
# move of the first puts two of its notes out, as many as it would bring
# in, so it stays. Down an octave the second would join C6 -> D5, a
# seventh: wider than a fifth, so it stays too, and is warned about.
fixture fifth "" "c'4( e' g'' c''') | d'''2( e''') |"
want "no join leap over a fifth" "$(notes fifth)" "60 64 79 84 86 88"
want "out of range left as is is warned" "$(grep -c 'mellophone: .*outside C4-C6' "$t/fifth.log")" 2
# Injected: the limit an octave -> the second phrase moves, leap and all.
fixture fifth-inj "#(set! player-join-limit 12)" "c'4( e' g'' c''') | d'''2( e''') |"
want "injected: join limit an octave lets it leap" "$(notes fifth-inj)" "60 64 79 84 74 76"

# Repeated and sequential phrases take the same shift (#8 item 2).
# D4 E4 F4 stays; the high phrase goes down; the low A3 has to go up, and
# fewest octave changes alone would leave everything after it up there:
# the repeat of D4 E4 F4 at D5 E5 F5, its sequence E4 F#4 G4 at E5 F#5 G5.
# Both take the first phrase's shift instead (A4 -> D4 is a fifth).
rep="d'4( e' f'2) | r1 | a''4( g'' c'''2) | r1 | a1 | r1 | d'4( e' f'2) | r1 | e'4( fis' g'2) |"
fixture repeat "" "$rep"
want "a repeat and a sequence take the first phrase's shift" "$(notes repeat)" \
  "62 64 65 69 67 72 69 62 64 65 64 66 67"
# Injected: no phrase is a repeat of another -> they land an octave up.
fixture repeat-inj "#(define (player-phrase-key p) #f)" "$rep"
want "injected: without the repeat rule they move" "$(notes repeat-inj)" \
  "62 64 65 69 67 72 69 74 76 77 76 78 79"

# ---- top note, fingering
# <c' e' g'> <d' f' a'> -> G4 A4; two voices E5/C5 then C#5/A4 -> only the
# top voice is fingered; Db5 after C#5 is another pitch and is fingered.
fixture top "" "<c' e' g'>2 <d' f' a'>2 | << { e''2 cis''2 } \\\\ { c''2 a'2 } >> | des''1 |"
want "chords reduce to the top note" "$(notes top)" "67 69 76 72 73 69 73"
want "one note per voice per moment" \
  "$(awk -F'\t' '$4=="note"{print $1, $2, $7}' "$t/top.tsv" | sort | uniq -d | wc -l)" 0
want "fingered: top notes, spelled pitch, no dashes" \
  "$(awk -F'\t' '$1=="finger"{printf "%s=%s ", $4, $5}' "$t/top-layout.txt")" \
  "G4=0 A4=12 E5=0 C#5=12 Db5=12 "

# ---- the book
{ cat "$m/Book.ly"; printf '#(define ly-events-file "%s")\n\\include "tools/ly-events.ily"\n' "$t/book.tsv"; } >"$t/book.ly"
if ly book; then
  L="$t/book-layout.txt"
  want "one staff size on every card" "$(awk -F'\t' '$1=="system"{print $4}' "$L" | sort -u | tr '\n' ' ')" "14.0 "
  rin=$(awk -F'\t' '$1=="system" && $2=="rin_de_angelito"{print $3}' "$L")
  [ "${rin:-0}" -gt 1 ] && ok "rin_de_angelito has $rin systems" || bad "rin_de_angelito has [$rin] systems, want more than 1"
  want "gnossienne: no note above C6" \
    "$(awk -F'\t' '$1=="gnossienne"{print $4}' "$t/book-range.txt")" none
  want "no fingering with a dash" "$(awk -F'\t' '$1=="finger" && $5 ~ /-/' "$L" | wc -l)" 0
  want "zeina's Db5 (m29) carries a fingering" \
    "$(awk -F'\t' '$1=="finger" && $2=="zeina" && $4=="Db5"{print $3, $5}' "$L")" "29 12"
  # every card of every song holds at most 6 systems: from each song's
  # "page" lines (a card's first system) and its system count
  want "no card over 6 systems" "$(awk -F'\t' '
      $1=="system" { n[$2]=$3 }
      $1=="page"   { if ($4 - (($2 in last) ? last[$2] : 1) > 6) print $2, $4; last[$2]=$4 }
      END { for (s in n) if (n[s] + 1 - ((s in last) ? last[s] : 1) > 6) print s, "end" }' "$L" | wc -l)" 0
  want "no compressed card" "$(grep -c 'compress' "$t/book.log")" 0
fi

# One song's card, as build.sh builds it: Book.ly's preamble and the song.
card() {  # card NAME SONG [LINES]: LINES go before Songs.ily's \include
  { sed '/^\\[A-Za-z_]*-card$/d; /^\\include "Songs.ily"$/d' "$m/Book.ly"
    printf '%s\n' "${3:-}" '\include "Songs.ily"' "\\$2-card"; } >"$t/$1.ly"
  ly "$1"
}
# A card holds 6 systems (player.ily's player-card-systems, measured on
# 5.5x4.25in for #21); a song goes over as many cards as it needs, each
# page break at a rehearsal mark, else at a rest, where one is in reach.
breaks() { awk -F'\t' '$1=="page"{printf "%s@%s ", $6, $7}' "$1" | sed 's/ $//'; }
if card card-zeina zeina; then
  want "zeina's 14 systems go on 3 cards" "$(pages "$t/card-zeina.pdf")" 3
  want "zeina's cards break at its marks (bar@kind)" "$(breaks "$t/card-zeina-layout.txt")" "25@mark 44@mark"
fi
# Injected: no break is better than another -> zeina splits evenly, off its marks.
if card card-zeina-inj zeina '#(define player-card-breaks
  (let ((f player-card-breaks)) (lambda (s kind) (f s (lambda (k) 2)))))'; then
  got=$(breaks "$t/card-zeina-inj-layout.txt")
  [ "$got" != "25@mark 44@mark" ] && ok "injected: without the mark/rest preference zeina breaks at [$got]" \
    || bad "injected: without the preference zeina still breaks at [$got]"
fi
card card-voodoo voodoo && want "voodoo's card breaks at a rest (bar@kind)" "$(breaks "$t/card-voodoo-layout.txt")" "21@rest"
card card-rin rin_de_angelito && want "rin_de_angelito's card has 1 page" "$(pages "$t/card-rin.pdf")" 1

# love_in_outer_space: its accompaniment is triads; no chord is left.
events="#(define ly-events-file \"$t/love.tsv\")
\\include \"tools/ly-events.ily\""
chords() { awk -F'\t' '$4=="note"{print $1, $2, $7}' "$t/love.tsv" | sort | uniq -d | wc -l; }
card love love_in_outer_space "$events" && want "love_in_outer_space: no chord" "$(chords)" 0
# Injected: the card through a plain \transpose f c' -> its triads come back.
card love-inj love_in_outer_space "$events
mellophonePart = #(define-music-function (m) (ly:music?) #{ \\transpose f c' \$m #})" \
  && { n=$(chords); [ "$n" -gt 0 ] && ok "injected: without the reduction, love_in_outer_space has $n chords" \
       || bad "injected: a plain \\transpose f c' left $n chords, want some"; }

[ $fail = 0 ] && echo "ddlm-player: all ok"
exit $fail
