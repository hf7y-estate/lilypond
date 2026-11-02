\version "2.24.1"

a-theme = {
	\partial 4 r4 |
	c8 f8~f2~ | f2.~ | f~ | f |
	\repeat percent 4 { aes4. g8 \acciaccatura { aes8 } g f | }
	c8 e8~e2~ | 2.~ | 2.~ | 2 g8 aes16 a |

	bes2.~ | 2.~ | 2.~ | 2. |
	\repeat percent 4 { bes4. aes8 \acciaccatura { bes8 } aes8 g | }
	c'8 f8~f2~ | 2.~ | 2.~ | 2
}

b-theme = {
	\repeat volta 2 {
		\partial 4 a8 bes16 b |
		c'2.~ | 2.~ | 2.~ | 2. |
		\repeat percent 4 { es'4. des'8 \acciaccatura { es'8 } des'8 c' | }
		f'8 bes8~bes2~ | 2.~ | 2. | bes2 as4 |
		g8 c'8~c'2~ | 2.~ | 2.~ | 2. |

		\repeat unfold 2 { 
			c'4 bes4. aes8 | g4 aes4.
				\volta 1 { bes8 | }
				\volta 2 { c8 | }
		}
		c8 f8~f2~ | 2.~ | 2.~ | f2
	}
}

accompaniment = {
	\partial 4 <f aes c'>4-. | 
	\repeat unfold 4 { 4-. r4 4-. | }
	s2._\markup { \italic "accomp. simile" }
}

harmonies = \chordmode {
	\partial 4 s4
	f2.:m s2.*3 | s2.*4 |
	c2.:7 s2.*3 | bes2.:m s2.*3 |
	bes2.:m s2.*3 | f2.:m s2.*3 |

	f2.:7 s2.*3 | s2.*4 |
	bes2.:m s2.*3 | c2.:7 s2.*3 |
	c2.:7 s2.*3 | f2.:m s2.*2 s2
}

form = \transpose c c' {
	\key f \minor
	\time 3/4
	<< \a-theme
		{
			\partial 4 s4 | s2.*8 | \break
			\grace { s8 } s2.*8 | \break
			s2.*7 | s2 \break \tag #'phone \pageBreak
		} >>
	<< \b-theme
		{	
			\partial 4. s4 |
			s2.*8 | \break \grace { s8 }
			s2.*8 | \break
		} >>
	\cueBox \markup { "Mids take melody" \concat { "3" \super"rd" } "time" }
}

vis_hora-header = \header {
	piece = "Vi's Hora"
}

vis_hora-accompaniment =
<<
	\new ChordNames {
		\harmonies
	}
	\new Staff {
		<< 
			<< 
				\form 
				{s4 s2.*4 \oneVoice }
			>> \\
			\magnifyMusic 0.63 { \accompaniment } 
		>>
	}
>>