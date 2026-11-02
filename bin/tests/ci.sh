#!/usr/bin/env bash
# Run every tests/*.sh; red if any is.
root=$(git rev-parse --show-toplevel)
rc=0
for t in "$root"/tests/*.sh; do
  echo "== $t"
  bash "$t" || { echo "RED: $t"; rc=1; }
done
exit $rc
