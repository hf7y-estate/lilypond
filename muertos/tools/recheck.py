#!/usr/bin/env python3
"""recheck.py -- does one voice of a card still say what its source PDF says?

  recheck.py CARD.tsv VOICE SOURCE [--allow BARS]

CARD.tsv is what muertos/tools/ly-events.ily wrote for one card. VOICE is
the Nth voice in it (in order of first event). SOURCE is a PDF[:STAFF]
(read with pdf2ly.py, staff 1 by default) or a TSV in ly-events form.

Both sides become one token per note or chord (pitch classes, length) and
one per run of rests, and are lined up in order (difflib). Pitches are
compared as pitch classes after the one transposition (0-11 semitones)
that matches the most notes: a card may sit in another octave or be
written for another instrument. A card carries a selection of its source,
so measures only in the PDF are listed as "pdf only" and are not red.
Every card token that does not line up with the PDF is red.

Exit 0: every card token that differs lies in a card measure named by
--allow (BARS: "-" for none, or e.g. "14,16" or "20-23"; for a known
misreading or a known change of form, said in muertos/recheck.tsv), and
every allowed measure still differs. Exit 1: a difference outside the
allowed measures, or an allowed measure that now matches (drop it from
recheck.tsv, so it cannot later hide a new difference); each is named by
its card and PDF measures. Exit 2 (BLIND): a file that cannot be read, no
such voice, no notes on either side, a bad --allow, or a crash.
"""
import argparse
import collections
import difflib
import os
import sys
from fractions import Fraction as F

NAMES = ["c", "cis", "d", "es", "e", "f", "fis", "g", "as", "a", "bes", "b"]


def blind(msg):
    print(f"BLIND: {msg}")
    sys.exit(2)


def read_tsv(path):
    """-> {voice: [(bar, kind, (midi,...) or None, length)]}, chords grouped."""
    voices = collections.OrderedDict()
    try:
        lines = open(path).read().splitlines()
    except OSError as e:
        blind(f"{path}: {e.strerror}")
    for n, line in enumerate(lines, 1):
        f = line.split("\t")
        if len(f) != 7:
            blind(f"{path}:{n}: {len(f)} fields, want 7")
        bar, pos, _, kind, pitch, length, voice = f
        if kind == "tie":
            continue
        try:
            bar, pos, length = int(bar), F(pos), F(length)
        except ValueError:
            blind(f"{path}:{n}: not a number")
        evs = voices.setdefault(voice, collections.OrderedDict())
        key = (bar, pos)
        if kind == "note":
            if key in evs and evs[key][1] == "n":
                b, k, ps, ln = evs[key]
                evs[key] = (b, k, ps + (int(pitch),), ln)
            else:
                evs[key] = (bar, "n", (int(pitch),), length)
        elif kind in ("rest", "mrest"):
            evs.setdefault(key, (bar, "r", None, length))
        else:
            blind(f"{path}:{n}: unknown kind {kind!r}")
    return collections.OrderedDict((v, list(e.values())) for v, e in voices.items())


def pdf_events(spec):
    path, _, staff = spec.rpartition(":")
    if not path or not staff.isdigit():
        path, staff = spec, "1"
    if not os.path.isfile(path):
        blind(f"{path}: no such file")
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import pdf2ly  # needs PyMuPDF; only the PDF path does
    _, measures = pdf2ly.read(path, int(staff), lambda m: None)
    out = []
    for i, m in enumerate(measures, 1):
        for e in m.events:
            if e.kind == "note":
                out.append((i, "n", tuple(pdf2ly.midi(*p) for p in e.pitches), e.length()))
            elif e.kind == "rest":
                out.append((i, "r", None, e.length()))
            else:
                out.append((i, "r", None, F(e.count)))
    return out


def tokens(evs, shift):
    toks, bars = [], []
    for bar, kind, ps, length in evs:
        if kind == "r":
            if toks and toks[-1] == ("r",):
                continue
            toks.append(("r",))
        else:
            toks.append(("n", tuple(sorted({(p + shift) % 12 for p in ps})), length))
        bars.append(bar)
    return toks, bars


