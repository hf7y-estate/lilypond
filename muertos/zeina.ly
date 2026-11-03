\version "2.24.1"
% Zeina: the accompaniment part of archive/brass-charts/Palestine/Zeina.ly
% (musicxml2ly output), shaped like the other songs in this book.
% Rehearsal marks, tempi and D.S. are read off that file's Zeina-Melody.
% The source part is in treble_8 (lowest note A2, below the mellophone);
% it is written here in treble one octave up, so Book.ly's
% \transpose f c' puts it in the same written range as the other parts.

zeina-header = \header {
    piece = "Zeina"
    tagline = ""
}

zeina-music = \relative d {
    \clef "treble" \numericTimeSignature\time 4/4 \key bes \major
    \repeat volta 4 {
        | % 1
        \tempo 4=180 \mark \markup { \box { Intro } }
        d4 -. es4 -. c4 -. es4 -. | % 2
        r8 d8 -. r8 c8 -. r8 bes8 -. r8
        a8 -. | % 3
        d4 -. es4 -. c4 -. es4 -. | % 4
        d4 -. r4 r2 | % 5
        }
    \repeat volta 2 {
        | % 9
        \mark \markup { \musicglyph "scripts.segno" \box { A } }
        d4 -. d4 -. d8 -. [ d8 -. ]
        d4 -. | \barNumberCheck #10
        d4 -. d8 -. [ d8 -. ] d4 -.
        d8 -. [ d8 -. ] | % 11
        d4 -. d4 -. d8 -. [ d8 -. ]
        d4 -. | % 12
        d4 -. d8 -. [ d8 -. ] d4 (
        c4 ) }
    | % 13
    \mark \markup { \box { B } }
    es4 fis4 g2 | % 14
    \grace { fis32 } g4. fis8 es2 | % 15
    r4 g4 g2 | % 16
    \grace { fis32 } g4. fis8 es8 [
    fis8 ] es4 | % 17
    R1 | % 18
    \repeat volta 2 {
    r4 fis8 [ g8 ] a4 a8 [ g8 ]
    | fis4 r4 r2 |
    r4 es8 [ fis8 ] g8 [ a8 bes8
    c8 ] }
    \alternative { { d4 r4 r2 | } { \once \omit Staff.BarLine s1*0 } }
    \mark \markup { \box { C } }
    d4 c4 b4 g8 [ c8 ~ ] | % 26
    c8 [ bes8 ] a4 fis4 d4 | % 27
    a'4 g4 fis4 d8 [ g8 ~ ] | % 28
    g8 [ f8 ] es4 d4 a4 | % 29
    es'2 ges2 | \barNumberCheck #30
    g2 a2 | % 31
    c,4 es2 c4 | % 32
    d4 d'16 ( [ ^ "Only when repeating" es16
    d16 c16 ] d4 c4 ) \textEndMark "D.S." \bar "|."
    \repeat volta 2 {
        \mark \markup { \box { D } } \tempo 4=220
        d,4 r4 fis4 es4 | d4 r4 g4 fis4 | es4 r4 a4 g4 | fis4 es4 d4 c4 | d4 r4 fis4 es4 | }
    \alternative {
      { d4 r4 g4 fis4 | es4 r4 bes'4 g4 | a4 r4 r2 | }
      { d,4 r4 fis4 g4 | a4 fis4 es4 fis4 | d4 r4 r2 \bar "|." }
    }
    \repeat volta 2 {
        \mark \markup { \box { E } }
        r4. d8 -. r4 d8 -. r8 | r4. c8 -. r4 c8 -. r8 | r4. c8 -. r4 c8 -. r8 |
        r4. bes8 -. r4 bes8 -. r8 | r4. bes8 -. r4 bes8 -. r8 | r4. a8 -. r4 a8 -. r8 | }
    \alternative {
      { r4. a8 -. r4 a8 -. r8 | r4. g8 -. r4 g8 -. r8 | }
      { a'4 g4 fis4 es4 | d4 es8 [ fis8 ] es8 [ d8 ] c4 \textEndMark "D.S." \bar "|." }
    }
}

zeina-accompaniment = {
    \new Staff {
        \transpose c c' \zeina-music
    }
}
