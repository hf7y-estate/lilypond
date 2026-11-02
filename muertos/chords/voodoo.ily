% voodoo-chords: the chord symbols of "Voodoo mids F horn.pdf", read and placed on the
% card by muertos/tools/pdfchords.py (muertos/chords.sh --write); do not
% hand-edit. Concert pitch: Songs.ily's \transpose f c' writes them for
% the F mellophone with the notes. 10 placed, 0 left out.
% The source part sits 7 semitones above the card's concert pitch.
voodoo-chords = \transpose c f \chordmode {
	d1*8:m  % m1 Dmin
	g1*4:m  % m9 Gmin
	cis\breve:dim  % m13 C#o
	d\breve:m  % m15 Dmin
	d1:m  % m17 Dmin
	g2:dim  % m18 Go
	cis2:dim  % m18 C#o
	d1:m  % m19 Dmin
	e2:dim  % m20 Eo
	cis1*37/2:dim  % m20 C#o
}
