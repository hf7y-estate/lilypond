% ly-onsets.ily -- write every note and rest LilyPond engraves, one TSV
% line each, to the file named by the Scheme string ly-onsets-file:
%   moment  bar  note|rest  midi|-  length  voice
% moment is the event's start from the top of the score, in whole notes
% (a pickup starts at 0). Grace notes are left out (the PDF reader skips
% them too). muertos/chords.sh includes it after the book preamble, and
% muertos/tools/pdfchords.py places each chord of the source PDF at the
% moment of the card note it lines up with.
#(define ly-onsets-port (open-output-file ly-onsets-file))
#(define (ly-onsets-line ctx kind pitch len)
   (if (zero? (ly:moment-grace (ly:context-property ctx 'measurePosition)))
       (format ly-onsets-port "~a\t~a\t~a\t~a\t~a\t~a\n"
               (ly:moment-main (ly:context-current-moment ctx))
               (ly:context-property ctx 'currentBarNumber)
               kind pitch len
               (string-append (symbol->string (ly:context-name ctx)) ":"
                              (number->string (object-address ctx) 16)))))
#(define (ly-onsets-length ev)
   (ly:moment-main (ly:duration-length (ly:event-property ev 'duration))))
#(define (ly-onsets-engraver ctx)
   (make-engraver
    (listeners
     ((note-event engraver ev)
      (let ((p (ly:event-property ev 'pitch)))
        (if (ly:pitch? p)
            (ly-onsets-line ctx "note" (+ 60 (ly:pitch-semitones p)) (ly-onsets-length ev)))))
     ((rest-event engraver ev)
      (ly-onsets-line ctx "rest" "-" (ly-onsets-length ev)))
     ((multi-measure-rest-event engraver ev)
      (ly-onsets-line ctx "rest" "-" (ly-onsets-length ev))))))
\layout {
  \context { \Voice \consists #ly-onsets-engraver }
  \context { \CueVoice \consists #ly-onsets-engraver }
}
