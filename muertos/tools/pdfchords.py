#!/usr/bin/env python3
"""pdfchords.py -- a source PDF's chord symbols, placed on a card (#6).

  pdfchords.py ONSETS.tsv VOICE PDF[:STAFF] --song NAME [--label L] > chords/NAME.ily
  pdfchords.py --parse SYMBOL...

ONSETS.tsv is what muertos/tools/ly-onsets.ily wrote for the card's
accompaniment at concert pitch (before Book.ly's \\transpose f c'). VOICE
is its Nth voice (in order of first event); STAFF (default 1) is the staff
of PDF that voice was read from.

Chord symbols are the PDF's non-bold text above a staff that reads as a
chord (pdf2ly.CHORD_SYMBOL); bold text there is a rehearsal mark. A symbol
may sit above another staff of the same system than STAFF (a chords staff):
its measure is found by x on its own staff, its beat is the event nearest
it there, and that point in time is carried to STAFF's measure at the same
x. The card's voice is lined up with STAFF note by note (difflib, pitch
classes after the one transposition that matches most notes, as
recheck.py does), and each chord lands at the card moment of the matched
note it falls on or after. A chord that falls in music the card does not
carry (or carries changed) is left out and listed in the output's header.

The output defines NAME-chords as a \\chordmode at the card's concert
pitch: each chord lasts until the next, the last to the card's end. A
source part for a transposing instrument is moved by \\transpose c X, X
the interval found above.

Exit 0 with the file on stdout. Exit 2 (BLIND): a symbol this does not
know how to spell (add it to QUALITIES, never guess), no chord symbols,
nothing placed, two chords at one moment, unreadable input, or a crash.
Run it with `python3 -I`; the PDF path needs PyMuPDF (python3-pymupdf).
Source PDFs are other people's arrangements: never commit them.
"""
import argparse
import collections
import difflib
import os
import re
import sys
from fractions import Fraction as F

ROOT = re.compile(r"([A-G])([#b♯♭]?)")
# Chord-symbol suffix -> LilyPond \chordmode modifier.
QUALITIES = {
    "": "", "M": "",
    "-": "m", "m": "m", "mi": "m", "min": "m",
    "7": "7", "9": "9", "6": "6",
    "-7": "m7", "m7": "m7", "mi7": "m7", "min7": "m7",
    "-6": "m6", "m6": "m6", "min6": "m6",
    "maj7": "maj7", "ma7": "maj7", "M7": "maj7", "Δ": "maj7", "Δ7": "maj7",
    "o": "dim", "dim": "dim", "o7": "dim7", "dim7": "dim7",
    "ø": "m7.5-", "ø7": "m7.5-", "m7b5": "m7.5-", "-7b5": "m7.5-",
    "+": "aug", "aug": "aug", "sus": "sus4", "sus4": "sus4", "sus2": "sus2",
}
STEPS = {"C": "c", "D": "d", "E": "e", "F": "f", "G": "g", "A": "a", "B": "b"}
ALTER = {"": "", "#": "is", "♯": "is", "b": "es", "♭": "es"}
# Card = source - s semitones; \transpose c TO[s] moves the source's chords there.
TO = ["c", "b", "bes", "a", "aes", "g", "fis", "f", "e", "ees", "d", "des"]
DURS = {F(2): "\\breve", F(3, 2): "1.", F(1): "1", F(3, 4): "2.", F(1, 2): "2",
        F(3, 8): "4.", F(1, 4): "4", F(3, 16): "8.", F(1, 8): "8", F(1, 16): "16"}


class Blind(Exception):
    pass


def note(letter, acc):
    n = STEPS[letter] + ALTER[acc]
    return {"ees": "es", "aes": "as"}.get(n, n)


def parse_chord(sym):
    """'B♭-' -> 'bes:m'; 'D7/G' -> 'd:7/g'; Blind on what it does not know."""
    s = sym.strip()
    main, _, bass = s.partition("/")
    m = ROOT.match(main)
    if not m:
        raise Blind(f"chord symbol {sym!r}: no root")
    q = main[m.end():]
    if q not in QUALITIES:
        raise Blind(f"chord symbol {sym!r}: unknown quality {q!r} (add it to QUALITIES)")
    out = note(*m.groups())
    if QUALITIES[q]:
        out += ":" + QUALITIES[q]
    if bass:
        b = ROOT.fullmatch(bass)
        if not b:
            raise Blind(f"chord symbol {sym!r}: bad bass {bass!r}")
        out += "/" + note(*b.groups())
    return out


def ly_dur(d):
    if d in DURS:
        return DURS[d]
    return f"1*{d.numerator}" + (f"/{d.denominator}" if d.denominator != 1 else "")


def with_dur(chord, d):
    root, colon, rest = chord.partition(":")
    if not colon:
        root, slash, bass = chord.partition("/")
        return root + ly_dur(d) + (slash + bass if slash else "")
    return root + ly_dur(d) + ":" + rest


# ------------------------------------------------------------- the card ---

