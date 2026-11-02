% la_llorona-chords: the chord symbols of "La Llorona F.pdf", read and placed on the
% card by muertos/tools/pdfchords.py (muertos/chords.sh --write); do not
% hand-edit. Concert pitch: Songs.ily's \transpose f c' writes them for
% the F mellophone with the notes. 8 placed, 1 left out.
% The source part sits 7 semitones above the card's concert pitch.
% left out: Gmin at source moment 19/2: the card does not carry this music as the source has it
la_llorona-chords = \transpose c f \chordmode {
	s1*12
	g1.:m  % m17 Gmin
	c1.:m  % m19 Cmin
	g1.:m  % m21 Gmin
	d1*9/4:7  % m23 D7
	g1.:m  % m26 Gmin
	f1.  % m28 F
	es1.  % m30 Eb
	d1*9/4:7  % m32 D7
}
