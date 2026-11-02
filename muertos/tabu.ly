\version "2.24.1"
% Tabu: read from "Tabu French Horn (F).pdf" (staff 1) by
% muertos/tools/pdf2ly.py; regenerate with that command, do not hand-edit
% the notes.  Written for an instrument in f; \transpose c' f sounds it at concert pitch.
% 40 measures; 0 CHECK

tabu-header = \header {
  piece = "Tabu"
  tagline = ""
}

tabu-accompaniment = \transpose c' f {
  \compressEmptyMeasures
  % m1
  \clef "treble" \key ees \major \time 4/4 \tempo 4 = 180 \mark \markup \box "A" c'2 g'2^\markup "(Single Melody)" |
  % m2
  f'2. g'4 |
  % m3
  c'1 |
  % m4
  R1 |
  % m5
  c'2 g'2 |
  % m6
  f'2. g'4 |
  % m7
  c'1 |
  % m8
  R1 |
  % m9
  c''4 bes'2 g'4 |
  % m10
  c''4 bes'4 g'4 r4 |
  % m11
  f'4 es'2 c'4 |
  % m12
  f'4 es'4 c'4. bes8 |
  % m13
  c'8 c'8 c'4 r2 |
  % m14
  r2 r4. bes8 |
  % m15
  c'8 c'8 c'4 r2 |
  % m16
  R1 |
  \bar "||"
  % m17
  \mark \markup \box "A" <g c' es'>2 <es' g' c''>2^\markup "(Harmonized)" |
  % m18
  <d' f' as'>2. <es' g' c''>4 |
  % m19
  <g c' es'>1 |
  % m20
  R1 |
  % m21
  <g c' es'>2 <es' g' c''>2 |
  % m22
  <d' f' as'>2. <es' g' c''>4 |
  % m23
  <g c' es'>1 |
  % m24
  R1 |
  % m25
  c''4 bes'2 g'4 |
  % m26
  c''4 bes'4 g'4 r4 |
  % m27
  f'4 es'2 c'4 |
  % m28
  f'4 es'4 c'4. bes8 |
  % m29
  c'8 c'8 c'4 r2 |
  % m30
  r2 r4. bes8 |
  % m31
  c'8 c'8 c'4 r2 |
  % m32
  R1 |
  % m33
  \bar ".|:" \mark \markup \box "B" R1 |
  % m34
  R1 |
  % m35
  r4 <d' fis' b'>8 <es' g' c''>8 r8 <d' fis' b'>8 <es' g' c''>8 r8 |
  % m36
  <d' fis' b'>8 <es' g' c''>8 r8 <d' fis' b'>8 <es' g' c''>8 r4.^\markup "Repeat 4x" |
  \bar ":|.|:"
  % m37
  \mark \markup \box "Solos" r4 <c' es' g'>2.^\markup "Vamp" |
  % m38
  r4 <d' f' as'>2. |
  % m39
  r4 <c' es' g'>2. |
  % m40
  r4 <b d' f'>8 <b d' f'>8 r8 <b d' f'>8 <b d' f'>8 r8 |
  \bar ":|."
}
