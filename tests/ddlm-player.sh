#!/usr/bin/env bash
# The player profile (muertos/player.ily, hf7y-estate/lilypond#8):
# \mellophonePart's top-note reduction and whole-phrase range fit, the
# fingering rules in muertos/mellophone.ily (top note only, spelled pitch,
# "12" not "1-2") and the card layout (5.5x6in cards, #21/#25), on small
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

# ---- the tuba fallback (#8's "harmonic floor"): the same D6 E6 as
# "fifth" above, no shift of which fits (the same join-limit math), but
# now with a second voice (after \\, the one item 7 doesn't play, both
# measures sounding E4, itself in range) under it. Both D6 and E6 move to
# the octave of that E4 nearest their own that is in range: E5, both of
# them.
topnotes() {  # topnotes NAME: the first voice's notes (the top voice,
  # engraved before the one after \\, so always the first one logged)
  local v=$(awk -F'\t' '$4=="note"{print $7; exit}' "$t/$1.tsv")
  awk -F'\t' -v v="$v" '$4=="note" && $7==v{printf "%s ", $5}' "$t/$1.tsv" | sed 's/ $//'
}
tuba="<< { c'4( e' g'' c''') | d'''2( e''') | } \\\\ { e'2 | e'2 | } >>"
fixture tuba "" "$tuba"
want "a note no shift fits is replaced from the voice after \\\\" "$(topnotes tuba)" "60 64 79 84 76 76"
grep -q 'mellophone: .*outside' "$t/tuba.log" \
  && bad "range warning on a note the tuba fallback replaced"
# Injected: without it, this is exactly "fifth"'s case (left as is, warned).
fixture tuba-inj "#(define (player-tuba-fallback! phrases shadow) #f)" "$tuba"
want "injected: without the tuba fallback it is left as is" "$(topnotes tuba-inj)" "60 64 79 84 86 88"
want "injected: without the tuba fallback it is warned" \
  "$(grep -c 'mellophone: .*outside C4-C6' "$t/tuba-inj.log")" 2

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
# <c' e' g'> <d' f' a'> -> G4 A4; two voices E5/C5 then C#5/A4 -> the
# lower voice is taken out, so only E5 C#5 print; Db5 after C#5 is another
# pitch and is fingered.
top="<c' e' g'>2 <d' f' a'>2 | << { e''2 cis''2 } \\\\ { c''2 a'2 } >> | des''1 |"
fixture top "" "$top"
want "chords reduce to the top note, the lower voice is out" "$(notes top)" "67 69 76 73 73"
want "one note per voice per moment" \
  "$(awk -F'\t' '$4=="note"{print $1, $2, $7}' "$t/top.tsv" | sort | uniq -d | wc -l)" 0
want "fingered: top notes, spelled pitch, no dashes" \
  "$(awk -F'\t' '$1=="finger"{printf "%s=%s ", $4, $5}' "$t/top-layout.txt")" \
  "G4=0 A4=12 E5=0 C#5=12 Db5=12 "
# Injected: without player-drop-lower! the lower voice's C5 A4 print again.
fixture top-inj "#(define (player-drop-lower! m) #t)" "$top"
want "injected: without the drop the lower voice prints" "$(notes top-inj)" "67 69 76 72 73 69 73"

# A cue-size top voice keeps the voice under it: whether a cue is ever the
# part is Zach's open question on #8, so those passages stay as written.
fixture cue-mag "" "<< \\magnifyMusic 0.63 { e''2 cis''2 } \\\\ { c''2 a'2 } >> |"
want "a \\magnifyMusic top voice keeps the voice under it" "$(notes cue-mag)" "76 72 73 69"
fixture cue-voice "" "<< \\new CueVoice { \\voiceOne e''2 cis''2 } \\\\ { c''2 a'2 } >> |"
want "a CueVoice top voice keeps the voice under it" "$(notes cue-voice)" "76 72 73 69"
# the book's CueVoice check below reads ly-events.ily's voice column: it
# must name a CueVoice when there is one
want "ly-events names a CueVoice" "$(awk -F'\t' '$4=="note" && $7 ~ /^CueVoice:/' "$t/cue-voice.tsv" | wc -l)" 2

