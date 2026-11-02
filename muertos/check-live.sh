#!/usr/bin/env bash
# muertos/check-live.sh [URL [EXPECT]] -- read the published book: URL
# (default https://hf7y.com/ddlm/) must answer 200, list at least one PDF,
# contain EXPECT if given (publish.sh passes the source sha, so a stale page
# is red), and every PDF it links must answer 200. Prints each status;
# exits 1 on any red.
set -uo pipefail
url=${1:-https://hf7y.com/ddlm/}
expect=${2:-}
code() { curl -s -o /dev/null -I -L -w '%{http_code}' "$1"; }
red=0
c=$(code "$url"); echo "$c $url"; [ "$c" = 200 ] || red=1
page=$(curl -s -L "$url")
if [ -n "$expect" ] && ! grep -qF -- "$expect" <<<"$page"; then
  echo "page does not mention $expect (not deployed yet?)"; red=1
fi
pdfs=$(printf '%s\n' "$page" | grep -o 'href="[^"]*\.pdf"' | sed 's/^href="//; s/"$//' | sort -u)
[ -n "$pdfs" ] || { echo "no PDF links on $url"; red=1; }
for p in $pdfs; do
  case $p in http*) u=$p ;; *) u=${url%/}/$p ;; esac
  c=$(code "$u"); echo "$c $u"; [ "$c" = 200 ] || red=1
done
exit $red
