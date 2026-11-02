#!/usr/bin/env python3
"""barsum.py FILE.ly... -- every measure of a song's accompaniment adds
up to its time signature, counted from the notes, not from any comment.

Issue #4: "Every measure must sum to its time signature."  pdf2ly.py marks
a measure that does not with a "% CHECK" comment, but that comment is the
reader's own word and anyone editing the file can drop it.  This counts the
durations itself, stdlib only (it runs where PyMuPDF and LilyPond do not),
and shares no code with pdf2ly.py.

It reads the `<song>-accompaniment = ... { ... }` block: notes, rests and
chords with LilyPond's duration memory, dots, `\\tuplet n/m { }`, `R1*N`
multi-measure rests, `\\time`, `\\partial`, and the `|` bar check that ends
each measure.  Everything else it knows by name (`\\clef`, `\\key`, `\\mark`,
`\\markup`, `\\tempo`, `\\set ... = #'(...)`, `\\bar`, dynamics, ties,
slurs, articulations).

Exit 0: every measure adds up.  1: at least one does not (each listed as
`FILE: m<N>: sums to X, time is n/d`).  2: BLIND -- a file is missing, has
no accompaniment block, or holds a token this does not know; it is never
counted as a pass.
"""
import re
import sys
from fractions import Fraction as F

PITCH = r"[a-g](?:isis|eses|is|es|s)?[',]*[!?]?"
EVENT = re.compile(
    r"^(?P<head>" + PITCH + r"|<(?:\s*" + PITCH + r")+\s*>|r|R|s)"
    r"(?P<dur>\\breve|128|64|32|16|8|4|2|1)?(?P<dots>\.*)"
    r"(?P<mul>\*\d+(?:/\d+)?)?(?P<post>.*)$")
# What may follow a note or rest: ties, slurs, articulations, dynamics,
# and a markup attached with ^ _ or - (its argument is the next token).
POST = re.compile(r"~|\(|\)|\[|\]|-[.>^_!+-]|[-^_]\\markup$|\\(?:ppp|pp|p|mp|mf|f|ff|fff|sfz|sf|fp|<|>|!)")
DYN = re.compile(r"^\\(?:ppp|pp|p|mp|mf|f|ff|fff|sfz|sf|fp|<|>|!)$")


class Blind(Exception):
    pass


def tokens(text, line0):
    """(token, line) pairs; strings and #'(...) scheme stay one token,
    a <chord> stays joined to its duration, % comments are dropped."""
    i, n, line = 0, len(text), line0
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
        elif c.isspace():
            i += 1
        elif c == "%":
            while i < n and text[i] != "\n":
                i += 1
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            if j >= n:
                raise Blind(f"line {line}: unterminated string")
            yield text[i:j + 1], line
            i = j + 1
        elif c == "#":
            j, depth = i + 1, 0
            while j < n and text[j] in "'`":
                j += 1
            if j < n and text[j] == "(":
                while j < n:
                    if text[j] == "(":
                        depth += 1
                    elif text[j] == ")":
                        depth -= 1
                        if depth == 0:
                            break
                    elif text[j] == '"':
                        j += 1
                        while j < n and text[j] != '"':
                            j += 1
                    j += 1
                if depth:
                    raise Blind(f"line {line}: unbalanced scheme")
                j += 1
            else:
                while j < n and not text[j].isspace():
                    j += 1
            yield "#SCHEME", line
            line += text[i:j].count("\n")
            i = j
        else:
            j = i
            if c == "<":
                j = text.find(">", i)
                if j < 0:
                    raise Blind(f"line {line}: unterminated chord")
            while j < n and not text[j].isspace():
                j += 1
            yield text[i:j], line
            i = j


def body(path):
    with open(path, encoding="utf-8") as fh:
        src = fh.read()
    m = re.search(r"^[\w-]+-accompaniment\s*=\s*(?:\\transpose\s+\S+\s+\S+\s*)?\{",
                  src, re.M)
    if not m:
        raise Blind("no <song>-accompaniment = { block")
    start = m.end()
    end = re.search(r"^\}", src[start:], re.M)
    if not end:
        raise Blind("accompaniment block never closes")
    return src[start:start + end.start()], src[:start].count("\n") + 1


def dur_of(digits, dots):
    base = F(2) if digits == "\\breve" else F(1, int(digits))
    return base * (2 - F(1, 2 ** len(dots)))


