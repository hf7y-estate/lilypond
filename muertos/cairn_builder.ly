\version "2.24.1"

a-theme = \transpose c c' {
	r4. c'4 bes8 | c'2. |
	r4. bes4 as8 | bes2. |
	r4. as4 g8 | f2. |
}

b-theme = \transpose c c' {
	r4. c4\f c8 | f2. |
	r4. as4. | g2. |
	r4. as4 bes8 | c'2. |
}

form = {
	\time 6/8
	\key f \minor
	\mark #1
	\repeat volta 2 {
		\a-theme
		\textEndMark "×8-12"
	}
	\cueBox \markup \center-column { 
		\line { 
			"1-2 voices start " \concat { \dynamic p "." }
			"Each repeat: add voices, crescendo. "
		}
		\vspace #0.2
		\line { 
			"Once" \italic "tutti,"
			"introduce harmonies, then improvization."
		}
		\vspace #0.2
		\line { "On cue:" \bold "B" }
	}
	\break
	\mark #2 
	\repeat volta 2 {
		% \textMark "On cue:"
		\b-theme
		\textEndMark "×4"
	}
	\cueBox \markup { "to" \bold "A" "or End." }
}

cairn_builder-header = \header {
	piece = "Cairn Builder"
	composer = "J Gerken"
}
	
cairn_builder-accompaniment =
{
	\new Staff {
		\form 
	}
}

