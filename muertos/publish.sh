#!/usr/bin/env bash
# muertos/publish.sh -- build the card book (build.sh), replace ddlm/ in
# hf7y/hf7y.github.io with it plus an index.html (index.sh), commit and push
# that repo's master, then wait until https://hf7y.com/ddlm/ serves this
# build with every PDF answering 200 (check-live.sh).
# Touches nothing in the site repo outside ddlm/. Refuses uncommitted
# changes under muertos/, so the page's source sha is what was built.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
site=${DDLM_SITE:-https://github.com/hf7y/hf7y.github.io.git}
live=${DDLM_LIVE:-https://hf7y.com/ddlm/}
tries=${DDLM_TRIES:-20}   # x30s waiting for Pages
die() { echo "publish.sh: $*" >&2; exit 1; }

if [ -n "$(git -C "$here" status --porcelain -- .)" ]; then
  die "uncommitted changes under muertos/; commit them first"
fi
sha=$(git -C "$here" rev-parse HEAD)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

"$here/build.sh" "$work/out"
git clone -q --depth 1 --branch master "$site" "$work/site"
rm -rf "$work/site/ddlm"
mkdir "$work/site/ddlm"
cp "$work/out"/*.pdf "$work/site/ddlm/"
"$here/index.sh" "$work/out" "$sha" "$(date -u '+%Y-%m-%d %H:%M UTC')" >"$work/site/ddlm/index.html"

cd "$work/site"
git add -A ddlm
outside=$(git diff --cached --name-only | grep -v '^ddlm/' || true)
[ -z "$outside" ] || die "would touch files outside ddlm/: $outside"
git commit -q -m "ddlm: F mellophone card book from hf7y-estate/lilypond@${sha:0:7}"
pushed=
for _ in 1 2 3; do
  if git push -q origin HEAD:master; then pushed=1; break; fi
  git pull -q --rebase origin master
done
[ -n "$pushed" ] || die "could not push to $site"
echo "publish.sh: pushed $(git rev-parse --short HEAD) to $site"

for i in $(seq 1 "$tries"); do
  if "$here/check-live.sh" "$live" "${sha:0:7}"; then exit 0; fi
  [ "$i" = "$tries" ] || sleep 30
done
die "$live is not serving this build after $tries tries"