# ---- grace notes are fingered at the size of every other fingering (#25
# item 9, Zach 2026-11-02: "grace note fingerings are too small")
fsize() { awk -F'\t' '$1=="finger"{print $7, $6}' "$t/$1-layout.txt" | sort -u | tr '\n' ' '; }
fixture grace "" "\\acciaccatura { d''8 } c''2. \\acciaccatura { e''8 } f''4 |"
want "grace and note fingerings are one size" "$(fsize grace)" "grace -4 note -4 "
# Injected: without Mellophone_engraver's acknowledger the grace's own
# font-size (-8, LilyPond's graceSettings) is back
rm -rf "$t/m-grace"; cp -r "$m" "$t/m-grace"
sed -i "s/(ly:grob-set-property! grob 'font-size mellophone-fingering-size)/#t/" "$t/m-grace/mellophone.ily"
if ! grep -q . <(diff "$m/mellophone.ily" "$t/m-grace/mellophone.ily"); then bad "grace-inj: the sed changed nothing in mellophone.ily"
else
  sed "s|^\\\\include \"mellophone.ily\"|\\\\include \"$t/m-grace/mellophone.ily\"|" "$t/grace.ly" >"$t/grace-inj.ly"
  if lilypond -I "$t/m-grace" -o "$t/grace-inj" "$t/grace-inj.ly" >"$t/grace-inj.log" 2>&1; then
    got=$(fsize grace-inj)
    [ "$got" != "grace -4 note -4 " ] && ok "injected: without the acknowledger the grace fingering is [$got]" \
      || bad "injected: without the acknowledger the grace fingering is still [$got]"
  else bad "lilypond failed on grace-inj:"; tail -5 "$t/grace-inj.log"; fi
fi
# \magnifyMusic's own output is unchanged by the mark player.ily puts on it.
fixture mag-up "" "\\magnifyMusic 1.5 { c''2 d''2 } |"
want "\\magnifyMusic above 1 is no cue, and still engraves" "$(notes mag-up)" "72 74"

# ---- the book
{ cat "$m/Book.ly"; printf '#(define ly-events-file "%s")\n\\include "tools/ly-events.ily"\n' "$t/book.tsv"; } >"$t/book.ly"
if ly book; then
  L="$t/book-layout.txt"
  want "one staff size on every card" "$(awk -F'\t' '$1=="system"{print $4}' "$L" | sort -u | tr '\n' ' ')" "14.0 "
  rin=$(awk -F'\t' '$1=="system" && $2=="rin_de_angelito"{print $3}' "$L")
  [ "${rin:-0}" -gt 1 ] && ok "rin_de_angelito has $rin systems" || bad "rin_de_angelito has [$rin] systems, want more than 1"
  want "gnossienne: no note above C6" \
    "$(awk -F'\t' '$1=="gnossienne"{print $4}' "$t/book-range.txt")" none
  want "la_llorona: m6's D6 is replaced from the accompaniment voice" \
    "$(awk -F'\t' '$1=="la_llorona"{print $4}' "$t/book-range.txt")" none
  want "no fingering with a dash" "$(awk -F'\t' '$1=="finger" && $5 ~ /-/' "$L" | wc -l)" 0
  want "zeina's Db5 (m22, was m29 before the intro and B folds) carries a fingering" \
    "$(awk -F'\t' '$1=="finger" && $2=="zeina" && $4=="Db5"{print $3, $5}' "$L")" "22 12"
  # every fingering in the book one size, and some of them on grace notes
  want "the book's fingerings, grace and note, are one size" \
    "$(awk -F'\t' '$1=="finger"{print $7, $6}' "$L" | sort -u | tr '\n' ' ')" "grace -4 note -4 "
  # every card of every song holds at most 11 systems: from each song's
  # "page" lines (a card's first system) and its system count
  want "no card over 11 systems" "$(awk -F'\t' '
      $1=="system" { n[$2]=$3 }
      $1=="page"   { if ($4 - (($2 in last) ? last[$2] : 1) > 11) print $2, $4; last[$2]=$4 }
      END { for (s in n) if (n[s] + 1 - ((s in last) ? last[s] : 1) > 11) print s, "end" }' "$L" | wc -l)" 0
  # one card a song but zeina (#25: "generally pieces on 2 pages now should
  # aim for 1 page"): only zeina has a "page" line, and every one is at a mark
  want "only zeina goes on to a 2nd card" \
    "$(awk -F'\t' '$1=="page"{print $2}' "$L" | sort -u | tr '\n' ' ')" "zeina "
  want "every 2nd card starts at a rehearsal mark" "$(awk -F'\t' '$1=="page" && $7!="mark"' "$L" | wc -l)" 0
  want "no compressed card" "$(grep -c 'compress' "$t/book.log")" 0
