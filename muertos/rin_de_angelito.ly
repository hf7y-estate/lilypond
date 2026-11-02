\version "2.24.1"
% Rin de Angelito: read from "Rin de Angelito Concert.pdf" (staff 3) by
% muertos/tools/pdf2ly.py; regenerate with that command, do not hand-edit
% the notes.  Concert pitch.
% 16 measures; 0 CHECK
% Clef forced to treble (--clef): the source staff is in bass,
% Book.ly's \transpose f c' puts it in the mellophone's treble range.

rin_de_angelito-header = \header {
  piece = "Rin de Angelito"
  tagline = ""
}

rin_de_angelito-accompaniment = {
  \compressEmptyMeasures
  % m1
  \clef "treble" \key bes \major \time 4/4 R1 |
  % m2
  R1 |
  % m3
  R1 |
  % m4
  R1 |
  \bar ".|:"
  % m5
  <d bes>1 |
  % m6
  <fis c'>1 |
  % m7
  <fis c'>1 |
  % m8
  <g bes>1 |
  \bar ":|.|:"
  % m9
  <f d'>1 |
  % m10
  <f d'>1 |
  % m11
  <g es'>1 |
  % m12
  <f d'>1 |
  % m13
  <f d'>1 |
  % m14
  <f d'>1 |
  % m15
  <g es'>1 |
  % m16
  <g d'>1 |
  \bar "|."
}
