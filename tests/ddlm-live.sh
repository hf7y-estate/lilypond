#!/usr/bin/env bash
# muertos/index.sh writes the ddlm page; muertos/check-live.sh reads it back
# off the running site. Green on a good page, red on each injected failure:
# a linked PDF or range report answering 404, a stale page (sha absent), a
# song PDF or the range report missing from the build. And #8's Done-when
# (Zach, 2026-11-02, quoted on #21: "Vi's hora needs chords. chords are
# generally missing."): red when a main PDF prints no chord symbol, when the
# no-chords alternate or a song with chords is not linked, or when the page
# has no build date; BLIND (exit 2) with no gs or a PDF that will not
# download. No LilyPond, no network: curl and gs are stubbed, and a stub
# "PDF" is the text gs would read out of it.
set -uo pipefail
root=$(git rev-parse --show-toplevel)
m=$root/muertos
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
fail=0
ok()  { if "$@" >"$t/log" 2>&1; then echo "ok: $*"; else echo "FAIL (want green): $*"; cat "$t/log"; fail=1; fi; }
red() { if "$@" >"$t/log" 2>&1; then echo "FAIL (want red): $*"; cat "$t/log"; fail=1; else echo "ok, red: $*"; fi; }
# says WANT CMD...: red, and the output says WANT (so it is red for that reason)
says() { local want=$1; shift
  if "$@" >"$t/log" 2>&1; then echo "FAIL (want red, [$want]): $*"; cat "$t/log"; fail=1
  elif grep -qF -- "$want" "$t/log"; then echo "ok, red [$want]: $*"
  else echo "FAIL (red, but not [$want]): $*"; cat "$t/log"; fail=1; fi; }
# blind CMD...: exit 2 and BLIND, never 0 or a plain red
blind() { "$@" >"$t/log" 2>&1; local rc=$?
  if [ $rc = 2 ] && grep -q '^BLIND: ' "$t/log"; then echo "ok, BLIND: $*"
  else echo "FAIL (want BLIND, exit 2; got $rc): $*"; cat "$t/log"; fail=1; fi; }

# The songs whose main card must carry chords: what check-live.sh reads.
songs=$(comm -12 <(sed -n 's/.*withChords \\\([a-z_]*\)-chords .*/\1/p' "$m/Songs.ily" | sort -u) \
                 <(sed -n 's/^\\\([A-Za-z_]*\)-card$/\1/p' "$m/Book.ly" | sort -u))
grep -qx vis_hora <<<"$songs" && echo "ok: vis_hora is a song with chords" \
  || { echo "FAIL: vis_hora is not among the songs with chords [$songs]"; fail=1; }

mkdir "$t/out" "$t/bin"
echo "F Mellophone Cm G7 Fm Am C G" >"$t/out/mellophone-cards.pdf"
echo "F Mellophone Cm G7 Fm Am C G" >"$t/out/mellophone-letter.pdf"
for f in mellophone-nochords-cards mellophone-nochords-letter; do echo "F Mellophone 0 12 2" >"$t/out/$f.pdf"; done
: >"$t/out/mellophone-range.txt"
printf 'la-llorona.pdf\tLa Llorona\t-\n' >"$t/out/songs.tsv"
echo "F Mellophone La Llorona Gm Cm" >"$t/out/la-llorona.pdf"
for s in $songs; do
  n=${s//_/-}
  [ "$s" = la_llorona ] && continue
  echo "F Mellophone $s Cm G7 Fm" >"$t/out/$n.pdf"
  echo "F Mellophone $s 0 12" >"$t/out/$n-nochords.pdf"
  title=$s; [ "$s" = vis_hora ] && title="Vi's Hora & <co>"
  printf '%s.pdf\t%s\t%s-nochords.pdf\n' "$n" "$title" "$n" >>"$t/out/songs.tsv"
done

ok "$m/index.sh" "$t/out" 0123456789abcdef "2026-11-02 00:00 UTC"
"$m/index.sh" "$t/out" 0123456789abcdef "2026-11-02 00:00 UTC" >"$t/page.html"
for want in 'href="mellophone-cards.pdf"' 'href="mellophone-letter.pdf"' 'href="mellophone-range.txt"' \
            'href="mellophone-nochords-cards.pdf"' 'href="mellophone-nochords-letter.pdf"' \
            'href="la-llorona.pdf">La Llorona<' "Vi's Hora &amp; &lt;co&gt;" '@0123456' 'Built 2026-11-02'; do
  grep -qF -- "$want" "$t/page.html" && echo "ok: page has $want" || { echo "FAIL: page lacks $want"; fail=1; }
done
cp "$t/page.html" "$t/good.html"

# curl: -w answers a status (404 for a URL holding $STUB_RED); -o FILE
# downloads $STUB_DIR/<basename> (exit 22 when absent, or when it holds
# $STUB_NOFILE); anything else prints the page.
cat >"$t/bin/curl" <<'STUB'
#!/usr/bin/env bash
url=${!#}
case " $* " in
  *" -w "*) case $url in *"${STUB_RED:-NONE}"*) printf 404 ;; *) printf 200 ;; esac ;;
  *" -o "*)
    out=; prev=
    for a in "$@"; do [ "$prev" = -o ] && out=$a; prev=$a; done
    case $url in *"${STUB_NOFILE:-NONE}"*) exit 22 ;; esac
    src=$STUB_DIR/${url##*/}
    [ -f "$src" ] || exit 22
    cp "$src" "$out" ;;
  *) cat "$STUB_PAGE" ;;
