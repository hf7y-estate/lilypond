#!/usr/bin/env python3
"""pdf2ly.py -- read one staff of a MuseScore vector PDF into LilyPond.

  pdf2ly.py PDF [--staff N] [--name SONG] [--title T] [--clef C]
                [--to-concert PITCH] > SONG.ly
  pdf2ly.py --compare CONCERT.pdf[:N] WRITTEN.pdf[:N] [--interval SEMIS]

Reads the notation MuseScore draws: SMuFL glyphs (Leland, Bravura or
MuseScore 3's "MScore") as text with positions (PyMuPDF rawdict), staff
lines, stems and barlines as stroked lines, beams as filled quads, ties
and slurs as filled curves.  It gives clef, key, time, pitch, rhythm
(notehead, flags, beams, dots, rests, multi-measure rests, triplets),
ties, slurs, barlines and repeats, voltas, rehearsal marks, tempo, text
above the staff, staccato/accent/tenuto/fermata and dynamics.

Every measure is summed against its time signature.  A measure that does
not add up is written as read, with a "% CHECK" comment, and listed on
stderr as "CHECK m<N>: ..."; nothing is filled in to make it add up.  A
short first measure is written as \\partial and reported as a pickup.

--staff N picks the Nth staff of every system (1 = top; default 1).
--to-concert PITCH wraps the music in \\transpose c' PITCH, for a part
written for a transposing instrument: f for horn in F, ees for alto sax
in Eb, bes for Bb.  --clef forces the output clef (pitches unchanged).

--compare reads staff N of each PDF and lines the notes up (difflib):
the concert part's pitches raised by --interval semitones (default 7,
what \\transpose f c' does) against the written part's.  It prints the
agreement as matched events / events in the longer part.

Run it with `python3 -I`; PyMuPDF is the Debian/Ubuntu python3-pymupdf
package.  Source PDFs are other people's arrangements: never commit them.
"""
import argparse
import difflib
import re
import sys
from fractions import Fraction as F

import pymupdf

NOTEHEADS = {0xE0A0: F(2), 0xE0A2: F(1), 0xE0A3: F(1, 2), 0xE0A4: F(1, 4)}
RESTS = {0xE4E2: F(2), 0xE4E3: F(1), 0xE4E4: F(1, 2), 0xE4E5: F(1, 4),
         0xE4E6: F(1, 8), 0xE4E7: F(1, 16), 0xE4E8: F(1, 32), 0xE4E9: F(1, 64)}
FLAGS = {0xE240: 1, 0xE241: 1, 0xE242: 2, 0xE243: 2, 0xE244: 3, 0xE245: 3,
         0xE246: 4, 0xE247: 4}
ACCIDENTALS = {0xE260: -1, 0xE261: 0, 0xE262: 1, 0xE263: 2, 0xE264: -2}
CLEFS = {0xE050: ("treble", 38), 0xE052: ("treble_8", 31),
         0xE053: ("treble^8", 45), 0xE062: ("bass", 26), 0xE05C: ("alto", 32),
         0xE069: ("percussion", 38)}
TOP_LINE = {"treble": 38, "treble_8": 31, "treble^8": 45, "bass": 26,
            "alto": 32, "tenor": 30, "percussion": 38}
ARTICS = {0xE4A0: "->", 0xE4A1: "->", 0xE4A2: "-.", 0xE4A3: "-.",
          0xE4A4: "--", 0xE4A5: "--", 0xE4AC: "-^", 0xE4AD: "-^",
          0xE4C0: "\\fermata", 0xE4C1: "\\fermata"}
DYN = {0xE520: "p", 0xE521: "m", 0xE522: "f", 0xE523: "r", 0xE524: "s",
       0xE525: "z", 0xE526: "n"}
DYNAMICS = {"ppp", "pp", "p", "mp", "mf", "f", "ff", "fff", "fp", "sf",
            "sfz", "fz", "rfz", "sfp"}
DOT = 0xE1E7
REPEAT_DOT = 0xE044
SEGNO, CODA = 0xE047, 0xE048
TIME_DIGITS = range(0xE080, 0xE08A)
TUPLET_DIGITS = range(0xE880, 0xE88A)
METRONOME = {0xE1D2: "1", 0xE1D3: "2", 0xE1D5: "4", 0xE1D7: "8",
             0xECA2: "1", 0xECA3: "2", 0xECA5: "4", 0xECA7: "8"}
CHORD_SYMBOL = re.compile(
    r"(?:[A-G][#b\u266f\u266d]?(?:maj|min|mi|m|M|o|\u00f8|dim|aug|sus|add|\+|-|\u0394|\d+|\(|\)|,)*"
    r"(?:/[A-G][#b\u266f\u266d]?)?\s*)+|N\.?C\.?")
STEPS = "cdefgab"
SEMIS = [0, 2, 4, 5, 7, 9, 11]
SHARPS = "fcgdaeb"
MAJOR_SHARP = ["c", "g", "d", "a", "e", "b", "fis", "cis"]
MAJOR_FLAT = ["c", "f", "bes", "ees", "aes", "des", "ges", "ces"]


def is_smufl(ch):
    return 0xE000 <= ord(ch) <= 0xF8FF


class Glyph:
    def __init__(self, cp, x, y, size, bbox):
        self.cp, self.x, self.y, self.size, self.bbox = cp, x, y, size, bbox


class Word:
    def __init__(self, text, bbox, bold, size):
        self.text, self.bbox, self.bold, self.size = text, bbox, bold, size
        self.x, self.y = bbox[0], bbox[3]


class Staff:
    def __init__(self, page, top, sp, x0, x1):
        self.page, self.top, self.sp, self.x0, self.x1 = page, top, sp, x0, x1
        self.bottom = top + 4 * sp
        self.glyphs, self.words, self.vlines, self.hlines = [], [], [], []
        self.beams, self.curves, self.boxes = [], [], []

    def dist(self, y):
        if self.top <= y <= self.bottom:
            return 0.0
        return min(abs(y - self.top), abs(y - self.bottom))


