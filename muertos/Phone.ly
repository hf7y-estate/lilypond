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
  (cons '("quarter" . (cons (* 5.5 in) (* 4.25 in))) paper-alist))
#(set! paper-alist
  (cons '("phone" . (cons (* 5.5 in) (* 2.5 in))) paper-alist))

\paper {
  % The lyre cards (#21): 5.5x4.25in, systems packed from the top at
  % 10 staff spaces (never under 9), no stretch. A card holds 6 systems
  % (player.ily's player-card-systems, measured with this spacing); a
  % song with more goes on to more cards, at the breaks player.ily picks.
  system-system-spacing =
    #'((basic-distance . 10)
       (minimum-distance . 9)
       (padding . 1)
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
    #'((basic-distance . 10)
       (minimum-distance . 0)
       (padding . 0)
       (stretchability . 12))

  % #(set-paper-size "phone")
  #(set-paper-size "quarter")

    scoreTitleMarkup = \markup {
      \fill-line {
        \fromproperty #'header:instrument
        \fontsize #2 \bold \fromproperty #'header:piece
        \fromproperty #'header:composer
      }
    }
    bookTitleMarkup = \markup { }
    evenHeaderMarkup = \markup \null
    oddHeaderMarkup = \markup \null
}

#(set-global-staff-size 14)