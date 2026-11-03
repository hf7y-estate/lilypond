#!/usr/bin/env bash
# muertos/check-live.sh [URL [EXPECT]] -- read the published book: URL
# (default https://hf7y.com/ddlm/) must answer 200, list at least one PDF,
# contain EXPECT if given (publish.sh passes the source sha, so a stale page
# is red), and every PDF and .txt it links must answer 200. Prints each status;
# exits 1 on any red.
#
# It also reads #8's Done-when off the live files, not off a build. Zach,
# 2026-11-02 (quoted by hf7y on #21): "Vi's hora needs chords. chords are
# generally missing." So the main book is the chords book:
#   - the page says when it was built ("Built YYYY-MM-DD");
#   - it links the main book (mellophone-cards.pdf, mellophone-letter.pdf)
#     and the no-chords alternate (mellophone-nochords-cards.pdf,
#     mellophone-nochords-letter.pdf);
#   - both main books, and the main <song>.pdf of every song whose card
#     Songs.ily builds \withChords and Book.ly prints (as build.sh reads
#     them), print at least one chord symbol (a root A-G with a quality:
#     Cm, G7, Am...). Each is downloaded and read with gs's txtwrite.
# The song list comes from Songs.ily and Book.ly next to this script, never
# from the page or the environment: a page that drops a song cannot drop
# its check.
# BLIND (exit 2): no gs, no Songs.ily or Book.ly, no song with chords in
# them, or a PDF that cannot be downloaded or read. Never read as green.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
url=${1:-https://hf7y.com/ddlm/}
expect=${2:-}
code() { curl -s -o /dev/null -I -L -w '%{http_code}' "$1"; }
blind() { echo "BLIND: $*"; exit 2; }
red=0
c=$(code "$url"); echo "$c $url"; [ "$c" = 200 ] || red=1
page=$(curl -s -L "$url")
if [ -n "$expect" ] && ! grep -qF -- "$expect" <<<"$page"; then
  echo "page does not mention $expect (not deployed yet?)"; red=1
fi
links=$(printf '%s\n' "$page" | grep -o 'href="[^"]*\.\(pdf\|txt\)"' | sed 's/^href="//; s/"$//' | sort -u)
grep -q '\.pdf$' <<<"$links" || { echo "no PDF links on $url"; red=1; }
for p in $links; do
  case $p in http*) u=$p ;; *) u=${url%/}/$p ;; esac
  c=$(code "$u"); echo "$c $u"; [ "$c" = 200 ] || red=1
done

# ---- #8's Done-when, read off the live files
grep -qE 'Built [0-9]{4}-[0-9]{2}-[0-9]{2}' <<<"$page" \
  || { echo "page has no build date (Built YYYY-MM-DD)"; red=1; }
[ -f "$here/Songs.ily" ] || blind "no $here/Songs.ily: cannot say which songs must print chords"
[ -f "$here/Book.ly" ] || blind "no $here/Book.ly: cannot say which songs are in the book"
# A song with chords that Book.ly prints (build.sh's own two readings).
songs=$(comm -12 <(sed -n 's/.*withChords \\\([a-z_]*\)-chords .*/\1/p' "$here/Songs.ily" | sort -u) \
                 <(sed -n 's/^\\\([A-Za-z_]*\)-card$/\1/p' "$here/Book.ly" | sort -u))
[ -n "$songs" ] || blind "no song in $here/Book.ly has a \\withChords card in Songs.ily"
command -v gs >/dev/null || blind "no gs: cannot read the chord symbols in the live PDFs"
for p in mellophone-nochords-cards.pdf mellophone-nochords-letter.pdf; do
  grep -qxF -- "$p" <<<"$links" || { echo "page does not link the no-chords alternate $p"; red=1; }
done
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
chords() {  # chords FILE.pdf: is FILE linked, and does it print a chord symbol?
  local p=$1 f text n
  grep -qxF -- "$p" <<<"$links" || { echo "page does not link $p (it must carry chords)"; red=1; return; }
  f=$work/$p
  curl -s -f -L -o "$f" "${url%/}/$p" && [ -s "$f" ] || blind "cannot download ${url%/}/$p"
  text=$(gs -q -dBATCH -dNOPAUSE -dSAFER -sDEVICE=txtwrite -o - "$f" 2>/dev/null | tr -d '\0') \
    || blind "gs cannot read $p"
  [ -n "$text" ] || blind "gs read no text from $p"
  n=$(grep -a -o '\b[A-G][b#♭♯]\?\(m\|7\|9\|6\|maj\|dim\|aug\|sus\|°\|ø\)' <<<"$text" | wc -l)
  if [ "$n" -gt 0 ]; then echo "chords: $p prints $n chord symbol(s)"
  else echo "NO CHORDS: $p prints no chord symbol (#8: the main book carries chords)"; red=1; fi
}
chords mellophone-cards.pdf
chords mellophone-letter.pdf
for s in $songs; do chords "${s//_/-}.pdf"; done
exit $red
