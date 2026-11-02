\version "2.24.1"

theme = \transpose c bes {
	\repeat volta 2 {
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
}

accompaniment = \transpose c f {
	\repeat volta 2 {
		\partial 2.
		c8 f a4 8 bes |
		<c' a>1 | s4 a8 8 4 g8 f |
		g1 | s4 c8 d g4 8 a |
		bes1 | s4 bes8 8 4 a8 g |
		f1 | s4 c8 f a4 8 bes |

		<c' a>1 | s4 a8 8 bes4 a8 c' |
		bes1 | s4 g8 g a4 g8 f |
		a4 f8 g a2 | s4 g8 f g4 bes4 |
		a1 | s4
	}
}

harmonies = \chordmode {
	\partial 2.
	s2. 
	bes2 s2 | s1 |
	f2:7 s2 | s1 |
	f2:7 s2 | s1 |
	bes2 s2 | s1 |

	bes2 s2 | s1 |
	c2:m s2 | s1 |
	bes2 s2 | f2:7 s2 |
	bes2 s2 | s4
}

form = {
	\time 4/4
	\key bes \major
	<< \theme
		{ 	s2. | s1*3 | s4 \break 
			s2. | s1*3 | s4 \break
			s2. | s1*3 | s4 \break
			s2. | s1*3 | s4 }
	>>
	\cueBox \markup { "Mids take melody" \concat { "3" \super"rd" } "time" }
}

santa_sangre-header = \header {
	piece = "Santa Sangre"
}

santa_sangre-accompaniment = {
	<<
		\new ChordNames {
			\harmonies
		}
		\new Staff {
			<<
				\magnifyMusic 0.63 { \form } \\
				\accompaniment
			>>
		}
	>>
}
