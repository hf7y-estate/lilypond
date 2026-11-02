\version "2.24.1"

% The F mellophone card book: muertos/build.sh builds it, and builds each
% song's card from this preamble (everything but the \<song>-card lines).

% ##f: no valve fingerings (the range check and report stay on).
mellophoneFingering = ##t
\include "mellophone.ily"
\include "Songs.ily"

\ana_dammi_falastini-card
\cairn_builder-card
\the_fool-card
\gnossienne-card
\la_llorona-card
\love_in_outer_space-card
\santa_sangre-card
\vis_hora-card
\zeina-card