fi

# One song's card, as build.sh builds it: Book.ly's preamble and the song.
card() {  # card NAME SONG [LINES]: LINES go before Songs.ily's \include
  { sed '/^\\[A-Za-z_]*-card$/d; /^\\include "Songs.ily"$/d' "$m/Book.ly"
    printf '%s\n' "${3:-}" '\include "Songs.ily"' "\\$2-card"; } >"$t/$1.ly"
  ly "$1"
}
# A card holds 11 systems (player.ily's player-card-systems, measured on
# 5.5x6in for #25); a song goes over as many cards as it needs, each
# page break at a rehearsal mark, else at a rest, where one is in reach.
breaks() { awk -F'\t' '$1=="page"{printf "%s@%s ", $6, $7}' "$1" | sed 's/ $//'; }
if card card-zeina zeina; then
  want "zeina's 13 systems go on 2 cards" "$(pages "$t/card-zeina.pdf")" 2
  want "zeina's 2nd card starts at a rehearsal mark (bar@kind)" "$(breaks "$t/card-zeina-layout.txt")" "26@mark"
fi
# Injected: marks are the worst place to break -> zeina breaks off its marks.
if card card-zeina-inj zeina '#(define player-card-breaks
  (let ((f player-card-breaks)) (lambda (s kind) (f s (lambda (k) (- 2 (kind k)))))))'; then
  got=$(breaks "$t/card-zeina-inj-layout.txt")
  [ "$got" != "26@mark" ] && ok "injected: with the preference reversed zeina breaks at [$got]" \
    || bad "injected: with the preference reversed zeina still breaks at [$got]"
fi
for s in voodoo vis_hora le_chant_des_partisans the_fool la_llorona; do
  card "card-$s" "$s" && want "$s's card has 1 page" "$(pages "$t/card-$s.pdf")" 1
done
# Every bar of every song is on its card, and no system is one bar unless
# the song is (Zach, 2026-11-02, of Cairn Builder: "the last print had a
# system break error": its \cueBox, mid-system, pushed bars 8-10 off the
# card). Each card again, its bar numbers printed as [BAR<n>] on every bar;
# the bars wanted are those a note or rest ly-events.ily logs sounds in.
cat >"$t/bars.py" <<'EOF'
import math, re, sys
from fractions import Fraction as F
import pymupdf as fitz
pdf, tsv, song = sys.argv[1:4]
want = set()  # every bar a note or rest sounds in (R2.*3 and c1. hold on)
for f in (l.rstrip("\n").split("\t") for l in open(tsv)):
    if len(f) > 5 and f[3] in ("note", "rest", "mrest"):
        b, pos, ml, ln = int(f[0]), F(f[1]), F(f[2]), F(f[5])
        want.update(range(b, b + max(1, math.ceil((pos + ln) / ml))))
