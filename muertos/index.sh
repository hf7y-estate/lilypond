#!/usr/bin/env bash
# muertos/index.sh OUTDIR SHA DATE -- print ddlm/index.html for a build.sh
# OUTDIR: the full book (cards and letter) at the top, then each song's card.
set -euo pipefail
out=${1:?usage: index.sh OUTDIR SHA DATE} sha=${2:?} date=${3:?}
esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'; }
for f in mellophone-cards.pdf mellophone-letter.pdf songs.tsv; do
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
</style>
</head>
<body>
<h1>Día de los Muertos: F Mellophone</h1>
<h2>The whole book</h2>
<ul>
<li><a href="mellophone-cards.pdf">Cards, 5.5×8.5in</a></li>
<li><a href="mellophone-letter.pdf">Letter, two cards per sheet (cut down the middle)</a></li>
</ul>
<h2>Songs</h2>
<ul>
HTML
while IFS=$'\t' read -r pdf title; do
  [ -f "$out/$pdf" ] || { echo "index.sh: songs.tsv names missing $pdf" >&2; exit 1; }
  printf '<li><a href="%s">%s</a></li>\n' "$(printf %s "$pdf" | esc)" "$(printf %s "$title" | esc)"
done <"$out/songs.tsv"
cat <<HTML
</ul>
<p><small>Built $(printf %s "$date" | esc) from
<a style="display:inline" href="https://github.com/hf7y-estate/lilypond/tree/$sha/muertos">hf7y-estate/lilypond@${sha:0:7}</a>.</small></p>
</body>
</html>
HTML
