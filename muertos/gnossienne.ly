\version "2.24.1"

a-theme = \repeat volta 2 \transpose c c'' {
	r4\p c8 es d4 c | \repeat unfold 2 { \acciaccatura { c8 } b,2 } |
	r4 c8 es d4 c | \repeat unfold 2 { \acciaccatura { e8 } f2 } |
	r4 c8 es d4 c | \acciaccatura { c8 } b,2 \acciaccatura { aes,?8 } g,2 |
	\acciaccatura { f,8 } g,4 \acciaccatura { f,8 } g,2. | 
		\acciaccatura { aes,?8 } g,4 \acciaccatura { g,8 } f,2. |
		R1 |
}

b-theme = \repeat volta 2 \transpose c c' {
	\acciaccatura { aes8 } bes2\f \acciaccatura { aes8 } g2 |
	\acciaccatura { aes8 } bes2 \acciaccatura { aes8 } g2 |
	\acciaccatura { aes8 } g4\p \acciaccatura { g8 } f2. | R1 |
}

c-theme = \repeat volta 2 \transpose c c'' {
	r8 c d e f g b g | f4 \acciaccatura { g8 } f2. |
	\acciaccatura { g8 } f2 \acciaccatura { f8 } e2 |
	\acciaccatura { des?8 } c2 \acciaccatura { c8 } b,2 |
	\acciaccatura { aes,?8 } g,4 \acciaccatura { g,8 } f,2. |
	R1 |
}

accompaniment = {
	\repeat unfold 2 { r4 <f aes c'>2-- 4-. }
	s1_\markup "accomp. simile"
}

harmonies = \chordmode {
	f1:m | s1 |
	f1:m | s1 |
	f1:m | s1 | c1:m |
	f1:m | s1 |

	bes1:m | s1 |
	f1:m | s1 |

	f1:m | s1 |
	f1:m | s1 |
	f1:m | s1 |
}

form = {
	\textMark "Lent"
	\time 4/4
	\key f \minor
	\mark #1
	<< \a-theme
		{
			s1*4 \break |
			s1*5 \break |
		} >>
	\mark #2
	\b-theme \break
	\mark #3 
	\c-theme \break
	\mark #2
	\b-theme 
	\cueBox \markup { "Mids take melodies" \bold "A" "&" \bold "B" \concat { "3" \super"rd" }"time" }
}

gnossienne-header = \header {
	piece = \markup {
	\concat { "1" \super "ère" } "Gnossienne" }
}
gnossienne-accompaniment = {
	<<
		\new ChordNames {
			\harmonies
		}
		\new Staff {
			<< 
				<< 
					\form
					{ s1 | s1 | \oneVoice }
				>> \\
				\magnifyMusic 0.63 { \accompaniment }
			>>
		}
	>>
}