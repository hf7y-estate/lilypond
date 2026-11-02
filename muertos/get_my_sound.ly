\version "2.24.1"
% Get My Sound: read from "Get_My_Sound.pdf" (staff 2) by
% muertos/tools/pdf2ly.py; regenerate with that command, do not hand-edit
% the notes.  Concert pitch.
% 12 measures; 0 CHECK
% Clef forced to treble (--clef): the source staff is in bass,
% Book.ly's \transpose f c' puts it in the mellophone's treble range.

get_my_sound-header = \header {
  piece = "Get My Sound"
  tagline = ""
}

get_my_sound-accompaniment = {
  \compressEmptyMeasures
  % m1
  \clef "treble" \key f \major \time 4/4 \bar ".|:" r4 <f a>4 r4 <a c'>4 |
  % m2
  r8 <g e'>8 r8 <f d'>8~ <f d'>2 |
  % m3
  r4 <f a>4 r4 <a c'>4 |
  % m4
  r8 <g e'>8 r8 <f d'>8~ <f d'>2 |
  % m5
  r4 <f a>4 r4 <a c'>4 |
  % m6
  r8 <g e'>8 r8 <f d'>8~ <f d'>2 |
  % m7
  r4 <f a>4 r4 <a c'>4 |
  % m8
  r8 <g e'>8 r8 <f d'>8~ <f d'>2 |
  \bar ":|."
  % m9
  r4 <f a>4 r4 <a c'>4 |
  % m10
  r8 <g e'>8 r8 <f d'>8~ <f d'>2 |
  % m11
  r4 <f a>4 r4 <a c'>4 |
  % m12
  r8 <g e'>8 r8 <f d'>8~ <f d'>2 |
  \bar "|."
}
