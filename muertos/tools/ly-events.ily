% ly-events.ily -- write every note and rest LilyPond engraves, one TSV
% line each, to the file named by the Scheme string ly-events-file:
%   bar  position-in-bar  measure-length  note|rest|mrest|tie  midi|-  length  voice
% Lengths and positions are in whole notes. Grace notes are left out (the
% PDF reader skips them too). muertos/recheck.sh includes it after the
% book preamble and compares the lines with muertos/tools/recheck.py.
#(define ly-events-port (open-output-file ly-events-file))
#(define (ly-events-line ctx kind pitch len)
   (if (zero? (ly:moment-grace (ly:context-property ctx 'measurePosition)))
       (format ly-events-port "~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
               (ly:context-property ctx 'currentBarNumber)
               (ly:moment-main (ly:context-property ctx 'measurePosition))
               (ly:moment-main (ly:context-property ctx 'measureLength))
               kind pitch len
               (string-append (symbol->string (ly:context-name ctx)) ":"
                              (number->string (object-address ctx) 16)))))
#(define (ly-events-length ev)
   (ly:moment-main (ly:duration-length (ly:event-property ev 'duration))))
#(define (ly-events-engraver ctx)
   (make-engraver
    (listeners
     ((note-event engraver ev)
      (let ((p (ly:event-property ev 'pitch)))
        (if (ly:pitch? p)
            (ly-events-line ctx "note" (+ 60 (ly:pitch-semitones p)) (ly-events-length ev)))))
     ((rest-event engraver ev)
      (ly-events-line ctx "rest" "-" (ly-events-length ev)))
     ((multi-measure-rest-event engraver ev)
      (ly-events-line ctx "mrest" "-" (ly-events-length ev)))
     ((tie-event engraver ev)
      (ly-events-line ctx "tie" "-" 0)))))
\layout {
  \context { \Voice \consists #ly-events-engraver }
  \context { \CueVoice \consists #ly-events-engraver }
}
