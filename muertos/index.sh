#!/usr/bin/env bash
# muertos/index.sh OUTDIR SHA DATE -- print ddlm/index.html for a build.sh
# OUTDIR: the full book (cards and letter) at the top, then each song's card.
# The main book has chord symbols (#8); an alternate without them
# (mellophone-nochords-*.pdf) and a song's third songs.tsv column (its
# -nochords.pdf, or -) add "without chords" links.
set -euo pipefail
out=${1:?usage: index.sh OUTDIR SHA DATE} sha=${2:?} date=${3:?}
esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }
for f in mellophone-cards.pdf mellophone-letter.pdf mellophone-range.txt songs.tsv; do
  [ -f "$out/$f" ] || { echo "index.sh: no $out/$f" >&2; exit 1; }
done
cat <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Día de los Muertos: F Mellophone</title>
<style>
body { font: 18px/1.5 system-ui, sans-serif; max-width: 36em; margin: 1em auto; padding: 0 1em; }
a { display: block; padding: .4em 0; }
li { list-style: none; border-bottom: 1px solid #ddd; }
ul { padding: 0; }
small { color: #666; }
a.with { display: inline; font-size: .85em; padding: 0 0 .4em; }
</style>
</head>
<body>
<h1>Día de los Muertos: F Mellophone</h1>
<h2>The whole book</h2>
<ul>
<li><a href="mellophone-cards.pdf">Cards with chord symbols, 5.5×6in</a></li>
<li><a href="mellophone-letter.pdf">Letter with chord symbols, two cards at the top of each sheet (bottom 2.5in blank for the lyre)</a></li>
HTML
for f in mellophone-nochords-cards.pdf mellophone-nochords-letter.pdf; do
  [ -f "$out/$f" ] || continue
  case $f in *cards*) what="Cards without chord symbols, 5.5×6in" ;;
             *) what="Letter without chord symbols, two cards at the top" ;; esac
  printf '<li><a href="%s">%s</a></li>\n' "$f" "$what"
done
cat <<HTML
<li><a href="mellophone-range.txt">Range check, written C4–C6 (text)</a></li>
</ul>
<h2>Songs</h2>
<ul>
HTML
while IFS=$'\t' read -r pdf title nochords; do
  [ -f "$out/$pdf" ] || { echo "index.sh: songs.tsv names missing $pdf" >&2; exit 1; }
  with=
  if [ -n "$nochords" ] && [ "$nochords" != - ]; then
    [ -f "$out/$nochords" ] || { echo "index.sh: songs.tsv names missing $nochords" >&2; exit 1; }
    with=$(printf ' <a class="with" href="%s">without chords</a>' "$(printf %s "$nochords" | esc)")
  fi
  printf '<li><a href="%s">%s</a>%s</li>\n' "$(printf %s "$pdf" | esc)" "$(printf %s "$title" | esc)" "$with"
done <"$out/songs.tsv"
cat <<HTML
</ul>
<p><small>Built $(printf %s "$date" | esc) from
<a style="display:inline" href="https://github.com/hf7y/lilypond/tree/$sha/muertos">hf7y/lilypond@${sha:0:7}</a>.</small></p>
</body>
</html>
HTML
