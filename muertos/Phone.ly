\version "2.24.3"

% This file should only include formatting adjustments needed to make a
% score look good on a phone screen. In its proper implementation, this
% file can just be commented out from a score and the score should still
% compile just fine

%These can be redefined locally , I think
\layout {
	indent = #0
	ragged-last = ##f
	\context {
		\Score
		rehearsalMarkFormatter = #format-mark-box-alphabet
       % \override RehearsalMark.font-name = #"Bitstream Charter"
       \override RehearsalMark.padding = #0.5
       \override RehearsalMark.X-offset = #-2
       \override RehearsalMark.font-size = #3
       \override TimeSignature.break-visibility = ##(#f #t #t)
	}
	\context {
		\Staff
		% \RemoveAllEmptyStaves
		aDueText = #""
		soloIIText = #""
		soloText = #""
	}
}


#(set! paper-alist
  (cons '("card" . (cons (* 5.5 in) (* 8.5 in))) paper-alist))
#(set! paper-alist
  (cons '("phone" . (cons (* 5.5 in) (* 2.5 in))) paper-alist))

#(set! paper-alist
  (cons '("lyre" . (cons (* 5.5 in) (* 6 in))) paper-alist))

\paper {
  % The lyre cards (#25, Zach 2026-11-02: "treat the page height as 6
  % inches including margin"): 5.5x6in, systems packed from the top at
  % 8 staff spaces (never under 7, 0.5 between skylines), no stretch: "generally pieces on 2
  % pages now should aim for 1 page", so the spacing is tighter than #21's
  % 10. player.ily's player-card-systems is what a card holds at this
  % spacing; a song with more goes on to a second card.
  system-system-spacing =
    #'((basic-distance . 8)
       (minimum-distance . 7)
       (padding . 0.5)
       (stretchability . 0))
  ragged-bottom = ##t
  ragged-last-bottom = ##t
  top-margin = 0.25\in
  bottom-margin = 0.25\in
  left-margin = 0.3\in
  right-margin = 0.3\in
  % the card's spare height goes between the systems, not under the last
  last-bottom-spacing.stretchability = 0
  markup-system-spacing =
    #'((basic-distance . 8)
       (minimum-distance . 0)
       (padding . 0)
       (stretchability . 12))

  #(set-paper-size "lyre")

    scoreTitleMarkup = \markup {
      \fill-line {
        \fromproperty #'header:instrument
        \fontsize #2 \bold \fromproperty #'header:piece
        \fromproperty #'header:composer
      }
    }
    bookTitleMarkup = \markup { }
    % a song's 2nd card: its name, small, top left, so the cards collate
    % (#25: "print small title where possible on 2nd pages")
    evenHeaderMarkup = \markup \unless \on-first-page-of-part
      \fill-line { \small \italic \fromproperty #'header:piece \null }
    oddHeaderMarkup = \evenHeaderMarkup
}

#(set-global-staff-size 14)