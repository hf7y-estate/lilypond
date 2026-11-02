\version "2.24.1"

a-melody = \transpose c c' {
	\partial 4 r8 c |
	\repeat volta 2 {
		d2. | c | d8 f~ f2 | e2 d8 c |
		d2. | c | d8 f~ f4 g | a2 g8 f |
		g2~ 8 f | g2~ 8 f | f4 g f | e2 r8 e |
		f8 e d2 | c4 d8 c~ 4 | d2. | 
		\alternative { 
			{ r2 r8 c8 | }
			{ d4 f8 g~ 4 | }
		}
	}
}

b-melody = \transpose c c' {
	a2. | c'~ | c' | r4 a g |
	f2.~ | f~ | 2 r4 | f4 g f |
	a8 g a2 | c'2.~ | c' | r4 a g |
	f2.~ | f~ | 2.~ | f4 r4
}

c-melody = \transpose c c' {
	\partial 4 r8 c |
	d2. | c | d8 f~ f2 | e2 d8 c |
	d2. | c | d8 f~ f4 g | a2 g8 f |
	g2~ 8 f | g2~ 8 f | g4~ 8 c'~ 4 | c'2 r8 c' |
	d'8 c' a2 | c'4 d'8 c'~ 4 | d'2. | r2 
}

c-harmony = {
	\partial 4 r4 |
	r4 a2~ | 4 g f | d2.~ | 4 c2 |
	r4 a2~ | 4 g f | d2.~ | d |
	r4 c d | r d a | r a c' | c' g a~ |
	a2. | r4 f2 | d2. | R2 
}

form = {
	\time 3/4
	\key d \minor
	\mark #1
	<< \a-melody 
		{
			\partial 4 s4 |
			s2.*8 | \break
		}
	>> \bar "||" \break
	\mark #2
	<< \b-melody 
		{ s2.*8 \break
			s2.*7 | s2 }
	>> \break
	\mark #3
	<< 
		\new CueVoice { \voiceOne \c-melody }
		\\
		\c-harmony
		{
			\partial 4 s4 | \bar "||"
			s2.*8 |
			s2.*7 | \partial 2 s2
		}
	>> \bar "|."
}

harmonies = \chordmode {
	\partial 4 s4 |
	d2.:m | a:m | d2.:m | a:m |
	d2.:m | a:m | d2:m a4:m | d2.:m |
	c2.: | s2. | a:m | s2. |
	d2.:m | a:m | d2.:m | R2. | s2. |

	bes2.:maj7 | s2. | s2. | R2. |
	f | s2. | s2. | R2. |
	bes2.:maj7 | s2. | s2. | R2. |
	f | s2. | s2. | s4 r4

	s4 | d2.:m | a:m | d2.:m | a:m |
	d2.:m | a:m | d2.:m | d2.:m |
	c2. | c2. | a:m | a:m |
	d2.:m | a:m | d2.:m | R2
}

the_fool-header = \header {
	piece = "The Fool"
	composer = "Neutral Milk Hotel"
}

the_fool-accompaniment =
<<
	\new ChordNames {
		\harmonies
	}
	\new Staff {
		\form
	}
>>