# ---------------------------------------------------------------- page ---

def read_page(page, pno):
    glyphs, words = [], []
    for b in page.get_text("rawdict")["blocks"]:
        for line in b.get("lines", []):
            for s in line["spans"]:
                text_chars = []
                for c in s["chars"]:
                    if is_smufl(c["c"]):
                        glyphs.append(Glyph(ord(c["c"]), c["origin"][0],
                                            c["origin"][1], s["size"], c["bbox"]))
                    else:
                        text_chars.append(c)
                if text_chars:
                    # split the span into words on wide gaps, keep spaces
                    cur = []
                    for c in text_chars:
                        if cur and c["bbox"][0] - cur[-1]["bbox"][2] > s["size"] * 1.2:
                            words.append(make_word(cur, s))
                            cur = []
                        cur.append(c)
                    words.append(make_word(cur, s))
    words = [w for w in words if w.text.strip()]
    hsegs, vsegs, beams, curves, boxes = [], [], [], [], []
    for d in page.get_drawings():
        items = d["items"]
        r = d["rect"]
        kinds = "".join(i[0] for i in items)
        if d["type"] in ("f", "fs") and d.get("fill") is not None:
            if "c" in kinds and r.width > 4:
                curves.append(r)
            elif kinds == "llll" and r.width < 500:
                pts = [items[0][1]] + [i[2] for i in items]
                beams.append((r, pts))
            elif kinds in ("re", "qu") or (kinds == "llll"):
                pass
        if d["type"] in ("s", "fs"):
            w = d.get("width") or 0
            if kinds in ("qu", "re") or (("c" in kinds or kinds == "llll")
                                         and r.width > 8 and r.height > 8):
                boxes.append(r)
                continue
            if "c" in kinds and r.width > 4:
                curves.append(r)
                continue
            for i in items:
                if i[0] != "l":
                    continue
                p, q = i[1], i[2]
                if abs(p.y - q.y) <= max(0.2, 0.08 * abs(p.x - q.x)) and abs(p.x - q.x) > 0.5:
                    # level, or nearly (tuplet brackets slope a little)
                    hsegs.append((min(p.x, q.x), max(p.x, q.x), (p.y + q.y) / 2, w))
                elif abs(p.x - q.x) < 0.2 and abs(p.y - q.y) > 0.5:
                    vsegs.append((p.x, min(p.y, q.y), max(p.y, q.y), w))
    return glyphs, words, hsegs, vsegs, beams, curves, boxes


def make_word(chars, span):
    text = "".join(c["c"] for c in chars)
    x0 = min(c["bbox"][0] for c in chars)
    x1 = max(c["bbox"][2] for c in chars)
    y0 = min(c["bbox"][1] for c in chars)
    y1 = max(c["origin"][1] for c in chars)
    bold = "Bold" in span["font"] or (span["flags"] & 16) != 0
    w = Word(text, (x0, y0, x1, y1), bold, span["size"])
    w.italic = "Italic" in span["font"] or (span["flags"] & 2) != 0
    return w


def find_staves(pno, hsegs):
    """Five equally spaced horizontal lines sharing an x-range = a staff."""
    rows = {}
    for x0, x1, y, w in hsegs:
        if x1 - x0 < 20:
            continue
        rows.setdefault(round(y, 1), []).append((x0, x1))
    spans = {}
    for y, segs in rows.items():
        segs.sort()
        merged = []
        for a, b in segs:
            if merged and a <= merged[-1][1] + 1.0:
                merged[-1][1] = max(merged[-1][1], b)
            else:
                merged.append([a, b])
        spans[y] = [m for m in merged if m[1] - m[0] > 40]
    ys = sorted(y for y in spans if spans[y])
    staves, used = [], set()
    for i, y in enumerate(ys):
        if y in used:
            continue
        for j in range(i + 1, min(i + 4, len(ys))):
            sp = ys[j] - y
            if not 3.0 <= sp <= 12.0:
                continue
            lines = [y]
            for k in range(1, 5):
                hit = [v for v in ys if abs(v - (y + k * sp)) < 0.35 and v not in used]
                if not hit:
                    break
                lines.append(hit[0])
            if len(lines) == 5:
                for a, b in spans[y]:
                    staves.append(Staff(pno, y, (lines[4] - y) / 4, a, b))
                used.update(lines)
                break
    return staves


def group_systems(staves, vsegs):
    """Staves joined by one vertical line (the system's start barline) are
    one system."""
    parent = list(range(len(staves)))

    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for x, y0, y1, w in vsegs:
        # MuseScore draws a spanning barline per staff, from its top line
        # to the next staff's top line: touching both joins them
        cover = [i for i, s in enumerate(staves)
                 if s.x0 - 3 <= x <= s.x1 + 3 and y0 <= s.bottom + 0.8 and y1 >= s.top - 0.8]
        if len(cover) > 1:
            for i in cover[1:]:
                parent[root(i)] = root(cover[0])
    groups = {}
    for i, s in enumerate(staves):
        groups.setdefault(root(i), []).append(s)
    systems = sorted(groups.values(), key=lambda g: (g[0].page, min(s.top for s in g)))
    return [sorted(g, key=lambda s: s.top) for g in systems]