esac
STUB
# gs: -sDEVICE=txtwrite -o - FILE prints the stub PDF's text.
cat >"$t/bin/gs" <<'STUB'
#!/usr/bin/env bash
cat "${!#}"
STUB
chmod +x "$t/bin/curl" "$t/bin/gs"
live() { PATH="$t/bin:$PATH" STUB_PAGE="$t/page.html" STUB_DIR="$t/out" "$@"; }
cl=$m/check-live.sh
U=https://example.test/ddlm/

ok  live "$cl" $U 0123456
red live env STUB_RED=vis-hora.pdf "$cl" $U 0123456
# The range report the page links answers 404: red, same as a dead PDF.
red live env STUB_RED=mellophone-range.txt "$cl" $U 0123456
red live env STUB_RED=/ddlm/ "$cl" $U
red live "$cl" $U fedcba9

# ---- #8: the main book carries chords, read off the live PDFs
# Vi's Hora's main PDF is its no-chords card (the live site on 2026-11-03).
cp "$t/out/vis-hora.pdf" "$t/vis-hora.keep"; cp "$t/out/vis-hora-nochords.pdf" "$t/out/vis-hora.pdf"
says "NO CHORDS: vis-hora.pdf" live "$cl" $U 0123456
cp "$t/vis-hora.keep" "$t/out/vis-hora.pdf"
# The main book is the no-chords book.
cp "$t/out/mellophone-cards.pdf" "$t/cards.keep"; cp "$t/out/mellophone-nochords-cards.pdf" "$t/out/mellophone-cards.pdf"
says "NO CHORDS: mellophone-cards.pdf" live "$cl" $U 0123456
cp "$t/cards.keep" "$t/out/mellophone-cards.pdf"
# A title or rehearsal letter is not a chord: A B C, Gnossienne, Get, Angelito.
echo "F Mellophone Gnossienne Get Angelito A B C 12 0" >"$t/out/vis-hora.pdf"
says "NO CHORDS: vis-hora.pdf" live "$cl" $U 0123456
cp "$t/vis-hora.keep" "$t/out/vis-hora.pdf"
# The page drops Vi's Hora: its check is not dropped with it.
grep -v 'href="vis-hora.pdf"' "$t/good.html" >"$t/page.html"
says "page does not link vis-hora.pdf" live "$cl" $U 0123456
# The page drops the no-chords alternate.
grep -v 'href="mellophone-nochords-cards.pdf"' "$t/good.html" >"$t/page.html"
says "page does not link the no-chords alternate mellophone-nochords-cards.pdf" live "$cl" $U 0123456
# The page has no build date.
sed 's/Built [0-9-]*/Built/' "$t/good.html" >"$t/page.html"
says "page has no build date" live "$cl" $U 0123456
cp "$t/good.html" "$t/page.html"
ok  live "$cl" $U 0123456
# BLIND: a PDF that will not download, and no gs on PATH.
blind live env STUB_NOFILE=voodoo.pdf "$cl" $U 0123456
mkdir "$t/nogs"
for c in bash env curl grep sed sort comm cut tr wc cp rm mktemp dirname cat; do
  p=$(PATH="$t/bin:$PATH" command -v "$c") && ln -s "$p" "$t/nogs/$c"
done
blind env PATH="$t/nogs" STUB_PAGE="$t/page.html" STUB_DIR="$t/out" "$cl" $U 0123456

: >"$t/page.html"
red live "$cl" $U

rm "$t/out/mellophone-range.txt"
red "$m/index.sh" "$t/out" 0123456789abcdef "2026-11-02 00:00 UTC"
: >"$t/out/mellophone-range.txt"
rm "$t/out/vis-hora.pdf"
red "$m/index.sh" "$t/out" 0123456789abcdef "2026-11-02 00:00 UTC"

exit $fail
