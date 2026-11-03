\version "2.24.1"
% Le Chant des Partisans: read from "Le Chant des Partisans-Alto_Saxophone.pdf" (staff 1) by
% muertos/tools/pdf2ly.py; regenerate with that command, do not hand-edit
% the notes, except m30-m34 (below).  Written for an instrument in ees; \transpose c' ees sounds it at concert pitch.
% 34 measures; 0 CHECK

le_chant_des_partisans-header = \header {
  piece = "Le Chant des Partisans"
  tagline = ""
}

le_chant_des_partisans-accompaniment = \transpose c' ees {
  \compressEmptyMeasures
  % m1
  \clef "treble" \key g \major \time 4/4 \mark \markup \box "Build-up" r2 r4 d'4^\markup "Enter on call" |
  \bar ".|:"
  % m2
  g'4 g'8 a'8 b'4 b'8 a'8 |
  % m3
  g'4 g'8 fis'8 e'4 d'8. fis'16 |
  % m4
  e'4 d'2 r4 |
  % m5
  \set Score.repeatCommands = #'((volta "1.")) r2 r4 d'4 |
  \bar ":|."
  % m6
  \set Score.repeatCommands = #'((volta #f) (volta "2.")) r2. fis'4 |
  \set Score.repeatCommands = #'((volta #f))
  % m7
  b'4 b'8 c''8 d''4 d''8 c''8 |
  % m8
  b'4 b'8 a'8 g'4 d'8. fis'16 |
  % m9
  e'4 d'2 r4 |
  % m10
  r2. g'4 |
  % m11
  b'4 b'8 c''8 d''4 d''8 c''8 |
  % m12
  b'4 b'8 a'8 g'4 d'8. fis'16 |
  % m13
  e'4 d'2 r4 |
  % m14
  r2 r4 d'4 |
  \bar "||"
  % m15
  \mark \markup \box "Verse" g'4 g'8 a'8 b'4 b'8 a'8 |
  % m16
  g'4 g'8 fis'8 e'4 d'8. fis'16 |
  % m17
  e'4 d'2 r4 |
  % m18
  r2. d'4 |
  % m19
  g'4 g'8 a'8 b'4 b'8 a'8 |
  % m20
  g'4 g'8 fis'8 e'4 d'8. fis'16 |
  % m21
  e'4 d'2 r4 |
  % m22
  r2. fis'4 |
  % m23
  b'4 b'8 c''8 d''4 d''8 c''8 |
  % m24
  b'4 b'8 a'8 g'4 d'8. fis'16 |
  % m25
  e'4 d'2 r4 |
  % m26
  r2. g'4 |
  % m27
  b'4 b'8 c''8 d''4 d''8 c''8 |
  % m28
  b'4 b'8 a'8 g'4 d'8. fis'16 |
  % m29
  e'4 d'2 r4 |
  % m30-m34, hand-edited (#25 item 7, Zach 2026-11-02: "the rhythm at the
  % end should be rewritten for clarity (16th note instead of 8th note?)").
  % The source (Le Chant des Partisans-Alto_Saxophone.pdf, m30-34) writes
  % the B a 16th before beat 4 (m30, 32, 34) and before beat 2 (m31, 33) as
  % an 8th that runs over the beat, then a 16th rest: r8 r16 b'8 r16 b'8,
  % g'8. b'8 r16 b'8. Here that B is a 16th and the rest after it an 8th:
  % every note starts where the source's does, and each beat starts on a
  % rest or note of its own.
  % m30
  r2 r8. b'16 r8 b'8 |
  % m31
  \bar ".|:" \mark \markup \box "Chorus" g'8.^\markup "Call / Response" b'16 r8 b'8 g'8. r16 r4 |
  % m32
  r2 r8. b'16 r8 b'8 |
  % m33
  g'8. b'16 r8 b'8 g'8. r16 r4 |
  % m34
  r2 r8. b'16 r8 b'8 |
  \bar ":|."
}