def read_onsets(path):
    """-> ({voice: [(t, 'n'|'r', (midi,...)|None, length, bar)]}, end)."""
    voices = collections.OrderedDict()
    end = F(0)
    try:
        lines = open(path).read().splitlines()
    except OSError as e:
        raise Blind(f"{path}: {e.strerror}")
    for n, line in enumerate(lines, 1):
        f = line.split("\t")
        if len(f) != 6:
            raise Blind(f"{path}:{n}: {len(f)} fields, want 6")
        t, bar, kind, pitch, length, voice = f
        try:
            t, bar, length = F(t), int(bar), F(length)
        except ValueError:
            raise Blind(f"{path}:{n}: not a number")
        end = max(end, t + length)
        evs = voices.setdefault(voice, collections.OrderedDict())
        if kind == "note":
            if t in evs and evs[t][1] == "n":
                a, k, ps, ln, b = evs[t]
                evs[t] = (a, k, ps + (int(pitch),), ln, b)
            else:
                evs[t] = (t, "n", (int(pitch),), length, bar)
        elif kind == "rest":
            evs.setdefault(t, (t, "r", None, length, bar))
        else:
            raise Blind(f"{path}:{n}: unknown kind {kind!r}")
    return collections.OrderedDict((v, list(e.values())) for v, e in voices.items()), end


# -------------------------------------------------------------- the PDF ---

def measure_at(measures, x, sp):
    """Index of the measure a symbol at x belongs to: the last one starting
    at or before it (a symbol may start a little left of its barline)."""
    at = [i for i, m in enumerate(measures) if m.x0 - 0.5 * sp <= x]
    if not at or x >= measures[at[-1]].x1 + 0.5 * sp:
        return None
    return at[-1]


def pdf_reading(path, staff_no):
    """-> (events [(t, kind, pitches, length)] of staff STAFF_NO,
           chords [(t, symbol)] from every staff, in time order)."""
    if not os.path.isfile(path):
        raise Blind(f"{path}: no such file")
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    sys.dont_write_bytecode = True  # no __pycache__ in the checkout
    import pdf2ly  # needs PyMuPDF; only the PDF path does
    _, systems = pdf2ly.load(path)
    warn = lambda m: None

    def symbols(st):
        return [w for w in st.words if not w.bold and pdf2ly.CHORD_SYMBOL.fullmatch(w.text.strip())
                and st.top - 8 * st.sp < w.y <= st.top + 0.5 * st.sp]
    wanted = {staff_no} | {k for sysm in systems for k, st in enumerate(sysm, 1) if symbols(st)}
    read = {}  # (staff, system) -> [Measure]
    for k in sorted(wanted):
        state = {}
        for si, sysm in enumerate(systems):
            if k <= len(sysm):
                read[k, si] = pdf2ly.read_staff(sysm[k - 1], state, warn)
    pdf2ly.spell([m for si in range(len(systems)) for m in read.get((staff_no, si), [])])

    def lengths(m, time):
        bar = F(*time)
        out = []
        for e in m.events:
            if e.kind not in ("note", "rest"):
                out.append(bar * e.count)
            elif e.full:
                out.append(bar)
            else:
                out.append(e.length())
        return out

    events, starts, time = [], {}, (4, 4)
    t = F(0)
    for si in range(len(systems)):
        for mi, m in enumerate(read.get((staff_no, si), [])):
            time = m.time or time
            starts[si, mi] = (t, time)
            for e, ln in zip(m.events, lengths(m, time)):
                if e.kind == "note":
                    events.append((t, "n", tuple(pdf2ly.midi(*p) for p in e.pitches), ln))
                elif ln:
                    events.append((t, "r", None, ln))
                t += ln
            if not m.events:
                t += F(*time)
    chords = []
    for si, sysm in enumerate(systems):
        if (staff_no, si) not in read:
            continue
        ref = read[staff_no, si]
        for k, st in enumerate(sysm, 1):
            for w in symbols(st):
                mi = measure_at(ref, w.x, st.sp)
                if mi is None:
                    continue
                start, time = starts[si, mi]
                own = read.get((k, si), [])
                oi = measure_at(own, w.x, st.sp)
                pos = F(0)
                if oi is not None and own[oi].events:
                    m = own[oi]
                    near = min(range(len(m.events)), key=lambda i: abs(m.events[i].x - w.x))
                    pos = sum(lengths(m, time)[:near], F(0))
                chords.append((start + pos, w.text.strip()))
    chords.sort(key=lambda c: c[0])
    return events, chords


# ------------------------------------------------------------ placement ---

def tokens(evs, shift):
    """One token per note or chord (pitch classes, length), one per run of
    rests; -> (tokens, start time of each)."""
    toks, times = [], []
    for e in evs:
        t, kind, ps, length = e[:4]
        if kind == "r":
            if toks and toks[-1] == ("r",):
                continue
            toks.append(("r",))
        else:
            toks.append(("n", tuple(sorted({(p + shift) % 12 for p in ps})), length))
        times.append(t)
    return toks, times


