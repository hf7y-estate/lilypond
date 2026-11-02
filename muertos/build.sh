#!/usr/bin/env bash
# muertos/build.sh OUTDIR -- build the F mellophone card book into OUTDIR:
#   mellophone-cards.pdf   the book, one 5.5x8.5in card per page
#   mellophone-letter.pdf  the same cards 2-up on landscape letter, cut line
#   <song>.pdf             one cards PDF per song
#   mellophone-chords-cards.pdf, mellophone-chords-letter.pdf
#                          the book again with chord symbols (ddlmChords, #6)
#   <song>-chords.pdf      a song's card with chord symbols, for each song
#                          whose card has \withChords in Songs.ily
#   songs.tsv              <song>.pdf <TAB> title <TAB> <song>-chords.pdf or -,
#                          in book order
#   mellophone-range.txt   written range per song, notes outside F#3-C6
#                          (mellophone.ily writes it)
# Fails on any LilyPond error, or on a page that is not 5.5x8.5in.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=${1:?usage: build.sh OUTDIR}
mkdir -p "$out"
out=$(cd "$out" && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

ly() {  # ly NAME FILE: compile FILE to $out/NAME.pdf, zero errors
  local log="$work/$1.log"
  if ! lilypond -I "$here" -o "$work/$1" "$2" >"$log" 2>&1 || grep -q 'error:' "$log"; then
    grep -B1 -A3 'error' "$log" >&2 || tail -20 "$log" >&2
    echo "build.sh: $2 failed (log above)" >&2
    exit 1
  fi
  mv "$work/$1.pdf" "$out/$1.pdf"
}

card_size() {  # every page of $1 must be 396x612pt (5.5x8.5in)
  local bad
  bad=$(gs -q -dNODISPLAY -dSAFER --permit-file-read="$1" -sIN="$1" -c \
    'IN (r) file runpdfbegin 1 1 pdfpagecount { pdfgetpage /MediaBox get
     dup 2 get round cvi 396 ne exch 3 get round cvi 612 ne or { (bad) = } if }
     for quit' 2>&1)
  [ -z "$bad" ] || { echo "build.sh: $1 has a page that is not 5.5x8.5in" >&2; exit 1; }
}

ly mellophone-cards "$here/Book.ly"
card_size "$out/mellophone-cards.pdf"
mv "$work/mellophone-cards-range.txt" "$out/mellophone-range.txt"

# Book.ly with ddlmChords = ##t: the same cards with chord symbols.
sed 's/^ddlmChords = ##f$/ddlmChords = ##t/' "$here/Book.ly" >"$work/book-chords.ly"
grep -qx 'ddlmChords = ##t' "$work/book-chords.ly" \
  || { echo "build.sh: Book.ly has no line 'ddlmChords = ##f'" >&2; exit 1; }
ly mellophone-chords-cards "$work/book-chords.ly"
card_size "$out/mellophone-chords-cards.pdf"

: >"$out/songs.tsv"
for song in $(sed -n 's/^\\\([A-Za-z_]*\)-card$/\1/p' "$here/Book.ly"); do
  name=${song//_/-}
  { sed '/^\\[A-Za-z_]*-card$/d' "$here/Book.ly"; printf '\\%s-card\n' "$song"; } >"$work/$name.ly"
  ly "$name" "$work/$name.ly"
  card_size "$out/$name.pdf"
  title=$(sed -n 's/^[[:space:]]*piece *= *"\(.*\)"[[:space:]]*$/\1/p' "$here/$song.ly" | head -1)
  [ -n "$title" ] || title=$(echo "${song//_/ }" | sed 's/\b\(.\)/\u\1/g')
  chords=-
  if grep -q "withChords \\\\$song-chords " "$here/Songs.ily"; then
    { sed '/^\\[A-Za-z_]*-card$/d' "$work/book-chords.ly"; printf '\\%s-card\n' "$song"; } >"$work/$name-chords.ly"
    ly "$name-chords" "$work/$name-chords.ly"
    card_size "$out/$name-chords.pdf"
    chords=$name-chords.pdf
  fi
  printf '%s.pdf\t%s\t%s\n' "$name" "$title" "$chords" >>"$out/songs.tsv"
done

for book in mellophone mellophone-chords; do
  gs -q -dBATCH -dNOPAUSE -dSAFER --permit-file-read="$out/$book-cards.pdf" \
    -sDEVICE=pdfwrite -dDEVICEWIDTHPOINTS=792 -dDEVICEHEIGHTPOINTS=612 -dFIXEDMEDIA \
    -sIN="$out/$book-cards.pdf" -o "$out/$book-letter.pdf" "$here/letter-2up.ps"
done

echo "build.sh: $(wc -l <"$out/songs.tsv") songs in $out"