def assign(staves, glyphs, words, hsegs, vsegs, beams, curves, boxes):
    def nearest(x, y, margin=4.0):
        best, bd = None, None
        for s in staves:
            if not s.x0 - 30 <= x <= s.x1 + 10:
                continue
            d = s.dist(y)
            if bd is None or d < bd:
                best, bd = s, d
        return best
    for g in glyphs:
        s = nearest(g.x, g.y)
        if s:
            s.glyphs.append(g)
    for w in words:
        s = nearest((w.bbox[0] + w.bbox[2]) / 2, w.y)
        if s:
            s.words.append(w)
    for v in vsegs:
        for s in staves:
            if s.x0 - 3 <= v[0] <= s.x1 + 3 and v[1] <= s.bottom + 4 * s.sp and v[2] >= s.top - 4 * s.sp:
                s.vlines.append(v)
    for h in hsegs:
        s = nearest((h[0] + h[1]) / 2, h[2])
        if s:
            s.hlines.append(h)
    for b in beams:
        s = nearest(b[0].x0 + b[0].width / 2, (b[0].y0 + b[0].y1) / 2)
        if s:
            s.beams.append(b)
    for c in curves:
        s = nearest(c.x0 + c.width / 2, (c.y0 + c.y1) / 2)
        if s:
            s.curves.append(c)
    for b in boxes:
        s = nearest(b.x0 + b.width / 2, b.y1)
        if s:
            s.boxes.append(b)


def load(path):
    doc = pymupdf.open(path)
    systems = []
    for pno, page in enumerate(doc):
        glyphs, words, hsegs, vsegs, beams, curves, boxes = read_page(page, pno)
        staves = find_staves(pno, hsegs)
        if not staves:
            continue
        assign(staves, glyphs, words, hsegs, vsegs, beams, curves, boxes)
        systems += group_systems(staves, vsegs)
    return doc, systems


# --------------------------------------------------------------- staff ---

class Event:
    def __init__(self, x, kind, dur):
        self.x, self.kind, self.dur = x, kind, dur
        self.heads = []          # [(diatonic, explicit alteration or None, y)]
        self.dots = 0
        self.tuplet = None       # (id, num, den)
        self.tie = False
        self.slur_start = self.slur_end = False
        self.artics, self.markups, self.dyn = [], [], None
        self.pitches = []        # [(diatonic, alteration)] after key/accidentals
        self.count = 1           # multi-measure rest count
        self.full = False        # whole rest filling the measure

    def length(self):
        d = self.dur * (2 - F(1, 2 ** self.dots))
        if self.tuplet:
            d = d * self.tuplet[2] / self.tuplet[1]
        return d


class Measure:
    def __init__(self):
        self.events = []
        self.start_bar = None
        self.end_bar = "|"
        self.marks = []          # lilypond strings before the first event
        self.time = None
        self.key = None
        self.clef = None
        self.volta_start = None
        self.volta_end = False
        self.x0 = self.x1 = 0


