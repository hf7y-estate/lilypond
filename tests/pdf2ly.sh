#!/usr/bin/env bash
# muertos/tools/pdf2ly.py reads a MuseScore-drawn PDF into LilyPond. It
# reads tests/pdf2ly-fixture.py's two-measure PDF (the real sources are other
# people's arrangements and stay out of the repo), and is red on each
# injected failure: a dropped beam must show as a "% CHECK" measure that
# does not add up (never silently fixed), a dropped sharp as the natural
# note, a dropped dot as a CHECK; --compare must give 100% for a part
# against itself and less for an altered one. That the ddlm song files carry
# no CHECK measure is tests/ddlm-barsum.sh's, which counts them from the notes.
#
# Needs PyMuPDF. dexter/tests' image has none and no pip, so without it this
# fetches one pinned wheel -- PyMuPDF 1.26.7, the version dexter's
# python3-pymupdf carries -- checks its sha256 against the one PyPI lists,
# and unpacks it into the temp dir. If it cannot (no network, a wrong hash,
# an import that fails) it says BLIND and is red: it used to say SKIP and
# pass, and the CI run of #13 graded it green having checked nothing.
set -uo pipefail
root=$(git rev-parse --show-toplevel)
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
WHL_URL=https://files.pythonhosted.org/packages/2a/6b/3de1714d734ff949be1e90a22375d0598d3540b22ae73eb85c2d7d1f36a9/pymupdf-1.26.7-cp310-abi3-manylinux_2_28_x86_64.whl
WHL_SHA=69dfc78f206a96e5b3ac22741263ebab945fdf51f0dbe7c5757c3511b23d9d72
blind() { echo "BLIND: $*; nothing checked"; exit 1; }
py() { python3 -I "$@"; }
if ! python3 -I -c 'import pymupdf' 2>/dev/null; then
  echo "no PyMuPDF installed: fetching the pinned wheel"
  curl -fsSL --retry 3 -o "$t/pymupdf.whl" "$WHL_URL" || blind "could not fetch $WHL_URL"
  got=$(sha256sum "$t/pymupdf.whl" | cut -d' ' -f1)
  [ "$got" = "$WHL_SHA" ] || blind "wheel sha256 $got, want $WHL_SHA"
  python3 -I -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' \
    "$t/pymupdf.whl" "$t/site" || blind "could not unpack the wheel"
  # -I drops PYTHONPATH, so the unpacked wheel goes on sys.path by hand.
  py() { python3 -I -c 'import runpy, sys; sys.path.insert(0, sys.argv[1]); sys.argv = sys.argv[2:]; runpy.run_path(sys.argv[0], run_name="__main__")' "$t/site" "$@"; }
  echo 'import pymupdf; print("PyMuPDF", pymupdf.VersionBind)' >"$t/probe.py"
  py "$t/probe.py" || blind "the pinned wheel does not import"
fi
fail=0
fx="$root/tests/pdf2ly-fixture.py"
r="$root/muertos/tools/pdf2ly.py"
has()  { if grep -qF -- "$2" "$3"; then echo "ok: $1"; else echo "FAIL: $1: no [$2] in $3:"; cat "$3"; fail=1; fi; }
hasnt(){ if grep -qF -- "$2" "$3"; then echo "FAIL: $1: [$2] in $3"; fail=1; else echo "ok: $1"; fi; }

read_fx() {  # read_fx NAME [--no-X]: fixture -> $t/NAME.ly, stderr $t/NAME.err
  py "$fx" "$t/$1.pdf" "${@:2}" || { echo "FAIL: fixture $1"; fail=1; return; }
  py "$r" "$t/$1.pdf" --name fx >"$t/$1.ly" 2>"$t/$1.err" || { echo "FAIL: pdf2ly on $1"; cat "$t/$1.err"; fail=1; }
}

# Green: key, time, pitches from key and accidental, dotted half, beam, rest.
read_fx good
has  "good: m1"  "\\clef \"treble\" \\key f \\major \\time 4/4 g'4 bes'2. |" "$t/good.ly"
has  "good: m2"  "c''8 d''8 r4 fis'2 |" "$t/good.ly"
has  "good: final bar" '\bar "|."' "$t/good.ly"
hasnt "good: no CHECK measure" "% CHECK m" "$t/good.ly"
py "$r" "$t/good.pdf" --name fx --to-concert f >"$t/horn.ly" 2>/dev/null
has  "--to-concert wraps" "fx-accompaniment = \\transpose c' f {" "$t/horn.ly"

# Injected: no beam -> the eighths read as quarters; m2 is 5/4 and says so.
read_fx nobeam --no-beam
has  "no beam: CHECK in file" "% CHECK m2: sums to 5/4, time is 4/4" "$t/nobeam.ly"
has  "no beam: CHECK on stderr" "CHECK m2: sums to 5/4" "$t/nobeam.err"
has  "no beam: notes as read, not fixed" "c''4 d''4 r4 fis'2 |" "$t/nobeam.ly"

# Injected: no sharp -> F natural.
read_fx nosharp --no-sharp
has  "no sharp: f'2" "c''8 d''8 r4 f'2 |" "$t/nosharp.ly"

# Injected: no dot -> m1 is 3/4; a short first measure is a pickup.
read_fx nodot --no-dot
has  "no dot: pickup, reported" "m1: pickup of 3/4" "$t/nodot.err"
has  "no dot: \\partial" "\\partial 2." "$t/nodot.ly"

# --compare: same part, interval 0 -> 100%; altered part -> less.
py "$r" --compare "$t/good.pdf" "$t/good.pdf" --interval 0 >"$t/same.txt" 2>&1
has  "compare: same part 100%" "matched 6 = 100.0%" "$t/same.txt"
py "$r" --compare "$t/good.pdf" "$t/nosharp.pdf" --interval 0 >"$t/diff.txt" 2>&1
hasnt "compare: altered part below 100%" "= 100.0% (pitch+duration" "$t/diff.txt"


exit $fail
