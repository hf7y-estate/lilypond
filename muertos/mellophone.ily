\version "2.24.1"

% mellophone.ily -- for any F mellophone part, engraved at written pitch.
% Include it before the scores (Book.ly does). It adds to every Voice:
%
% * Fingering: the trumpet valve combination ("0", "13", "123", ...),
%   always above the staff, on the FIRST occurrence of each written pitch
%   IN EACH SYSTEM, and only on the top note: of all the notes starting
%   at one moment on a staff, in any voice, only the highest is fingered
%   (hf7y-estate/lilypond#8, items 4-5: "12", not "1-2"). The pitch is the
%   spelled pitch: Db and C# are two pitches (#8 item 3; this reverses
%   #5's "enharmonics count as the same pitch"). Which note is first in
%   its system is only known after line breaking, so every top note gets
%   a fingering and the Fingering grob's after-line-breaking drops each
%   one an earlier note of the same pitch, on the same staff and in the
%   same system, already has. Toggle: set  mellophoneFingering = ##f
%   before the \include.
%
% * Range: written C4-C6, the player profile's (player.ily, #8 item 1).
%   A note outside it is a LilyPond warning naming the song (its source
%   file) and the measure, and every run writes <output>-range.txt: each
%   song's lowest and highest written note and every note outside the
%   range.
%
% Fingerings: "Fingerings for the mellophone are the same as fingerings for
% the trumpet" (en.wikipedia.org/wiki/Mellophone). From the trumpet's chart
% (en.wikipedia.org/wiki/Trumpet#Fingering, File:Special-T trumpet overtone
% series.png): the open notes are written C4 G4 C5 E5 G5 C6, with Bb5 in
% parentheses ("flat ... use of those fingerings is generally avoided");
% valve 2 lowers a half step, 1 a whole step, 1-2 one and a half, 2-3 two,
% 1-3 two and a half, 1-2-3 three. A note's fingering is the open note
% nearest above it, lowered by the fewest semitones: this gives the chart's
% standard fingerings (12 rather than 3, 0 rather than 13 for G4).

\include "player.ily"

#(define mellophone-fingering-on
   (if (defined? 'mellophoneFingering) mellophoneFingering #t))

% semitones above c' (written C4) of the open notes, without Bb5
#(define mellophone-open '(0 7 12 16 19 24))
#(define mellophone-valves #("0" "2" "1" "12" "23" "13" "123"))
% written range, semitones above c': the player profile's C4 .. C6
#(define mellophone-low player-low)
#(define mellophone-high player-high)
#(define (mellophone-fingering semis)
   "Valve combination for a written pitch SEMIS semitones above c', or #f."
   (let loop ((o mellophone-open))
     (cond ((null? o) #f)
           ((<= 0 (- (car o) semis) 6) (vector-ref mellophone-valves (- (car o) semis)))
           (else (loop (cdr o))))))

#(define (mellophone-pitch-name p)
   "Scientific name of written pitch P: c' is C4, fis is F#3, bes'' is Bb5."
   (string-append
    (vector-ref #("C" "D" "E" "F" "G" "A" "B") (ly:pitch-notename p))
    (case (ly:pitch-alteration p)
      ((-1) "bb") ((-1/2) "b") ((0) "") ((1/2) "#") ((1) "##") (else "?"))
    (number->string (+ 4 (ly:pitch-octave p)))))

#(define mellophone-range-name
   (string-append (mellophone-pitch-name (ly:make-pitch 0 0 0)) "-"
                  (mellophone-pitch-name (ly:make-pitch 2 0 0))))

#(define (mellophone-song event)
   "The song an event belongs to: the basename of the file it was written in."
   (let* ((origin (ly:event-property event 'origin #f))
          (file (if (ly:input-location? origin)
                    (car (ly:input-file-line-char-column origin))
                    "?"))
          (base (basename file)))
     (if (string-suffix? ".ly" base)
         (substring base 0 (- (string-length base) 3))
         base)))

% song -> #(lowest-pitch highest-pitch outside-list), songs in first-seen order
#(define mellophone-songs '())
#(define mellophone-seen (make-hash-table))

#(define (mellophone-note! song bar p)
   (let ((row (or (hash-ref mellophone-seen song)
                  (let ((r (vector p p '())))
                    (hash-set! mellophone-seen song r)
                    (set! mellophone-songs (append mellophone-songs (list song)))
                    r)))
         (s (ly:pitch-semitones p)))
     (if (< s (ly:pitch-semitones (vector-ref row 0))) (vector-set! row 0 p))
     (if (> s (ly:pitch-semitones (vector-ref row 1))) (vector-set! row 1 p))
     (if (or (< s mellophone-low) (> s mellophone-high))
         (vector-set! row 2 (append (vector-ref row 2) (list (cons bar p)))))))

#(define (mellophone-write-report)
   (let ((file (string-append (ly:parser-output-name) "-range.txt")))
     (call-with-output-file file
       (lambda (port)
         (format port "F mellophone, written pitch. Range ~a.\n" mellophone-range-name)
         (format port "song\tlowest\thighest\toutside ~a\n" mellophone-range-name)
         (for-each
          (lambda (song)
            (let ((row (hash-ref mellophone-seen song)))
              (format port "~a\t~a\t~a\t~a\n" song
                      (mellophone-pitch-name (vector-ref row 0))
                      (mellophone-pitch-name (vector-ref row 1))
                      (if (null? (vector-ref row 2))
                          "none"
                          (string-join
                           (map (lambda (o)
                                  (format #f "m~a ~a" (car o) (mellophone-pitch-name (cdr o))))
                                (vector-ref row 2))
                           ", ")))))
          mellophone-songs)))))

#(define (Mellophone_engraver context)
   (make-engraver
    (listeners
     ((note-event engraver event)
      (let ((p (ly:event-property event 'pitch #f)))
        (if (ly:pitch? p)
            (let ((s (ly:pitch-semitones p))
                  (song (mellophone-song event))
                  (bar (ly:context-property context 'currentBarNumber "?")))
              (mellophone-note! song bar p)
              (if (or (< s mellophone-low) (> s mellophone-high))
                  (ly:warning "mellophone: ~a, m~a: written ~a is outside ~a"
                              song bar (mellophone-pitch-name p)
                              mellophone-range-name)))))))
    ((finalize engraver) (mellophone-write-report))))

#(define (mellophone-key p)
   "A spelled written pitch: Db4 and C#4 are two keys."
   (list (ly:pitch-octave p) (ly:pitch-notename p) (ly:pitch-alteration p)))

#(define (mellophone-ours? a) (ly:event-property a 'mellophone-key #f))

#(define (mellophone-unfinger! event)
   (ly:event-set-property!
    event 'articulations
    (remove mellophone-ours? (ly:event-property event 'articulations '()))))

#(define (mellophone-finger! event context)
   "Put EVENT's valve combination on it, unless it already has it."
   (let* ((p (ly:event-property event 'pitch))
          (f (mellophone-fingering (ly:pitch-semitones p))))
     (if (and f (not (any mellophone-ours? (ly:event-property event 'articulations '()))))
         ;; New_fingering_engraver reads fingering events off the note's
         ;; articulations when it meets the note head.
         (ly:event-set-property!
          event 'articulations
          (cons (ly:make-stream-event
                 (ly:make-event-class 'fingering-event)
                 `((text . ,f)
                   (direction . ,UP)
                   (mellophone-key . ,(mellophone-key p))
                   (mellophone-name . ,(mellophone-pitch-name p))
                   (mellophone-song . ,(mellophone-song event))
                   (mellophone-bar . ,(ly:context-property context 'currentBarNumber "?"))
                   (origin . ,(ly:event-property event 'origin))))
                (ly:event-property event 'articulations '()))))))

% On a Staff: of the notes starting at one moment, in any of its voices,
% only the highest keeps a fingering. Every note event reaches the Staff
% before any engraver makes a note head, so a higher note arriving later
% in the same moment takes the fingering off the one before.
#(define (Mellophone_top_engraver context)
   (let ((top #f))
     (make-engraver
      ((start-translation-timestep engraver) (set! top #f))
      (listeners
       ((note-event engraver event)
        (let ((p (ly:event-property event 'pitch #f)))
          (if (and mellophone-fingering-on (ly:pitch? p)
                   (or (not top)
                       (> (ly:pitch-semitones p)
                          (ly:pitch-semitones (ly:event-property top 'pitch)))))
              (begin
                (if top (mellophone-unfinger! top))
                (mellophone-finger! event context)
                (set! top event)))))))))

#(define (mellophone-first-in-system grob)
   "Kill a mellophone fingering that an earlier one of the same pitch, on
the same staff, in the same system already shows."
   (let* ((cause (event-cause grob))
          (s (and cause (ly:event-property cause 'mellophone-key #f)))
          (sys (and s (ly:grob-system grob))))
     (if sys
         (let ((staff (ly:grob-get-vertical-axis-group-index grob))
               (when (lambda (g) (ly:grob-property (ly:item-get-column g) 'when))))
           (let loop ((gs (ly:grob-array->list (ly:grob-object sys 'all-elements)))
                      (before-me #t))
             (if (pair? gs)
                 (let* ((g (car gs))
                        (c (and (not (eq? g grob))
                                (eq? (grob::name g) 'Fingering)
                                (event-cause g)))
                        (same (and c
                                   (equal? s (ly:event-property c 'mellophone-key #f))
                                   (eqv? staff (ly:grob-get-vertical-axis-group-index g))))
                        (earlier (and same
                                      (let ((a (when g)) (b (when grob)))
                                        (or (ly:moment<? a b)
                                            (and before-me (equal? a b)))))))
                   (cond
                    (earlier (ly:grob-suicide! grob))
                    ((pair? (cdr gs)) (loop (cdr gs) (and before-me (not (eq? g grob)))))
                    (else (player-log "finger"
                                      (ly:event-property cause 'mellophone-song)
                                      (ly:event-property cause 'mellophone-bar)
                                      (ly:event-property cause 'mellophone-name)
                                      (ly:event-property cause 'text)))))))))))

\layout {
  \context {
    \Staff
    \consists #Mellophone_top_engraver
  }
  \context {
    \Voice
    \consists #Mellophone_engraver
    \override Fingering.after-line-breaking = #mellophone-first-in-system
    \override Fingering.direction = #UP
    \override Fingering.font-encoding = #'latin1
    \override Fingering.font-size = #-4
  }
}