got = {}  # bar -> (page, x) of its number, on the page only
for p, page in enumerate(fitz.open(pdf)):
    r = page.rect
    for x0, y0, x1, y1, w, *_ in page.get_text("words"):
        # [BAR<n>]: a word can run on into a mark or a fingering beside it
        for n in re.findall(r"\[BAR(\d+)\]", w):
            if r.x0 <= x0 and x1 <= r.x1 and r.y0 <= y0 and y1 <= r.y1:
                got.setdefault(int(n), (p, x0))
systems, prev = [], None  # a system starts where the page changes or x goes back
for b in sorted(got):
    if prev is None or got[b][0] != prev[0] or got[b][1] < prev[1]:
        systems.append([])
    systems[-1].append(b); prev = got[b]
lone = [s[0] for s in systems if len(s) == 1] if len(got) > 1 else []
# bars printed after the last one logged: the log was cut short (bars
# inside it can have none: a \repeat percent bar prints no notes)
print(song, len(want), len(set(got) & want),
      " ".join(map(str, sorted(want - set(got)))) or "-",
      " ".join(str(b) for b in sorted(got) if b > max(want, default=0)) or "-",
      " ".join(map(str, lone)) or "-", sep="\t")
EOF
barlines='\layout { \context { \Score
  barNumberVisibility = #all-bar-numbers-visible
  \override BarNumber.break-visibility = #end-of-line-invisible
  \override BarNumber.self-alignment-X = #LEFT
  barNumberFormatter = #(lambda (n pos alt ctx) (make-simple-markup (format #f "[BAR~a]" n))) } }'
songs=$(sed -n 's/^\\\([A-Za-z_]*\)-card$/\1/p' "$m/Book.ly")
for s in $songs; do  # 4 at a time: 14 at once can run a small host out of memory
  while [ "$(jobs -rp | wc -l)" -ge 4 ]; do wait -n; done
  card "bars-$s" "$s" "#(define ly-events-file \"$t/bars-$s.tsv\")
\\include \"tools/ly-events.ily\"
$barlines" >"$t/bars-$s.out" &
done
wait
for s in $songs; do
  if [ ! -s "$t/bars-$s.pdf" ] || grep -q '^FAIL' "$t/bars-$s.out"; then
    cat "$t/bars-$s.out"; bad "$s: no card to count bars on"; continue
  fi
  IFS=$'\t' read -r _ nwant nprint missing extra lone < <(python3 -I "$t/bars.py" "$t/bars-$s.pdf" "$t/bars-$s.tsv" "$s")
  want "$s: bars on the card (of $nwant), missing, past the log" "$nprint $missing $extra" "$nwant - -"
  want "$s: one-bar systems" "$lone" "-"
done
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

# vis_hora m1-4: the cue-size "accomp. simile" stabs under the melody are
# taken out (hf7y on #21: "the lower voice of << \\ >> passages still
# prints (Vi's Hora m1-4)"). the_fool's section C prints the horn
# countermelody alone, no cue notes (#25 item 5: "remove cue notes and
# only show horn counter melody (stems up)").
voices() { awk -F'\t' '$4=="note"{print $7}' "$t/$1.tsv" | sort -u | wc -l; }
card vis vis_hora "#(define ly-events-file \"$t/vis.tsv\")
\\include \"tools/ly-events.ily\"" && want "vis_hora: one voice prints" "$(voices vis)" 1
card fool the_fool "#(define ly-events-file \"$t/fool.tsv\")
\\include \"tools/ly-events.ily\"" \
  && want "the_fool: no CueVoice note" "$(awk -F'\t' '$4=="note" && $7 ~ /^CueVoice:/' "$t/fool.tsv" | wc -l)" 0 \
  && want "the_fool: section C is the horn countermelody alone, stems up (#25, Zach 2026-11-02: Mids)" \
    "$(grep -c 'new Voice { .stemUp .c-harmony }' "$m/the_fool.ly")" 1

[ $fail = 0 ] && echo "ddlm-player: all ok"
exit $fail