def check(path):
    """List of failures for one file; raises Blind when it cannot read it."""
    text, line0 = body(path)
    toks = list(tokens(text, line0))
    bad = []
    time, sig = F(4, 4), "4/4"
    partial = None
    last = F(1, 4)
    total = F(0)
    lone_r = None          # the measure so far is one R: its multiplier
    events = 0
    tup = []               # stack of tuplet factors
    braces = 0             # plain { } groups inside the block
    num = 1
    i = 0

    def arg(k):
        if k >= len(toks):
            raise Blind(f"line {toks[-1][1]}: {toks[-1][0]} has no argument")
        return toks[k][0]

    def markup(k):
        """Skip one \\markup argument starting at toks[k]; return next k."""
        while arg(k).startswith("\\") and arg(k) not in ("\\markup",):
            k += 1                       # \box \bold \italic ... wrap the next
        if arg(k) == "{":
            depth = 0
            while True:
                t = arg(k)
                depth += (t == "{") - (t == "}")
                k += 1
                if depth == 0:
                    return k
        return k + 1                     # a string or a word

    while i < len(toks):
        t, ln = toks[i]
        if t == "|":
            want = partial if (num == 1 and partial is not None) else time
            ok = total == want or (lone_r is not None and events == 1
                                   and total > 0 and (total / time).denominator == 1)
            if not ok:
                bad.append(f"{path}: m{num} (line {ln}): sums to {total}, time is {sig}"
                           + (f" (\\partial {partial})" if num == 1 and partial is not None else ""))
            num += int(total / time) if (ok and lone_r is not None) else 1
            total, lone_r, events = F(0), None, 0
            i += 1
        elif t in ("\\clef", "\\bar", "\\key"):
            i += 3 if t == "\\key" else 2
        elif t in ("\\major", "\\minor", "\\compressEmptyMeasures", "\\break",
                   "\\noBreak", "\\pageBreak", "\\default"):
            i += 1
        elif t == "\\time":
            m = re.fullmatch(r"(\d+)/(\d+)", arg(i + 1))
            if not m:
                raise Blind(f"line {ln}: \\time {arg(i + 1)}")
            time, sig = F(int(m[1]), int(m[2])), m[0]
            i += 2
        elif t == "\\partial":
            m = re.fullmatch(r"(\\breve|128|64|32|16|8|4|2|1)(\.*)", arg(i + 1))
            if not m or num != 1:
                raise Blind(f"line {ln}: \\partial {arg(i + 1)} (only in m1)")
            partial = dur_of(m[1], m[2])
            i += 2
        elif t == "\\tempo":
            i += 1
            if arg(i).startswith('"') or arg(i) == "\\markup":
                i = markup(i + 1) if arg(i) == "\\markup" else i + 1
            if i + 2 < len(toks) and re.fullmatch(r"\d+\.*", toks[i][0]) and toks[i + 1][0] == "=":
                i += 3
        elif t == "\\mark":
            i = markup(i + 2) if arg(i + 1) == "\\markup" else i + 2
        elif t == "\\markup":
            i = markup(i + 1)
        elif t == "\\set":
            if arg(i + 2) != "=":
                raise Blind(f"line {ln}: \\set {arg(i + 1)} without =")
            i += 4
        elif t == "\\tuplet":
            m = re.fullmatch(r"(\d+)/(\d+)", arg(i + 1))
            if not m or arg(i + 2) != "{":
                raise Blind(f"line {ln}: \\tuplet {arg(i + 1)} {arg(i + 2)}")
            tup.append(F(int(m[2]), int(m[1])))
            i += 3
        elif t == "{":
            braces += 1
            i += 1
        elif t == "}":
            if tup:
                tup.pop()
            elif braces:
                braces -= 1
            else:
                raise Blind(f"line {ln}: unmatched }}")
            i += 1
        elif DYN.match(t):
            i += 1
        elif re.fullmatch(r"[-^_]\\markup", t):   # a second markup on the same note
            i = markup(i + 1)
        else:
            m = EVENT.match(t)
            if not m:
                raise Blind(f"line {ln}: unknown token {t!r}")
            post = m["post"]
            rest = POST.sub("", post)
            if rest:
                raise Blind(f"line {ln}: unknown token {t!r} (after the note: {rest!r})")
            if m["dur"]:
                last = dur_of(m["dur"], m["dots"])
                d = last
            elif m["dots"]:
                raise Blind(f"line {ln}: dots with no duration in {t!r}")
            else:
                d = last
            if m["mul"]:
                a, _, b = m["mul"][1:].partition("/")
                d = d * F(int(a), int(b or 1))
            for f in tup:
                d *= f
            total += d
            events += 1
            if m["head"] == "R":
                lone_r = m["mul"] or "*1"
            i += 1
            if post.endswith("\\markup"):
                i = markup(i)
    if tup or braces:
        raise Blind("a { or \\tuplet { never closes")
    if total or events:
        bad.append(f"{path}: m{num}: {total} after the last bar check (no closing |)")
    return bad, num - 1


def main(argv):
    if not argv:
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        return 2
    rc = 0
    for path in argv:
        try:
            bad, n = check(path)
        except (OSError, UnicodeDecodeError, Blind) as e:
            print(f"BLIND: {path}: {e}")
            rc = 2
            continue
        for b in bad:
            print(b)
        if bad:
            rc = max(rc, 1)
        else:
            print(f"ok: {path}: {n} measures add up")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