def best_shift(src, card):
    a = [t[1] for t in tokens(src, 0)[0] if t[0] == "n"]
    best = (-1, 0)
    for s in range(12):
        b = [t[1] for t in tokens(card, s)[0] if t[0] == "n"]
        m = sum(x.size for x in difflib.SequenceMatcher(None, a, b, autojunk=False).get_matching_blocks())
        best = max(best, (m, -s))
    return -best[1]


def show(toks):
    out = []
    for t in toks[:8]:
        if t[0] == "r":
            out.append("r")
        else:
            p = "<" + " ".join(NAMES[x] for x in t[1]) + ">" if len(t[1]) > 1 else NAMES[t[1][0]]
            out.append(f"{p}:{t[2]}")
    return " ".join(out) + (" ..." if len(toks) > 8 else "")


def span(bars, i, j):
    if i == j:
        return "-"
    return f"m{bars[i]}" if bars[i] == bars[j - 1] else f"m{bars[i]}-{bars[j - 1]}"


def parse_bars(spec):
    """'-' -> set(); '14,16' -> {14, 16}; '20-23' -> {20, 21, 22, 23}."""
    if spec == "-":
        return set()
    bars = set()
    for part in spec.split(","):
        lo, _, hi = part.partition("-")
        if not lo.isdigit() or (hi and not hi.isdigit()) or (hi and int(hi) < int(lo)):
            blind(f"--allow {spec!r}: want '-' or card measures like 14,16 or 20-23")
        bars.update(range(int(lo), int(hi or lo) + 1))
    return bars


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("card", nargs="?")
    ap.add_argument("voice", nargs="?", type=int)
    ap.add_argument("source", nargs="?")
    ap.add_argument("--allow", default="-")
    a = ap.parse_args()
    if not (a.card and a.voice and a.source):
        ap.error("CARD.tsv VOICE SOURCE are required")
    allowed = parse_bars(a.allow)
    voices = read_tsv(a.card)
    if a.voice < 1 or a.voice > len(voices):
        blind(f"{a.card}: no voice {a.voice} (it has {len(voices)})")
    card = list(voices.values())[a.voice - 1]
    if a.source.endswith(".tsv"):
        src = [e for v in read_tsv(a.source).values() for e in v]
    else:
        src = pdf_events(a.source)
    if not any(e[1] == "n" for e in card) or not any(e[1] == "n" for e in src):
        blind(f"no notes: card voice {a.voice} has {len(card)} events, source {len(src)}")
    shift = best_shift(src, card)
    st, sb = tokens(src, 0)
    ct, cb = tokens(card, shift)
    sm = difflib.SequenceMatcher(None, st, ct, autojunk=False)
    diff = red = 0
    differing = set()
    for op, i1, i2, j1, j2 in sm.get_opcodes():
        if op == "equal":
            continue
        if op == "delete":
            print(f"pdf only: pdf {span(sb, i1, i2)}: {show(st[i1:i2])}")
            continue
        bars = set(cb[j1:j2])
        differing |= bars
        diff += j2 - j1
        ok = bars <= allowed
        red += 0 if ok else j2 - j1
        print(f"{'allowed' if ok else 'DIFF'}: card {span(cb, j1, j2)} / pdf {span(sb, i1, i2)}: "
              f"card [{show(ct[j1:j2])}] pdf [{show(st[i1:i2])}]")
    stale = sorted(allowed - differing)
    if stale:
        print(f"STALE: --allow names card m{', m'.join(map(str, stale))}, which now match "
              f"the source: drop them from recheck.tsv")
    verdict = "ok" if not red and not stale else "RED"
    print(f"{verdict}: card voice {a.voice}: {len(ct) - diff}/{len(ct)} tokens match the source "
          f"(transposed {shift} semitones, pitch classes); {diff} differ, {red} outside --allow {a.allow}")
    return 0 if verdict == "ok" else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # never let a crash read as red-or-green
        blind(f"{type(e).__name__}: {e}")
