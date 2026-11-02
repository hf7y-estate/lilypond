\version "2.24.1"

% One \bookpart per song, named <song>-card. Book.ly puts them all in
% one book; build.sh builds each alone as its own card PDF.

\include "Phone.ly"
\include "Style.ily"

\header {
	instrument = "F Mellophone"
}

\include "vis_hora.ly"
\include "santa_sangre.ly"
\include "gnossienne.ly"
\include "the_fool.ly"
\include "cairn_builder.ly"
\include "la_llorona.ly"
\include "ana_dammi_falastini.ly"
\include "love_in_outer_space.ly"
\include "zeina.ly"

ana_dammi_falastini-card = \bookpart {
	\ana_dammi_falastini-header
	\transpose f c'
	\ana_dammi_falastini-accompaniment
}

cairn_builder-card = \bookpart {
	\cairn_builder-header
	\removeWithTag #'phone
	\transpose f c'
	\cairn_builder-accompaniment
}

the_fool-card = \bookpart {
	\the_fool-header
	\markup { \bold "A" "and" \bold "B" "harmony rhythms with chords" }
	\removeWithTag #'phone
	\transpose f c'
	\the_fool-accompaniment
}

gnossienne-card = \bookpart {
	\gnossienne-header
	\removeWithTag #'phone
	\transpose f c'
	\gnossienne-accompaniment
}

la_llorona-card = \bookpart {
	\la_llorona-header
	\removeWithTag #'phone
	\transpose f c'
	\la_llorona-accompaniment
}

love_in_outer_space-card = \bookpart {
	\love_in_outer_space-header
	\transpose f c'
	\love_in_outer_space-accompaniment
}

santa_sangre-card = \bookpart {
	\santa_sangre-header
	\removeWithTag #'phone
	\transpose f c'
	\santa_sangre-accompaniment
}

vis_hora-card = \bookpart {
	\vis_hora-header
	\removeWithTag #'phone
	\transpose f c'
	\vis_hora-accompaniment
}

zeina-card = \bookpart {
	\zeina-header
	\transpose f c'
	\zeina-accompaniment
}
