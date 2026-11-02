#!/usr/bin/env python3
"""tests/pdf2ly-fixture.py OUT.pdf [--no-beam] [--no-sharp] [--no-dot]

Writes a two-measure, one-staff PDF drawn the way MuseScore draws one, for
tests/pdf2ly.sh.  The source PDFs are other people's arrangements and stay
out of the repo, so the test reads this instead.  Glyphs are text in a
Type3 font whose ToUnicode map gives SMuFL codepoints, as MuseScore's
Leland/MScore text does; staff lines, stems and barlines are stroked
lines; the beam is a filled four-sided path.  No dependencies.

The music, treble clef, one flat, 4/4:
  m1  g'4 bes'2.        (the B flat comes from the key)
  m2  c''8 d''8 r4 fis'2   (beamed eighths; the sharp is an accidental)
  final barline
Each --no-X flag leaves that one thing out, to inject a failure.
"""
import sys

args = sys.argv[1:]
out = args[0]
NO = {a[5:] for a in args[1:] if a.startswith("--no-")}

H = 792.0                      # page height; content is written y-down
TOP, SP = 100.0, 5.0           # staff top line, staff space
GLYPHS = [0xE050, 0xE260, 0xE084, 0xE0A4, 0xE0A3, 0xE1E7, 0xE4E5, 0xE262]
CODE = {cp: i + 1 for i, cp in enumerate(GLYPHS)}
HEAD_W = 295                   # notehead width, 1/1000 em at 20pt = 5.9pt

ops = []


def y(v):
    return H - v


def line(x0, y0, x1, y1, w):
    ops.append(f"{w} w {x0:.2f} {y(y0):.2f} m {x1:.2f} {y(y1):.2f} l S")


def glyph(cp, x, yy):
    ops.append(f"BT /F1 20 Tf 1 0 0 1 {x:.2f} {y(yy):.2f} Tm <{CODE[cp]:02X}> Tj ET")


def pos(dia):                  # treble: top line is F5 = diatonic 38
    return TOP + (38 - dia) * SP / 2


def note(cp, x, dia, stem=True, stem_top=None):
    yy = pos(dia)
    glyph(cp, x, yy)
    sx = x + HEAD_W / 1000 * 20
    if stem:
        line(sx, yy, sx, stem_top if stem_top is not None else yy - 3.5 * SP, 0.5)
    return sx


for k in range(5):
    line(30, TOP + k * SP, 330, TOP + k * SP, 0.5)
glyph(0xE050, 33, TOP + 3 * SP)                 # G clef on the G line
glyph(0xE260, 52, TOP + 2 * SP)                 # key: B flat
glyph(0xE084, 62, TOP + SP)                     # 4
glyph(0xE084, 62, TOP + 3 * SP)                 # 4
# m1
note(0xE0A4, 85, 32)                            # G4 quarter
note(0xE0A3, 120, 34)                           # B4 half (flat by key)
if "dot" not in NO:
    glyph(0xE1E7, 128, pos(34) - SP / 2)        # dot, in the space above
line(180, TOP, 180, TOP + 4 * SP, 0.8)
# m2
s1 = note(0xE0A4, 190, 35, stem_top=90)         # C5 eighth
s2 = note(0xE0A4, 205, 36, stem_top=90)         # D5 eighth
if "beam" not in NO:
    ops.append(f"{s1:.2f} {y(90):.2f} m {s2:.2f} {y(90):.2f} l {s2:.2f} {y(92.5):.2f} l "
               f"{s1:.2f} {y(92.5):.2f} l {s1:.2f} {y(90):.2f} l f")
glyph(0xE4E5, 225, TOP + 2 * SP)                # quarter rest
if "sharp" not in NO:
    glyph(0xE262, 253, pos(31))                 # sharp on F4
note(0xE0A3, 260, 31)                           # F4 half
line(297, TOP, 297, TOP + 4 * SP, 0.8)          # final barline: thin
line(300, TOP, 300, TOP + 4 * SP, 2.5)          #   + thick

content = "\n".join(ops).encode()
n = len(GLYPHS)
procs = {i + 1: f"{HEAD_W} 0 0 -60 {HEAD_W} 60 d1 0 -60 {HEAD_W} 120 re f".encode() for i in range(n)}
cmap = ("/CIDInit /ProcSet findresource begin 12 dict begin begincmap\n"
        "/CMapName /SMuFL def 1 begincodespacerange <00> <FF> endcodespacerange\n"
        f"{n} beginbfchar\n" +
        "".join(f"<{CODE[cp]:02X}> <{cp:04X}>\n" for cp in GLYPHS) +
        "endbfchar endcmap CMapName currentdict /CMap defineresource pop end end\n").encode()

objs = []                      # (number, bytes)


def obj(body):
    objs.append(body)
    return len(objs)


def stream(data, extra=b""):
    return b"<< /Length %d %s>>\nstream\n" % (len(data), extra) + data + b"\nendstream"


proc_ids = {i: obj(stream(p)) for i, p in procs.items()}
tounicode = obj(stream(cmap))
charprocs = " ".join(f"/g{i} {proc_ids[i]} 0 R" for i in proc_ids)
diffs = " ".join(f"/g{i}" for i in proc_ids)
font = obj((f"<< /Type /Font /Subtype /Type3 /FontBBox [0 -500 1000 500] "
            f"/FontMatrix [0.001 0 0 0.001 0 0] /CharProcs << {charprocs} >> "
            f"/Encoding << /Type /Encoding /Differences [1 {diffs}] >> "
            f"/FirstChar 1 /LastChar {n} /Widths [{' '.join([str(HEAD_W)] * n)}] "
            f"/ToUnicode {tounicode} 0 R >>").encode())
contents = obj(stream(content))
pages_id = len(objs) + 2
page = obj((f"<< /Type /Page /Parent {pages_id} 0 R /MediaBox [0 0 612 {int(H)}] "
            f"/Resources << /Font << /F1 {font} 0 R >> >> /Contents {contents} 0 R >>").encode())
pages = obj(f"<< /Type /Pages /Kids [{page} 0 R] /Count 1 >>".encode())
assert pages == pages_id
catalog = obj(f"<< /Type /Catalog /Pages {pages} 0 R >>".encode())
info = obj(b"<< /Title (Fixture) /Creator (MuseScore) >>")

buf = bytearray(b"%PDF-1.4\n")
offs = []
for i, body in enumerate(objs, 1):
    offs.append(len(buf))
    buf += b"%d 0 obj\n" % i + body + b"\nendobj\n"
xref = len(buf)
buf += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
for o in offs:
    buf += b"%010d 00000 n \n" % o
buf += (b"trailer\n<< /Size %d /Root %d 0 R /Info %d 0 R >>\nstartxref\n%d\n%%%%EOF\n"
        % (len(objs) + 1, catalog, info, xref))
with open(out, "wb") as f:
    f.write(buf)