def stem_width(staff):
    ws = sorted(round(v[3], 2) for v in staff.vlines if v[2] - v[1] < 4.5 * staff.sp)
    return ws[len(ws) // 2] if ws else 0.6


def read_staff(staff, state, warn):
    sp = staff.sp
    gsize = 4 * sp
    gl = sorted(staff.glyphs, key=lambda g: g.x)
    heads = [g for g in gl if g.cp in NOTEHEADS]
    small = [g for g in heads if g.size < 0.8 * gsize]
    if small:
        warn(f"skipped {len(small)} grace/cue notehead(s)")
    heads = [g for g in heads if g.size >= 0.8 * gsize]
    rests = [g for g in gl if g.cp in RESTS and g.size >= 0.8 * gsize]
    sw = stem_width(staff)

    # barlines: vertical lines covering the staff, wider than a stem or with
    # no notehead at their foot
    bars = []
    for x, y0, y1, w in staff.vlines:
        if y0 <= staff.top + 0.8 and y1 >= staff.bottom - 0.8:
            near = [h for h in heads if -0.5 * sp <= x - h.x <= 1.6 * sp
                    and y0 - sp <= h.y <= y1 + sp]
            if w > sw + 0.08 or not near:
                if x > staff.x0 + 1.0:
                    bars.append((x, w))
    bars.sort()
    groups = []
    for x, w in bars:
        if groups and x - groups[-1][-1][0] < 1.5 * sp:
            groups[-1].append((x, w))
        else:
            groups.append([(x, w)])
    thick = max([w for g in groups for _, w in g] + [0])
    barlines = []
    for g in groups:
        kinds = "".join("T" if w > 1.6 * sw and w > thick * 0.7 and thick > 1.2 else "t"
                        for _, w in g)
        x0, x1 = g[0][0], g[-1][0]
        dl = any(gg.cp == REPEAT_DOT and x0 - 1.5 * sp <= gg.x < x0 for gg in gl)
        dr = any(gg.cp == REPEAT_DOT and x1 < gg.x <= x1 + 1.5 * sp for gg in gl)
        if kinds in ("t",):
            typ = "|"
        elif kinds == "tt":
            typ = "||"
        elif kinds.startswith("T") and len(kinds) > 1 and not kinds.endswith("T"):
            typ = ".|"
        elif kinds.endswith("T") and len(kinds) > 1 and not kinds.startswith("T"):
            typ = "|."
        else:
            typ = "|"
        if dl and dr:
            typ = ":|.|:" if len(kinds) > 2 else ":..:"
        elif dl:
            typ = ":|."
        elif dr:
            typ = ".|:"
        barlines.append((x0, x1, typ))

    # prefix: clef, key, time at the start of the staff
    first_x = min([h.x for h in heads] + [r.x for r in rests] + [staff.x1])
    first_bar = barlines[0][0] if barlines else staff.x1
    pre_end = min(first_x, first_bar + 0.1)
    clef = None
    for g in gl:
        if g.cp in CLEFS and g.x < staff.x0 + 8 * sp:
            clef = CLEFS[g.cp][0]
            break
    if clef is None:
        clef = state.get("clef", "treble")
    def attached(acc):
        return any(0.3 * sp < h.x - acc.x < 3.2 * sp and abs(h.y - acc.y) < 0.3 * sp
                   for h in heads)
    key_accs = [g for g in gl if g.cp in (0xE260, 0xE262) and g.x < pre_end
                and g.x < staff.x0 + 14 * sp and not attached(g)]
    nflat = sum(1 for g in key_accs if g.cp == 0xE260)
    nsharp = sum(1 for g in key_accs if g.cp == 0xE262)
    key = state.get("key", (0, 0))
    if key_accs:
        key = (nsharp, nflat)
    elif not key_accs and state.get("key") is None:
        key = (0, 0)
    # time signatures anywhere inside the staff (digits at mid-staff height)
    times = []
    tdig = [g for g in gl if g.cp in TIME_DIGITS and staff.top - 0.6 * sp <= g.y <= staff.bottom + 0.6 * sp]
    for g in tdig:
        times.append(g)
    tsig = []
    used = set()
    for g in tdig:
        if id(g) in used:
            continue
        col = [h for h in tdig if abs(h.x - g.x) < 2.5 * sp and id(h) not in used]
        for h in col:
            used.add(id(h))
        mid = staff.top + 2 * sp
        num = "".join(str(h.cp - 0xE080) for h in sorted(col, key=lambda h: h.x) if h.y < mid)
        den = "".join(str(h.cp - 0xE080) for h in sorted(col, key=lambda h: h.x) if h.y > mid)
        if num and den:
            tsig.append((min(h.x for h in col), (int(num), int(den))))
    for g in gl:
        if g.cp in (0xE08A, 0xE08B):
            tsig.append((g.x, (4, 4) if g.cp == 0xE08A else (2, 2)))
    last_bar = barlines[-1][1] if barlines else staff.x1
    tsig = [t for t in tsig if t[0] < last_bar - 0.5 or not barlines]
    prefix_x = max([g.x + 1.2 * sp for g in key_accs] +
                   [t[0] + 2 * sp for t in tsig if t[0] < first_x] +
                   [staff.x0 + 3 * sp])

    # stems
    stems = [v for v in staff.vlines if v[3] <= sw + 0.08 and v[2] - v[1] < 12 * sp]

    def stem_of(h):
        # a stem stands at the notehead's left edge (down) or right edge (up)
        hw = (h.bbox[2] - h.bbox[0]) if h.bbox else 1.2 * sp
        best = None
        for v in stems:
            x, y0, y1, _ = v
            if -0.4 * sp <= x - h.x <= hw + 0.4 * sp and y0 - 0.6 * sp <= h.y <= y1 + 0.6 * sp:
                d = (round(min(abs(x - h.x), abs(x - h.x - hw)), 1), min(abs(h.y - y0), abs(h.y - y1)))
                if best is None or d < best[0]:
                    best = (d, v)
        return best[1] if best else None

    # chords: heads sharing a stem, or whole notes at one x
    chords = {}
    for h in heads:
        if NOTEHEADS[h.cp] >= 1:
            k = ("w", round(h.x / (1.5 * sp)))
            # merge with an existing whole chord close in x
            for kk in list(chords):
                if kk[0] == "w" and abs(chords[kk][0][0].x - h.x) < 1.5 * sp:
                    k = kk
                    break
            chords.setdefault(k, []).append((h, None))
        else:
            st = stem_of(h)
            k = ("s", st) if st else ("n", h.x, h.y)
            chords.setdefault(k, []).append((h, st))
    events = []
    for k, members in chords.items():
        hs = [m[0] for m in members]
        st = members[0][1]
        ev = Event(min(h.x for h in hs), "note", min(NOTEHEADS[h.cp] for h in hs))
        ev.stem = st
        for h in hs:
            pos = round((h.y - staff.top) / (sp / 2))
            ev.heads.append([TOP_LINE[clef] - pos, None, h.y, h.x])
        if st is not None and ev.dur == F(1, 4):
            x, y0, y1, _ = st
            up = abs(min(hh.y for hh in hs) - y0) > abs(max(hh.y for hh in hs) - y1)
            tip = y0 if up else y1
            n = 0
            for g in gl:
                if g.cp in FLAGS and abs(g.x - x) < 0.8 * sp and abs(g.y - tip) < 1.5 * sp:
                    n = max(n, FLAGS[g.cp])
            nb = 0
            for r, pts in staff.beams:
                if r.x0 - 0.6 <= x <= r.x1 + 0.6 and r.height < 3 * sp:
                    yb = beam_y(pts, x)
                    if yb is not None and y0 - 0.6 * sp <= yb <= y1 + 0.6 * sp:
                        nb += 1
            n = max(n, nb)
            ev.dur = F(1, 4 * 2 ** n)
            ev.beams = nb
        events.append(ev)
    for r in rests:
        if r.x < prefix_x - sp:
            continue
        ev = Event(r.x, "rest", RESTS[r.cp])
        ev.heads = []
        ev.y = r.y
        events.append(ev)
    # multi-measure rests: thick horizontal bar at mid-staff + number above
    for x0, x1, y, w in staff.hlines:
        if w > 0.4 * sp and x1 - x0 > 3 * sp and abs(y - (staff.top + 2 * sp)) < sp:
            digits = sorted([g for g in gl if g.cp in TIME_DIGITS and x0 - sp <= g.x <= x1
                             and g.y < staff.top - 0.5 * sp], key=lambda g: g.x)
            ev = Event(x0, "mrest", F(1))
            ev.count = int("".join(str(g.cp - 0xE080) for g in digits) or "1")
            events.append(ev)
    if any(g.cp in (0xE4EF, 0xE4F0, 0xE4F1) for g in gl):
        xs = [g for g in gl if g.cp == 0xE4EF]
        for g in xs:
            digits = sorted([d for d in gl if d.cp in TIME_DIGITS and d.y < staff.top - 0.5 * sp
                             and g.x - sp <= d.x <= g.x + 30 * sp], key=lambda d: d.x)
            ev = Event(g.x, "mrest", F(1))
            ev.count = int("".join(str(d.cp - 0xE080) for d in digits[:3]) or "1")
            events.append(ev)
    events.sort(key=lambda e: e.x)

    # dots, accidentals, articulations
    for ev in events:
        if ev.kind == "mrest":
            continue
        right = max([h[3] for h in ev.heads] + [ev.x]) + 0.9 * sp
        ys = [h[2] for h in ev.heads] or [getattr(ev, "y", staff.top + 2 * sp)]
        dots = sorted({round(g.x, 0) for g in gl if g.cp == DOT and right <= g.x <= right + 2.6 * sp
                       and min(abs(g.y - y) for y in ys) < 0.8 * sp
                       and not any(e2 is not ev and e2.x <= g.x and e2.x > ev.x for e2 in events)})
        ev.dots = len(dots)
        for h in ev.heads:
            for g in gl:
                if g.cp in ACCIDENTALS and 0.3 * sp < h[3] - g.x < 3.2 * sp and abs(g.y - h[2]) < 0.3 * sp \
                        and g.x > prefix_x - sp:
                    h[1] = ACCIDENTALS[g.cp]
        if ev.kind == "note":
            for g in gl:
                if g.cp in ARTICS and abs(g.x - ev.x) < 1.2 * sp:
                    a = ARTICS[g.cp]
                    if a not in ev.artics:
                        ev.artics.append(a)

    # dynamics: runs of dynamic letters below the staff
    dl = [g for g in gl if g.cp in DYN]
    used = set()
    for g in dl:
        if id(g) in used:
            continue
        run = [h for h in dl if abs(h.y - g.y) < 0.5 * sp and 0 <= h.x - g.x < 3 * sp]
        for h in run:
            used.add(id(h))
        word = "".join(DYN[h.cp] for h in sorted(run, key=lambda h: h.x))
        if word in DYNAMICS:
            tgt = nearest_event(events, g.x, sp)
            if tgt:
                tgt.dyn = word

    # tuplets
    tdigs = [(g.x, g.y, g.cp - 0xE880, None) for g in gl if g.cp in TUPLET_DIGITS]
    # MuseScore 3 can set the tuplet number as text: a lone digit with a
    # bracket at its height
    for w in staff.words:
        t = w.text.strip()
        if re.fullmatch(r"[2-9]", t) and w.x > staff.x0 + 2 * sp:
            yc = (w.bbox[1] + w.bbox[3]) / 2
            if any(h[1] >= w.x - 1.5 * sp and h[0] <= w.x + 2.5 * sp and abs(h[2] - yc) < 1.5 * sp
                   and h[3] < 1.2 and hooked(h, staff.vlines, sp)
                   for h in staff.hlines):
                tdigs.append((w.x, yc, int(t), w))
            elif getattr(w, "italic", False) and any(
                    r.x0 - sp <= w.x <= r.x1 and min(abs(yc - r.y0), abs(yc - r.y1)) < 3 * sp
                    for r, _ in staff.beams):
                tdigs.append((w.x, yc, int(t), w))     # unbracketed, over a beam
    tdigs.sort(key=lambda d: d[0])
    tid = state.setdefault("tid", 0)
    state["tuplet_words"] = {id(d[3]) for d in tdigs if d[3] is not None}
    for gx, gy, n, _ in tdigs:
        g = Glyph(0, gx, gy, 0, None)
        if n < 2:
            continue
        den = {3: 2, 5: 4, 6: 4, 7: 4, 2: 3, 4: 3}.get(n, n - 1)
        # a bracket is two halves either side of its number
        brk = [h for h in staff.hlines if h[1] >= g.x - 1.5 * sp and h[0] <= g.x + 2.5 * sp
               and abs(h[2] - g.y) < 2 * sp and h[1] - h[0] < 30 * sp and h[3] < 1.2
               and hooked(h, staff.vlines, sp)]
        if brk:
            bx0 = min(h[0] for h in brk) - 0.5 * sp
            bx1 = max(h[1] for h in brk) + 0.5 * sp
            members = [e for e in events if e.kind != "mrest" and bx0 <= e.x <= bx1]
        else:
            members = beam_group(events, g.x, sp)
        if not members:
            # nearest n events around the digit
            srt = sorted(events, key=lambda e: abs(e.x + 0.6 * sp - g.x))[:n]
            members = sorted(srt, key=lambda e: e.x)
        tid += 1
        for e in members:
            e.tuplet = (tid, n, den)
    state["tid"] = tid

    # ties and slurs
    pend_tie = state.pop("tie_pending", None)
    for c in staff.curves:
        left = [e for e in events if e.kind == "note" and e.x <= c.x0 + 0.5 * sp]
        right = [e for e in events if e.kind == "note" and e.x >= c.x0 + 0.5 * sp and e.x <= c.x1 + 0.5 * sp]
        le = max(left, key=lambda e: e.x) if left and c.x0 - max(left, key=lambda e: e.x).x < 3 * sp else None
        re_ = min([e for e in events if e.kind == "note" and e.x > (le.x if le else c.x0 - sp)],
                  key=lambda e: e.x, default=None)
        re_ = re_ if re_ and abs(re_.x - c.x1) < 3 * sp else None
        if le is None and re_ is not None and c.x0 < prefix_x + 3 * sp:
            continue                      # continuation from the last system
        if le is not None and re_ is None and c.x1 > (barlines[-1][0] if barlines else staff.x1) - 3 * sp:
            le.tie_open = True            # tie or slur into the next system
            continue
        if le is None or re_ is None:
            continue
        if set(h[0] for h in le.heads) & set(h[0] for h in re_.heads) and \
                [e for e in events if le.x < e.x < re_.x] == []:
            le.tie = True
        else:
            le.slur_start = True
            re_.slur_end = True

    # text: rehearsal marks in boxes, voltas, tempo, words above the staff
    marks = []        # (x, lilypond)
    voltas = []       # (x0, x1, text)
    for w in staff.words:
        t = w.text.strip()
        boxed = any(b.x0 - 2 <= w.bbox[0] and w.bbox[2] <= b.x1 + 2 and b.y0 - 2 <= w.bbox[1]
                    and w.bbox[3] <= b.y1 + 2 for b in staff.boxes)
        if w.x < staff.x0 + 2 * sp and re.fullmatch(r"\d+", t):
            continue                      # measure number
        if w.x < staff.x0 - 2:
            continue                      # instrument name
        if boxed:
            marks.append((w.x, f'\\mark \\markup \\box "{esc(t)}"'))
            continue
        if re.fullmatch(r"\d+\.(\s*\d+\.)*", t) and w.y < staff.top:
            hs = [h for h in staff.hlines if h[0] <= w.x + sp and h[1] >= w.x and abs(h[2] - w.bbox[1]) < 2 * sp
                  and h[3] < 1.2 and h[1] - h[0] > 2 * sp]
            x1 = max([h[1] for h in hs], default=w.x + 4 * sp)
            voltas.append((w.x - sp, x1, t))
            continue
        m = re.match(r"^\s*=\s*(\d+)", t)
        mg = [g for g in gl if g.cp in METRONOME and 0 <= w.x - g.x < 3 * sp and abs(g.y - w.y) < sp]
        if m and mg:
            marks.append((mg[0].x, f"\\tempo {METRONOME[mg[0].cp]} = {m.group(1)}"))
            continue
        if id(w) in state["tuplet_words"] or CHORD_SYMBOL.fullmatch(t):
            continue                      # tuplet number; chord symbols are not read here
        if w.y <= staff.top and w.y > staff.top - 5.5 * sp:
            tgt = nearest_event(events, w.x + 2 * sp, 10 * sp, after=w.x - 2 * sp)
            if tgt:
                tgt.markups.append(f'^\\markup "{esc(t)}"')
    for g in gl:
        if g.cp in (SEGNO, CODA):
            marks.append((g.x, '\\mark \\markup \\musicglyph "scripts.%s"' % ("segno" if g.cp == SEGNO else "coda")))

    # measures
    edges = [b for b in barlines if b[0] > prefix_x - 2 * sp or b[2] in (".|:",)]
    measures = []
    start = staff.x0
    start_bar = None
    for b in edges + [(staff.x1 + 1, staff.x1 + 1, None)]:
        evs = [e for e in events if start <= e.x < b[0]]
        if b[2] is None and not evs:
            break
        if not evs and b[2] in (".|:",) and not measures:
            start_bar = ".|:"
            start = b[1]
            continue
        m = Measure()
        m.x0, m.x1 = start, b[0]
        m.events = evs
        m.start_bar = start_bar
        m.end_bar = b[2] or "|"
        start_bar = None
        start = b[1]
        measures.append(m)
    if not measures:
        return []
    measures[0].clef = clef
    measures[0].key = key
    for x, t in tsig:
        for m in measures:
            if x < m.x1 - sp:
                m.time = t
                break
    for x, t in marks:
        for m in measures:
            if x < m.x1:
                m.marks.append(t)
                break
    for x0, x1, t in voltas:
        mi = [i for i, m in enumerate(measures) if m.x1 > x0 + sp]
        if not mi:
            continue
        i0 = mi[0]
        ends = [i for i, m in enumerate(measures) if i >= i0 and m.x1 <= x1 + 2 * sp]
        i1 = ends[-1] if ends else i0
        measures[i0].volta_start = t
        measures[i1].volta_end = True
    for ev in events:
        if getattr(ev, "tie_open", False):
            state["tie_pending"] = ev
    state["clef"], state["key"] = clef, key
    if pend_tie is not None and measures and measures[0].events:
        nxt = measures[0].events[0]
        if set(h[0] for h in pend_tie.heads) & set(h[0] for h in nxt.heads):
            pend_tie.tie = True
        else:
            pend_tie.slur_start = True
            # the slur ends where the next system's half of it ends
            close = [c for c in staff.curves if c.x0 < prefix_x + 3 * sp]
            if close:
                tgt = nearest_event(measures[0].events + sum((m.events for m in measures[1:]), []),
                                    close[0].x1, 3 * sp)
                if tgt:
                    tgt.slur_end = True
    return measures


def hooked(h, vlines, sp):
    """A tuplet bracket half ends in a short vertical hook (a ledger line
    or a volta line near the number does not)."""
    for x, y0, y1, _ in vlines:
        if y1 - y0 < 2 * sp and min(abs(x - h[0]), abs(x - h[1])) < 0.4 \
                and min(abs(y0 - h[2]), abs(y1 - h[2])) < 0.6:
            return True
    return False


def beam_y(pts, x):
    xs = sorted(set(round(p.x, 2) for p in pts))
    if len(xs) < 2:
        return None
    lx, rx = xs[0], xs[-1]
    lp = [p for p in pts if abs(p.x - lx) < 0.05]
    rp = [p for p in pts if abs(p.x - rx) < 0.05]
    if not lp or not rp or rx - lx < 0.1:
        return None
    ly = sum(p.y for p in lp) / len(lp)
    ry = sum(p.y for p in rp) / len(rp)
    t = min(1, max(0, (x - lx) / (rx - lx)))
    return ly + t * (ry - ly)


def beam_group(events, x, sp):
    """Events joined by beams around x (for an unbracketed tuplet)."""
    notes = [e for e in events if getattr(e, "beams", 0) > 0]
    if not notes:
        return []
    notes.sort(key=lambda e: e.x)
    groups, cur = [], [notes[0]]
    for e in notes[1:]:
        if e.x - cur[-1].x < 5 * sp and not [r for r in events if r.kind == "rest" and cur[-1].x < r.x < e.x]:
            cur.append(e)
        else:
            groups.append(cur)
            cur = [e]
    groups.append(cur)
    for g in groups:
        if g[0].x - sp <= x <= g[-1].x + 2 * sp:
            return g
    return []


def nearest_event(events, x, maxd, after=None):
    cand = [e for e in events if after is None or e.x >= after]
    if not cand:
        return None
    e = min(cand, key=lambda e: abs(e.x - x))
    return e if abs(e.x - x) <= maxd else None


def esc(t):
    return t.replace("\\", "\\\\").replace('"', '\\"')


# ------------------------------------------------------------- pitches ---

def key_alter(key):
    nsharp, nflat = key
    alt = {}
    for i in range(nsharp):
        alt[SHARPS[i]] = 1
    for i in range(nflat):
        alt[SHARPS[6 - i]] = -1
    return alt


def spell(measures):
    """Resolve explicit accidentals, key and ties into absolute pitches."""
    key = (0, 0)
    prev = None
    for m in measures:
        if m.key is not None:
            key = m.key
        kalt = key_alter(key)
        local = {}
        for ev in m.events:
            ev.pitches = []
            for dia, acc, _, _ in sorted(ev.heads, key=lambda h: h[0]):
                step = STEPS[dia % 7]
                if acc is not None:
                    local[dia] = acc
                    a = acc
                elif dia in local:
                    a = local[dia]
                elif prev is not None and prev.tie and any(p[0] == dia for p in prev.pitches) \
                        and ev is m.events[0]:
                    a = [p[1] for p in prev.pitches if p[0] == dia][0]
                else:
                    a = kalt.get(step, 0)
                ev.pitches.append((dia, a))
            prev = ev


def ly_pitch(dia, alt):
    step = STEPS[dia % 7]
    octave = dia // 7
    name = step + {-2: "eses", -1: "es", 0: "", 1: "is", 2: "isis"}[alt]
    name = name.replace("ees", "es") if False else name
    if step in "ea" and alt < 0:
        name = step + ("s" if alt == -1 else "ses")
    marks = octave - 3
    return name + ("'" * marks if marks > 0 else "," * (-marks))


def midi(dia, alt):
    return 12 * (dia // 7 + 1) + SEMIS[dia % 7] + alt


def ly_dur(d):
    """Fraction of a whole note -> lilypond duration with dots."""
    for base in (1, 2, 4, 8, 16, 32, 64, 128):
        for dots in range(3):
            if F(1, base) * (2 - F(1, 2 ** dots)) == d:
                return str(base) + "." * dots
    if d == 2:
        return "\\breve"
    return None


# ---------------------------------------------------------------- read ---

def read(path, staff_no, warn):
    doc, systems = load(path)
    measures = []
    state = {}
    for si, sysm in enumerate(systems):
        if staff_no > len(sysm):
            warn(f"system {si + 1} has {len(sysm)} staves; no staff {staff_no}")
            continue
        st = sysm[staff_no - 1]
        ms = read_staff(st, state, lambda msg, si=si: warn(f"system {si + 1}: {msg}"))
        if ms and measures and ms[0].start_bar is None and measures[-1].end_bar in (".|:",):
            ms[0].start_bar = ".|:"
            measures[-1].end_bar = "|"
        measures += ms
    spell(measures)
    return doc, measures


def emit(measures, report, clef_override=None):
    out = []
    time = (4, 4)
    num = 1
    tuplet_open = None
    clef = key = None
    for i, m in enumerate(measures):
        line = []
        if m.clef and m.clef != clef:
            line.append(f'\\clef "{clef_override or m.clef}"')
            clef = m.clef
        if m.key is not None and m.key != key:
            key = m.key
            ns, nf = m.key
            k = MAJOR_SHARP[ns] if ns else MAJOR_FLAT[nf]
            line.append(f"\\key {k} \\major")
        if m.time:
            if i == 0 or m.time != time:
                line.append(f"\\time {m.time[0]}/{m.time[1]}")
            time = m.time
        if m.start_bar and out and out[-1] == '  \\bar ":|."' and m.start_bar == ".|:":
            out[-1] = '  \\bar ":|.|:"'
        elif m.start_bar:
            line.append(f'\\bar "{m.start_bar}"')
        if m.volta_start:
            # a volta that starts where the last one ends ends it in the same command
            close = "(volta #f) " if out and out[-1].endswith("((volta #f))") else ""
            if close:
                out.pop()
            line.append(f"\\set Score.repeatCommands = #'({close}(volta \"{esc(m.volta_start)}\"))")
        line += m.marks
        meas_len = F(time[0], time[1])
        total = F(0)
        evs = m.events
        mrest = [e for e in evs if e.kind == "mrest"]
        if mrest:
            n = mrest[0].count
            dur = f"1*{n}" if time == (4, 4) else f"{time[1]}*{time[0] * n}"
            line.append(f"R{dur}")
            out.append(f"  % m{num}" + (f"-{num + n - 1}" if n > 1 else ""))
            out.append("  " + " ".join(line) + " |")
            num += n
            if m.end_bar != "|":
                out.append(f'  \\bar "{m.end_bar}"')
            continue
        if len(evs) == 1 and evs[0].kind == "rest" and evs[0].dur == 1 and evs[0].dots == 0:
            dur = "1" if time == (4, 4) else f"1*{time[0]}/{time[1]}"
            line.append(f"R{dur}")
            total = meas_len
        else:
            for ev in evs:
                tok = []
                if ev.tuplet and (tuplet_open is None or tuplet_open != ev.tuplet[0]):
                    if tuplet_open is not None:
                        tok.append("}")
                    tok.append(f"\\tuplet {ev.tuplet[1]}/{ev.tuplet[2]} {{")
                    tuplet_open = ev.tuplet[0]
                elif not ev.tuplet and tuplet_open is not None:
                    tok.append("}")
                    tuplet_open = None
                d = ly_dur(ev.dur * (2 - F(1, 2 ** ev.dots)))
                if d is None:
                    d = "4"
                    report.append(f"m{num}: unreadable duration {ev.dur}")
                if ev.kind == "rest":
                    tok.append("r" + d)
                else:
                    ps = [ly_pitch(*p) for p in ev.pitches]
                    tok.append((ps[0] if len(ps) == 1 else "<" + " ".join(ps) + ">") + d)
                    tok[-1] += "".join(ev.artics)
                    if ev.dyn:
                        tok[-1] += "\\" + ev.dyn
                    if ev.tie:
                        tok[-1] += "~"
                    if ev.slur_end:
                        tok[-1] += ")"
                    if ev.slur_start:
                        tok[-1] += "("
                tok[-1] += "".join(ev.markups)
                line += tok
                total += ev.length()
            if tuplet_open is not None:
                line.append("}")
                tuplet_open = None
        comment = ""
        if total != meas_len:
            if i == 0 and 0 < total < meas_len:
                at = max([k + 1 for k, tok in enumerate(line) if tok.startswith("\\time")] + [0])
                line.insert(at, f"\\partial {ly_dur(total) or '4'}")
                report.append(f"m{num}: pickup of {total} (written as \\partial)")
            else:
                comment = f"  % CHECK m{num}: sums to {total}, time is {time[0]}/{time[1]}"
                report.append(f"CHECK m{num}: sums to {total}, time is {time[0]}/{time[1]}")
        out.append(f"  % m{num}{comment}")
        out.append("  " + " ".join(line) + " |")
        if m.end_bar != "|":
            out.append(f'  \\bar "{m.end_bar}"')
        if m.volta_end:
            out.append("  \\set Score.repeatCommands = #'((volta #f))")
        num += 1
    return "\n".join(out), num - 1


def song_file(args, measures, report, src):
    body, n = emit(measures, report, args.clef)
    name = args.name
    title = args.title or name.replace("_", " ").title()
    wrap_open = f"\\transpose c' {args.to_concert} " if args.to_concert else ""
    lines = [
        '\\version "2.24.1"',
        f"% {title}: read from \"{src}\" (staff {args.staff}) by",
        "% muertos/tools/pdf2ly.py; regenerate with that command, do not hand-edit",
        "% the notes.  " + (f"Written for an instrument in {args.to_concert}; "
                            f"\\transpose c' {args.to_concert} sounds it at concert pitch."
                            if args.to_concert else "Concert pitch."),
        f"% {n} measures; " + (f"{sum(1 for r in report if r.startswith('CHECK'))} CHECK"),
    ] + ([f"% Clef forced to {args.clef} (--clef): the source staff is in {measures[0].clef},",
          "% Book.ly's \\transpose f c' puts it in the mellophone's treble range."]
         if args.clef and args.clef != measures[0].clef else []) + [
        "",
        f"{name}-header = \\header {{",
        f'  piece = "{esc(title)}"',
        '  tagline = ""',
        "}",
        "",
        f"{name}-accompaniment = {wrap_open}{{",
        "  \\compressEmptyMeasures",
        body,
        "}",
        "",
    ]
    return "\n".join(lines)


def notes(path, staff, warn):
    _, measures = read(path, staff, warn)
    seq = []
    for mi, m in enumerate(measures):
        for e in m.events:
            if e.kind == "note":
                seq.append((tuple(sorted(midi(*p) for p in e.pitches)), e.length()))
            elif e.kind == "rest":
                seq.append(("r", e.length()))
            else:
                seq.append(("R", F(e.count)))
    return seq, measures


def compare(a, b, interval, warn):
    def split(s):
        m = re.match(r"^(.*?)(?::(\d+))?$", s)
        return m.group(1), int(m.group(2) or 1)
    pa, sa = split(a)
    pb, sb = split(b)
    na, _ = notes(pa, sa, warn)
    nb, _ = notes(pb, sb, warn)
    ta = [(tuple(p + interval for p in t[0]) if isinstance(t[0], tuple) else t[0], t[1]) for t in na]
    sm = difflib.SequenceMatcher(None, ta, nb, autojunk=False)
    matched = sum(bl.size for bl in sm.get_matching_blocks())
    # pitch-only agreement (rhythm ignored), notes only
    pa_only = [t[0] for t in ta if isinstance(t[0], tuple)]
    pb_only = [t[0] for t in nb if isinstance(t[0], tuple)]
    sp = difflib.SequenceMatcher(None, pa_only, pb_only, autojunk=False)
    pm = sum(bl.size for bl in sp.get_matching_blocks())
    longest = max(len(ta), len(nb)) or 1
    plong = max(len(pa_only), len(pb_only)) or 1
    print(f"events: {len(ta)} concert, {len(nb)} written; matched {matched} "
          f"= {100 * matched / longest:.1f}% (pitch+duration, in order)")
    print(f"notes: {len(pa_only)} concert, {len(pb_only)} written; pitches matched {pm} "
          f"= {100 * pm / plong:.1f}% (pitch only)")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("pdf", nargs="?")
    ap.add_argument("--staff", type=int, default=1)
    ap.add_argument("--name")
    ap.add_argument("--title")
    ap.add_argument("--clef")
    ap.add_argument("--to-concert")
    ap.add_argument("--compare", nargs=2, metavar=("CONCERT[:N]", "WRITTEN[:N]"))
    ap.add_argument("--interval", type=int, default=7)
    args = ap.parse_args()

    def warn(msg):
        print(f"pdf2ly: {msg}", file=sys.stderr)
    if args.compare:
        return compare(args.compare[0], args.compare[1], args.interval, warn)
    if not args.pdf:
        ap.error("PDF is required")
    doc, measures = read(args.pdf, args.staff, warn)
    if not measures:
        warn(f"no staff {args.staff} read from {args.pdf}")
        return 1
    if not args.name:
        args.name = re.sub(r"[^a-z]+", "_", (doc.metadata.get("title") or "song").lower()).strip("_")
    if not args.title:
        args.title = doc.metadata.get("title") or None
    report = []
    src = args.pdf.rsplit("/", 1)[-1]
    sys.stdout.write(song_file(args, measures, report, src))
    for r in report:
        print(f"pdf2ly: {r}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
