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

accompaniment = \transpose c f {
	\repeat volta 2 {
		\partial 2.
		c8 f a4 8 bes |
		<c' a>1 | r4 a8 8 4 g8 f |
		g1 | r4 c8 d g4 8 a |
		bes1 | r4 bes8 8 4 a8 g |
		f1 | r4 c8 f a4 8 bes |

		<c' a>1 | r4 a8 8 bes4 a8 c' |
		bes1 | r4 g8 g a4 g8 f |
		a4 f8 g a2 | r4 g8 f g4 bes4 |
		a1 | r4
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
