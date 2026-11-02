\version "2.24.1"

% muertos/mellophone-test.ly -- the per-system fingering rule, visible.
% One phrase broken in the middle (\break inside the slur). System 1:
% C4 D4 E4 C4 F#4 Gb4 -> fingerings 0 13 12 . 2 2 (the second C4 already
% has its; Gb4 is spelled apart from F#4, hf7y-estate/lilypond#8 item 3).
% System 2 starts the count again: C4 D4 E4 G4 C5 -> 0 13 12 0 0. Eleven
% notes, ten fingerings. tests/mellophone.sh counts them. playerLayout =
% ##f keeps this \break (player.ily would place the breaks itself).

playerLayout = ##f
\include "mellophone.ily"

\header { tagline = ##f }
\paper { indent = 0 ragged-right = ##t }

\score {
  \new Staff \relative c' {
    \time 4/4
    c4( d e c | fis ges2. | \break
    c,4 d e g | c1) |
  }
}
