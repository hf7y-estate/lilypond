\version "2.24.3"

intro-melody = {
	\repeat volta 2 {
		g8 es16 g c'4 bes8 g | 
		bes8 c'16 bes aes g f es d8. g16 |
		c'16 b c' d' es' d' c' bes aes g f es |
		\alternative {
			{ g8 aes16 g f es d c b,4 | }
			{ g8 aes16 g f es d c b,8. g16 | }
		}
	}
	\repeat volta 2 {
		c'16 b c' d' es'8. g'16 f' es' d' c' |
		bes16 a bes c' d'8. f'16 es' d' c' bes |
		aes16 g aes bes c'8. es'16 d' c' b c' |
		\alternative {
			{ d'8 d'16 c' b aes g f g8. g16 | }
			{ d'8 d'16 c' b aes g f g4\fermata | }
		}	
	}
	s2. | s2. |
	s2.*4 |
}

intro-accompaniment = {
	\repeat volta 2 {
		g4 c'4 bes4 | 
		bes4 aes4 g4 |
		c'4 es'4 aes4 |
		\alternative {
			{ g4 f4 g4 | }
			{ g4 f4 g4 | }
		}
	}
	\repeat volta 2 {
		c'4 es'4 f'4 |
		bes4 d'4 es'4 |
		aes4 c'4 d'4 |
		\alternative {
			{ d'4 b4 g4 | }
			{ d'4 b4 g4\fermata | }
		}	
	}
	<g b>4^"Midhorns" <aes c'> <g b> |
	<f aes> <es g> <d f> |

	\repeat percent 4 { r4 <g c' es'>4 4 | }
}

a-melody = {
	\repeat volta 2 {
		g2 8 8 | 4 4 4 | 
		bes4 aes r8 8 | bes4 aes r8 8 |
		g4 4 4 | r aes g |
		g4 f r4 | 
		\alternative {
			{ R2. | }
			{ r4 r f | }
		}
	}
}

b-melody = {
	\repeat volta 2 {
		c'2 8 8 | es'4 c'4 4 | 
		d'4 bes r8 8 | d'4 bes4 4 |
		aes4 4 4 | c'4 d'4. c'8 |
		b4 g r4 | 
		\alternative {
			{ r4 r g | }
			{ R2. | }
		}
	}
}

harmonies = \chordmode {
	s2.*5 | s2.*5 | s2.*2 |
	c2.:m | s2.*3 |

	% a-melody
	c2.:m | s2. | f2.:m | s2. |
	c2.:m | s2. | g2.:7 | s2. | s2. |

	% b-melody
	c2.:m | s2. | bes2. | s2. |
	aes2. | s2. | g2.:7 | s2. | s2. |
}

form = {
	\time 3/4 
	\key c \minor
	<<
		\transpose c c' \intro-melody
		{ 
			s2.*5 | \break
			s2.*4 | \break s2.
			s2.*2 | \bar "||" s2.*4 }
	>>
	\break
	\mark #1
	\transpose c c \a-melody \break
	\mark #2
	\transpose c c \b-melody \bar "|."
}

accompaniment-form = \transpose c c {
	\time 3/4 
	\key c \minor
	<<
		\intro-accompaniment
		{ s2.*5 | s2.*5 | \oneVoice s2.*2 | \bar "||" s2.*4 }
	>>
	s2._\markup { \italic "accomp. simile" }
}

la_llorona-header = \header {
	piece = "La Llorona"
}

la_llorona-accompaniment =
<<
	\new ChordNames {
		\harmonies
	}
	\new Staff {
		<< 
			<< 
				\form
				{ 
					\magnifyMusic 0.63 {
						s2.*5 | s2.*5 | s2.*2 | }
					\bar "||" s2.*4 \oneVoice
				}
			>> \\
			\accompaniment-form
		>>
	}
>>