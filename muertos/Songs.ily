\version "2.24.1"

% One \bookpart per song, named <song>-card. Book.ly puts them all in
% one book; build.sh builds each alone as its own card PDF.

\include "Phone.ly"
\include "Style.ily"

\header {
	instrument = "F Mellophone"
}

\include "vis_hora.ly"
\include "santa_sangre.ly"
\include "gnossienne.ly"
\include "the_fool.ly"
\include "cairn_builder.ly"
\include "la_llorona.ly"
\include "ana_dammi_falastini.ly"
\include "love_in_outer_space.ly"
\include "zeina.ly"
\include "get_my_sound.ly"
\include "le_chant_des_partisans.ly"
\include "rin_de_angelito.ly"
\include "tabu.ly"
\include "voodoo.ly"

% Chord symbols read from the 2026 PDFs (muertos/chords.sh, #6).
\include "chords/gnossienne.ily"
\include "chords/la_llorona.ily"
\include "chords/love_in_outer_space.ily"
\include "chords/santa_sangre.ily"
\include "chords/vis_hora.ily"
\include "chords/get_my_sound.ily"
\include "chords/rin_de_angelito.ily"
\include "chords/voodoo.ily"

% \withChords CHORDS MUSIC: MUSIC with CHORDS above it in a ChordNames
% tagged #'chords. Book.ly's ddlmChords = ##t keeps them; ##f (or unset)
% takes them out with \removeWithTag #'chords. Put it inside the card's
% \transpose f c', so the chords are written in the part's key.
% Music that makes no Staff of its own (pdf2ly's songs) gets one, or its
% notes would land in the ChordNames.
#(define (ddlm-has-staff? m)
   (or (and (eq? (ly:music-property m 'name) 'ContextSpeccedMusic)
            (eq? (ly:music-property m 'context-type) 'Staff)
            (ly:music-property m 'create-new #f))  ; \new Staff, not \set Staff.x
       (any ddlm-has-staff? (ly:music-property m 'elements))
       (let ((e (ly:music-property m 'element)))
         (and (ly:music? e) (ddlm-has-staff? e)))))
withChords = #(define-music-function (chords music) (ly:music? ly:music?)
  (if (and (defined? 'ddlmChords) ddlmChords)
      (let ((staff (if (ddlm-has-staff? music) music #{ \new Staff $music #})))
        #{ << \tag #'chords \new ChordNames { #chords } #staff >> #})
      #{ \removeWithTag #'chords << \tag #'chords \new ChordNames { #chords } #music >> #}))

ana_dammi_falastini-card = \bookpart {
	\ana_dammi_falastini-header
	\transpose f c'
	\ana_dammi_falastini-accompaniment
}

cairn_builder-card = \bookpart {
	\cairn_builder-header
	\removeWithTag #'phone
	\transpose f c'
	\cairn_builder-accompaniment
}

the_fool-card = \bookpart {
	\the_fool-header
	\markup { \bold "A" "and" \bold "B" "harmony rhythms with chords" }
	\removeWithTag #'phone
	\transpose f c'
	\withChords \the_fool-chords \the_fool-accompaniment
}

gnossienne-card = \bookpart {
	\gnossienne-header
	\removeWithTag #'phone
	\transpose f c'
	\withChords \gnossienne-chords \gnossienne-accompaniment
}

la_llorona-card = \bookpart {
	\la_llorona-header
	\removeWithTag #'phone
	\transpose f c'
	\withChords \la_llorona-chords \la_llorona-accompaniment
}

love_in_outer_space-card = \bookpart {
	\love_in_outer_space-header
	\transpose f c'
	\withChords \love_in_outer_space-chords \love_in_outer_space-accompaniment
}

santa_sangre-card = \bookpart {
	\santa_sangre-header
	\removeWithTag #'phone
	\transpose f c'
	\withChords \santa_sangre-chords \santa_sangre-accompaniment
}

vis_hora-card = \bookpart {
	\vis_hora-header
	\removeWithTag #'phone
	\transpose f c'
	\withChords \vis_hora-chords \vis_hora-accompaniment
}

zeina-card = \bookpart {
	\zeina-header
	\transpose f c'
	\zeina-accompaniment
}

get_my_sound-card = \bookpart {
	\get_my_sound-header
	\transpose f c'
	\withChords \get_my_sound-chords \get_my_sound-accompaniment
}

le_chant_des_partisans-card = \bookpart {
	\le_chant_des_partisans-header
	\transpose f c'
	\le_chant_des_partisans-accompaniment
}

rin_de_angelito-card = \bookpart {
	\rin_de_angelito-header
	\transpose f c'
	\withChords \rin_de_angelito-chords \rin_de_angelito-accompaniment
}

tabu-card = \bookpart {
	\tabu-header
	\transpose f c'
	\tabu-accompaniment
}

voodoo-card = \bookpart {
	\voodoo-header
	\transpose f c'
	\withChords \voodoo-chords \voodoo-accompaniment
}
