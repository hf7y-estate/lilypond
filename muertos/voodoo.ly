\version "2.24.1"
% Voodoo: read from "Voodoo mids F horn.pdf" (staff 1) by
% muertos/tools/pdf2ly.py; regenerate with that command, do not hand-edit
% the notes.  Written for an instrument in f; \transpose c' f sounds it at concert pitch.
% 38 measures; 0 CHECK

voodoo-header = \header {
  piece = "Voodoo"
  tagline = ""
}

voodoo-accompaniment = \transpose c' f {
  \compressEmptyMeasures
  % m1
  \clef "treble" \key f \major \time 4/4 \bar ".|:" \tempo 4 = 190 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 r2 |
  % m2
  <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 r2 |
  % m3
  <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 r2 |
  % m4
  <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 r2 |
  % m5
  <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 r2 |
  % m6
  <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 r2 |
  % m7
  <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 r2 |
  % m8
  <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 r2 |
  % m9
  <d' g' bes'>8 <d' g' bes'>8 <d' g' bes'>8 <d' g' bes'>8 r2 |
  % m10
  <d' g' bes'>8 <d' g' bes'>8 <d' g' bes'>8 <d' g' bes'>8 r2 |
  % m11
  <d' g' bes'>8 <d' g' bes'>8 <d' g' bes'>8 <d' g' bes'>8 r2 |
  % m12
  <d' g' bes'>8 <d' g' bes'>8 <d' g' bes'>8 <d' g' bes'>8 r2 |
  % m13
  <cis' g' bes'>8 <cis' g' bes'>8 <cis' g' bes'>8 <cis' g' bes'>8 r2 |
  % m14
  <cis' g' bes'>8 <cis' g' bes'>8 <cis' g' bes'>8 <cis' g' bes'>8 r2 |
  % m15
  <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 r2 |
  % m16
  <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 r2 |
  \bar ":|.|:"
  % m17
  <d' f' a'>8^\markup "INTERLUDE"^\markup "VAMP" <d' f' a'>8 <d' f' a'>8 r8 r8 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 |
  % m18
  <cis' e' g'>8 <e' g' bes'>8 r4 <a cis' e'>4 <cis' e' g'>4 |
  % m19
  <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 r8 r8 <d' f' a'>8 <d' f' a'>8 <d' f' a'>8 |
  % m20
  <cis' e' g'>8 <e' g' bes'>8 r4 <a cis' e'>4 <cis' e' g'>4 |
  \bar ":|."
  % m21
  r4. a'8\mf^\markup "MAIN MELODY" r8 a'8 a'4 |
  \bar ".|:"
  % m22
  d''8 a'8~ a'2 g'8 f'8 |
  % m23
  d'4 r8 a'8 r8 a'8 r8 g'8 |
  % m24
  a'1 |
  % m25
  r4. a'8 r8 a'8 a'4 |
  % m26
  d''8 a'8~ a'2 g'8 f'8 |
  % m27
  d'4 r8 a'8 r8 a'8 r8 g'8 |
  % m28
  a'1 |
  % m29
  r4. d'8 r8 f'8 a'4 |
  % m30
  bes'2~ \tuplet 3/2 { bes'4 a'4 g'4 } |
  % m31
  e'4 r8 cis'8 r8 cis'8 e'4 |
  % m32
  g'8 e'8~ e'2. |
  % m33
  r4. a'8 r8 a'8 a'4 |
  % m34
  bes'2~ \tuplet 3/2 { bes'4 a'4 g'4 } |
  % m35
  e'4 r8 a8 r8 cis'8 e'4 |
  % m36
  f'8 d'8~ d'2. |
  % m37
  \set Score.repeatCommands = #'((volta "1.")) r4. a'8 r8 a'8 a'4 |
  \bar ":|."
  % m38
  \set Score.repeatCommands = #'((volta #f) (volta "2.")) R1 |
  \bar "|."
  \set Score.repeatCommands = #'((volta #f))
}
