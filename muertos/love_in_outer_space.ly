\version "2.24.3"

melody = {
	g2. | g2. | s2. | g2 f8 es |
	d8 es d2 | s2. | s2. | d2 es4 |
	f2. | s2. | s2. | f2 c4 |
	es8 c c2 | s2. | s2. | c2 d4 |

	es4 r r | es4 r r | es4 r r | es2 d4 |
	c4 bes,2 | s2. |  s2. | s2. |
}

accompaniment = {
	\repeat unfold 2 { 
		<g bes d'>2 r4 | q8 q r2 |
	}
	\repeat unfold 2 { 
		<fis a d'>2 r4 | q8 q r2 |
	}
	\repeat unfold 2 { 
		<f! aes! c'>2 r4 | q8 q r2 |
	}
	\repeat unfold 2 { 
		<es g c'>2 r4 | q8 q r2 |
	}
	\repeat unfold 2 { 
		<e aes bes>2 r4 | q8 q r2 |
	}
	\repeat unfold 2 { 
		<es g c'>2 r4 | q8 q r2 |
	}
}

form = {
	\time 3/4
	\key es \major
	\repeat volta 2 {
		s2.*8 | \break
		s2.*8 | \break
		s2.*8 |
	}
}

love_in_outer_space-header = \header {
    piece =  "Love In Outer Space"
    composer = "Sun Ra"
    tagline = ""
}

love_in_outer_space-accompaniment = {
	<<
		\new Staff {
			<<
				\form
				<< 
					\magnifyMusic #'0.63 \transpose c c' \melody \\
					\accompaniment
				>>
			>>
		}
	>>
}