def best_shift(src, card):
    a = [t[1] for t in tokens(src, 0)[0] if t[0] == "n"]
    best = (-1, 0)
    for s in range(12):
        b = [t[1] for t in tokens(card, s)[0] if t[0] == "n"]
        m = sum(x.size for x in difflib.SequenceMatcher(None, a, b, autojunk=False).get_matching_blocks())
        best = max(best, (m, -s))
    return -best[1]


def anchors(src, card, shift):
    """[(source time, card time)] of every token the two share, in order."""
    st, stt = tokens(src, 0)
    ct, ctt = tokens(card, shift)
    out = []
    for i, j, n in difflib.SequenceMatcher(None, st, ct, autojunk=False).get_matching_blocks():
        out += [(stt[i + k], ctt[j + k]) for k in range(n)]
    return out


def place(chords, pairs, end):
    """-> ([(card time, symbol)], [(source time, symbol, why)])."""
    placed, skipped = [], []
    for t, sym in chords:
        before = [p for p in pairs if p[0] <= t]
        after = [p for p in pairs if p[0] >= t]
        a = before[-1] if before else None
        b = after[0] if after else None
        if a and a[0] == t:
            c = a[1]
        elif a and b and b[1] - a[1] == b[0] - a[0]:
            c = a[1] + (t - a[0])            # inside music the card carries as is
        elif a and not b and a[1] + (t - a[0]) < end:
            c = a[1] + (t - a[0])
        elif b and not a and b[1] - (b[0] - t) >= 0:
            c = b[1] - (b[0] - t)
        else:
            skipped.append((t, sym, "the card does not carry this music as the source has it"))
            continue
        placed.append((c, sym))
    return placed, skipped


def bar_at(card_evs, t):
    bar = None
    for e in sorted(card_evs, key=lambda e: e[0]):
        if e[0] > t:
            break
        bar = e[4]
    return bar


def emit(song, label, placed, skipped, shift, end, card_evs):
    placed.sort(key=lambda c: c[0])
    for (t1, s1), (t2, s2) in zip(placed, placed[1:]):
        if t1 == t2:
            raise Blind(f"two chords at card moment {t1}: {s1!r} and {s2!r}")
    body, now = [], F(0)
    for i, (t, sym) in enumerate(placed):
        if t > now:
            body.append(f"\ts{ly_dur(t - now)}")
        nxt = placed[i + 1][0] if i + 1 < len(placed) else end
        body.append(f"\t{with_dur(parse_chord(sym), nxt - t)}  % m{bar_at(card_evs, t)} {sym}")
        now = nxt
    head = [f"% {song}-chords: the chord symbols of {label}, read and placed on the",
            "% card by muertos/tools/pdfchords.py (muertos/chords.sh --write); do not",
            "% hand-edit. Concert pitch: Songs.ily's \\transpose f c' writes them for",
            f"% the F mellophone with the notes. {len(placed)} placed, {len(skipped)} left out."]
    if shift:
        head.append(f"% The source part sits {shift} semitones above the card's concert pitch.")
    for t, sym, why in skipped:
        head.append(f"% left out: {sym} at source moment {t}: {why}")
    open_ = f"{song}-chords = " + (f"\\transpose c {TO[shift]} " if shift else "") + "\\chordmode {"
    return "\n".join(head + [open_] + body + ["}", ""])


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("onsets", nargs="?")
    ap.add_argument("voice", nargs="?", type=int)
    ap.add_argument("source", nargs="?")
    ap.add_argument("--song")
    ap.add_argument("--label")
    ap.add_argument("--parse", nargs="+", metavar="SYMBOL")
    a = ap.parse_args()
    if a.parse:
        for s in a.parse:
            print(f"{s}\t{parse_chord(s)}")
        return 0
    if not (a.onsets and a.voice and a.source and a.song):
        ap.error("ONSETS.tsv VOICE PDF[:STAFF] --song NAME are required")
    voices, end = read_onsets(a.onsets)
    if not 1 <= a.voice <= len(voices):
        raise Blind(f"{a.onsets}: no voice {a.voice} (it has {len(voices)})")
    card = list(voices.values())[a.voice - 1]
    path, _, staff = a.source.rpartition(":")
    if not path or not staff.isdigit():
        path, staff = a.source, "1"
    src, chords = pdf_reading(path, int(staff))
    if not chords:
        raise Blind(f"{path}: no chord symbols")
    for _, s in chords:
        parse_chord(s)
    if not any(e[1] == "n" for e in card) or not any(e[1] == "n" for e in src):
        raise Blind(f"no notes: card voice {a.voice} has {len(card)} events, source {len(src)}")
    shift = best_shift(src, card)
    placed, skipped = place(chords, anchors(src, card, shift), end)
    if not placed:
        raise Blind(f"none of the {len(chords)} chords of {path} lands on the card")
    sys.stdout.write(emit(a.song, a.label or os.path.basename(path), placed, skipped, shift, end,
                          [e for v in voices.values() for e in v]))
    for t, sym, why in skipped:
        print(f"left out: {sym} at source moment {t}: {why}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Blind as e:
        print(f"BLIND: {e}")
        sys.exit(2)
    except Exception as e:  # never let a crash read as a reading
        print(f"BLIND: {type(e).__name__}: {e}")
        sys.exit(2)
