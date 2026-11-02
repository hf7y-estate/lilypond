\version "2.24.1"
% Ana Dammi Falastini: read from "Anna Dammi Falastini v3-Accompaniment_(F).pdf" (staff 1) by
% muertos/tools/pdf2ly.py; regenerate with that command, do not hand-edit
% the notes.  Written for an instrument in f; \transpose c' f sounds it at concert pitch.
% 40 measures; 0 CHECK

ana_dammi_falastini-header = \header {
  piece = "Ana Dammi Falastini"
  tagline = ""
}

ana_dammi_falastini-accompaniment = \transpose c' f {
  \compressEmptyMeasures
  % m1
  \clef "treble" \key des \major \time 4/4 \bar ".|:" \mark \markup \box "Intro" \tempo 4 = 200 f'1~^\markup "Repeat 3x" |
  % m2
  f'1 |
  \bar ":|."
  % m3
  r4 f'8 f'8 ges'8 ges'8 as'8 as'8 |
  % m4
  bes'8 bes'8 c''8 c''8 des''8 des''8 es''8 es''8 |
  \bar "||"
  % m5
  \mark \markup { \box "A" \musicglyph "scripts.segno" } f''4 r4 r2 |
  % m6
  r2. es'4 |
  % m7
  as'4 r4 r2 |
  % m8
  r2 f'4 es'4 |
  % m9
  f'4 r4 r2 |
  % m10
  R1 |
  % m11
  as'4 r4 r2 |
  % m12
  R1 |
  % m13
  f'4 r4 r2 |
  % m14
  f'4 r4 f'4 f'4 |
  % m15
  as'4 r4 r2 |
  % m16
  es'8 f'8 ges'8 as'8 bes'8 c''8 des''8 es''8 |
  \bar "||"
  % m17
  \mark \markup { \box "B" \musicglyph "scripts.segno" } r4 f'8 bes'8 as'4 as'8 ges'8 |
  % m18
  f'4 ges'4 as'4 r4 |
  % m19
  r4 f'8 bes'8 as'4 as'8 ges'8 |
  % m20
  f'4 ges'4 f'4 r4 |
  % m21
  r4 f'8 bes'8 as'4 as'8 ges'8 |
  % m22
  f'4 ges'4 as'8 bes'16 c''16 bes'4 |
  % m23
  r4 c''8 c''8 c''4 c''8 bes'8 |
  % m24
  as'4 c''4 bes'4 r8 bes'8 |
  % m25
  as'4 c''4 bes'4 r8 bes'8 |
  % m26
  as'4 c''4 bes'2 |
  % m27
  r4 as'8 as'8 as'4 as'8 as'8 |
  % m28
  \mark \markup \box "C" as'4 bes'4 as'8 ges'8 f'8 es'8 |
  \bar ".|:"
  % m29
  f'1~ |
  % m30
  f'2. es'4 |
  % m31
  f'1~ |
  % m32
  f'2. es'4 |
  \bar ":|.|:"
  % m33
  \mark \markup \box "D" r4. f'8-. r4 f'8-. r8 |
  % m34
  r4. f'8-. r4 f'8-. r8 |
  \bar ":|."
  % m35
  r4. f'8-. r4 f'8-. r8 |
  % m36
  r4. f'8-. r4 f'8-. r8 |
  % m37
  bes'4 r4 bes'4 r4 |
  % m38
  bes'4^\markup "BACK TO A" bes'4 as'8 ges'8 f'8 es'8^\markup "D.S." |
  \bar ".|"
  % m39
  r4 as'8 as'8^\markup "ENDING ON CUE" as'4 as'8 ges'8 |
  % m40
  f'4 es'4 f'4 r4 |
  \bar "|."
}
