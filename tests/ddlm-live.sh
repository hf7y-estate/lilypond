#!/usr/bin/env bash
# muertos/index.sh writes the ddlm page; muertos/check-live.sh reads it back
# off the running site. Green on a good page, red on each injected failure:
# a linked PDF answering 404, a stale page (sha absent), a song PDF missing
# from the build. No LilyPond, no network: curl is stubbed.
set -uo pipefail
root=$(git rev-parse --show-toplevel)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
fail=0
ok()  { if "$@" >"$t/log" 2>&1; then echo "ok: $*"; else echo "FAIL (want green): $*"; cat "$t/log"; fail=1; fi; }
red() { if "$@" >"$t/log" 2>&1; then echo "FAIL (want red): $*"; cat "$t/log"; fail=1; else echo "ok, red: $*"; fi; }

mkdir "$t/out" "$t/bin"
for f in mellophone-cards mellophone-letter la-llorona vis-hora; do : >"$t/out/$f.pdf"; done
: >"$t/out/mellophone-range.txt"
printf 'la-llorona.pdf\tLa Llorona\nvis-hora.pdf\tVi'"'"'s Hora & <co>\n' >"$t/out/songs.tsv"

ok "$root/muertos/index.sh" "$t/out" 0123456789abcdef "2026-11-02 00:00 UTC"
"$root/muertos/index.sh" "$t/out" 0123456789abcdef "2026-11-02 00:00 UTC" >"$t/page.html"
for want in 'href="mellophone-cards.pdf"' 'href="mellophone-letter.pdf"' 'href="mellophone-range.txt"' \
            'href="la-llorona.pdf">La Llorona<' "Vi's Hora &amp; &lt;co&gt;" '@0123456'; do
  grep -qF -- "$want" "$t/page.html" && echo "ok: page has $want" || { echo "FAIL: page lacks $want"; fail=1; }
done

cat >"$t/bin/curl" <<'STUB'
#!/usr/bin/env bash
url=${!#}
case " $* " in
  *" -w "*) case $url in *"${STUB_RED:-NONE}"*) printf 404 ;; *) printf 200 ;; esac ;;
  *) cat "$STUB_PAGE" ;;
esac
STUB
chmod +x "$t/bin/curl"
live() { PATH="$t/bin:$PATH" STUB_PAGE="$t/page.html" "$@"; }

ok  live "$root/muertos/check-live.sh" https://example.test/ddlm/ 0123456
red live env STUB_RED=vis-hora.pdf "$root/muertos/check-live.sh" https://example.test/ddlm/ 0123456
red live env STUB_RED=/ddlm/ "$root/muertos/check-live.sh" https://example.test/ddlm/
red live "$root/muertos/check-live.sh" https://example.test/ddlm/ fedcba9
: >"$t/page.html"
red live "$root/muertos/check-live.sh" https://example.test/ddlm/

rm "$t/out/mellophone-range.txt"
red "$root/muertos/index.sh" "$t/out" 0123456789abcdef "2026-11-02 00:00 UTC"
: >"$t/out/mellophone-range.txt"
rm "$t/out/vis-hora.pdf"
red "$root/muertos/index.sh" "$t/out" 0123456789abcdef "2026-11-02 00:00 UTC"

exit $fail
