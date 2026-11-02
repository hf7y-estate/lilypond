#!/usr/bin/env bash
# muertos/mellophone.ily: fingering on the first occurrence of each written
# pitch in each system, a warning and a report line for each note outside
# F#3-C6, and a toggle that turns fingering off. Compiles
# muertos/mellophone-test.ly and variants of it with a failure injected,
# reads the fingerings back out of the PDF's text (gs txtwrite) and the
# range report mellophone.ily writes.
# Needs lilypond and gs. Without lilypond on PATH it says SKIP and checks
# nothing: LilyPond 2.24 is on the dexter host, not in the agent image.
set -uo pipefail
root=$(git rev-parse --show-toplevel)
if ! command -v lilypond >/dev/null || ! command -v gs >/dev/null; then
  echo "SKIP: no lilypond/gs on PATH; nothing checked"
  exit 0
fi
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
fail=0
src="$root/muertos/mellophone-test.ly"

# run NAME FILE: compile FILE; prints the fingerings, one per line
run() {
  lilypond -I "$root/muertos" -o "$t/$1" "$2" >"$t/$1.log" 2>&1 \
    || { echo "lilypond failed on $1:"; cat "$t/$1.log"; return 1; }
  gs -q -dBATCH -dNOPAUSE -dSAFER -sDEVICE=txtwrite -o - "$t/$1.pdf" \
    | tr -cs '0-9-' '\n' | grep -xE '0|1|2|1-2|2-3|1-3|1-2-3'
}
want() {  # want NAME GOT EXPECTED
  if [ "$2" = "$3" ]; then echo "ok: $1: $2"; else echo "FAIL: $1: got [$2], want [$3]"; fail=1; fi
}
# The fingerings of a score as a sorted list: gs reads text top to bottom,
# so page order is not note order (a fingering above a slur comes first).
sorted() { tr ' ' '\n' | grep . | sort | tr '\n' ' ' | sed 's/ $//'; }
fingers() { run "$@" | sorted; }
want_fingers() {  # want_fingers NAME FILE EXPECTED (in note order)
  want "$1" "$(fingers "$1" "$2")" "$(sorted <<<"$3")"
}

# Green: two systems, 11 notes, 9 fingerings (see the .ly's header).
want_fingers good "$src" "0 1-3 1-2 2 0 1-3 1-2 0 0"
want "range report" "$(sed -n 3p "$t/good-range.txt")" "$(printf 'mellophone-test\tC4\tC5\tnone')"
grep -q 'mellophone:' "$t/good.log" && { echo "FAIL: warning on an in-range score"; fail=1; }

# Injected: no \break, one system -> the second line's repeats lose theirs.
sed 's/\\break//' "$src" >"$t/nobreak.ly"
want_fingers nobreak "$t/nobreak.ly" "0 1-3 1-2 2 0 0"

# Injected: the repeated C4 in system 1 made an F4 -> it gets its own "1",
# so the green case's missing fingering there is the per-system rule.
sed 's/c4( d e c |/c4( d e f |/' "$src" >"$t/norepeat.ly"
want_fingers norepeat "$t/norepeat.ly" "0 1-3 1-2 1 2 0 1-3 1-2 0 0"

# Injected: written D6 and F3, outside the range: warned and reported.
sed 's/c1) |/c1 | d'\''1 | f,,,1) |/' "$src" >"$t/range.ly"
run range "$t/range.ly" >/dev/null
want "range warnings" "$(grep -o 'mellophone: .*' "$t/range.log" | tr '\n' ';')" \
  "mellophone: range, m5: written D6 is outside F#3-C6;mellophone: range, m6: written F3 is outside F#3-C6;"
want "range report, outside" "$(sed -n 3p "$t/range-range.txt")" "$(printf 'range\tF3\tD6\tm5 D6, m6 F3')"

# Toggle: mellophoneFingering = ##f before the include -> no fingerings.
sed 's/^\\include "mellophone.ily"/mellophoneFingering = ##f\n&/' "$src" >"$t/off.ly"
want_fingers off "$t/off.ly" ""
[ -s "$t/off-range.txt" ] && echo "ok: toggle off still writes the range report" \
  || { echo "FAIL: toggle off wrote no range report"; fail=1; }

exit $fail
