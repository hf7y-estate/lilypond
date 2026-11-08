\version "2.24.1"

% The card (Zach, 2026-11-02: "santa sangre, print melody below as
% separate system, not as cues above. so 3rd time becomes a labeled
% system."): the mids part, then the melody as its own labelled score
% under it (Songs.ily's santa_sangre-card), both through \mellophonePart.

theme = \transpose c bes {
	\partial 2.
	e8 g c'4 8 d' |

	e'1 | r4 c'8 8 4 b8 a |
	f1 | r4 d8 f b4 8 c' |
	d'1 | r4 c'8 8 4 b8 a |
	e1 | r4 e8 g c'4 8 d' |

	e'1 | r4 c'8 8 d'4 c'8 e' |
	d'2 a | r4 a8 b c'4 b8 a |
	c'4 e8 f g2 | r4 f8 g b4 8 d' |
	c'1 | r4
}

% The mids part: "Santa Sangre-C_Instruments_2.pdf" staff 1 (2026), concert
% pitch, as muertos/tools/pdf2ly.py reads it (m1's r4 + pickup is the
% \partial; m17's r4 completes the repeat). muertos/recheck.sh holds the card
% to it (recheck.tsv). The 2024 hand-entered line, a step above this one and
% with a two-note chord in m2 and m10, is gone (#8).
accompaniment = {
	\repeat volta 2 {
		\partial 2.
		bes8 d' g'4 8 a' |
		bes'1 | r4 g'8 8 4 f'8 es' |
		c'1 | r4 a8 c' f'4 8 g' |
		a'1 | r4 g'8 8 4 f'8 es' |
		bes1 | r4 bes8 d' g'4 8 a' |

		bes'1 | r4 g'8 8 a'4 g'8 bes' |
		a'2 es' | r4 es'8 f' g'4 f'8 es' |
		g'4 bes8 c' d'2 | r4 c'8 d' es'4 8 f' |
		d'1 | r4
	}
}

santa_sangre-header = \header {
	piece = "Santa Sangre"
}

santa_sangre-accompaniment = \new Staff {
	\time 4/4
	\key bes \major
	\accompaniment
}

santa_sangre-melody = \new Staff {
	\time 4/4
	\key bes \major
	\textMark \markup \box \bold \line { \concat { "3" \super "rd" } "time: melody" }
	\theme
	\bar "|."
}
