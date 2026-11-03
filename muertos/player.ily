\version "2.24.1"

% player.ily -- the player profile for the F mellophone card book
% (hf7y-estate/lilypond#8, "Player profile"). Every card's part goes
% through \mellophonePart, once, the same way; there are no per-song fixes.
%
%   \mellophonePart MUSIC
%     1. \transpose f c' MUSIC: written pitch, chord symbols included (#6).
%     2. Top-note reduction (#8 item 7): every stacked chord keeps only its
%        highest note. ChordNames are left alone.
%     3. Range fit (#8 items 1-2): each line is split into phrases at
%        breaths only (a rest or skip, a rehearsal mark, a slur or phrasing
%        slur ending on a note, a breath mark, an untied note a whole note
%        or longer) and each phrase gets one octave shift, 0, -8 or +8,
%        chosen for the whole line at once (dynamic programming over the
%        phrases). Costs, most important first: a join leap wider than a
%        perfect fifth where the shift changes (the hard limit: leaving
%        everything as written never has one), notes outside written
%        C4-C6, a repeat or sequence not on its first phrase's shift
%        (item 2: "Repeated or sequential phrases take the same shift"; the
%        same two notes, or from three notes on the same intervals), octave
%        changes, the size of the leaps at changed joins (doubled when no
%        rest separates the phrases), phrases moved.
%        Notes inside a phrase all move together, so a new leap can only
%        appear at a join. Each part of a << >> is its own line; the lower
%        voices of << ... \\ ... >> are not fitted (the player takes the
%        top voice, item 7) and stay as written.
%   Not here yet (#8 items 8 and 10): borrowing another part's measures,
%   the beat skeleton and the tuba fallback. A phrase the shifts cannot
%   fit stays as it is and is still warned about and listed by
%   mellophone.ily's range report.
%
% Layout (#8 item 6), for every score: Player_layout_engraver places the
% line breaks itself and ignores the songs' own \break. A system holds
% about four 4/4 bars: a bar costs its length in whole notes (at most 1:
% a compressed multi-measure rest prints as one bar) or its onsets / 8 if
% more, and a system takes bars while their cost is <= 4. A rehearsal
% mark starts a new system once the current one has 2 bars; no system
% has fewer than 2 bars unless the song does. A song goes on as many
% 5.5x4.25in cards (#21) as its systems need at player-card-systems a card
% (player-card-systems-first on the card with the title), and
% player-card-breaks puts each page break at a system start that keeps
% every card within that: at a rehearsal mark if one is in reach, else at
% a rest (one ends at the bar line, or the bar opens with one), else the
% start nearest an even split; no other page break is allowed. Phone.ly
% packs the systems from the top of the card (ragged-bottom). One staff
% size for every card (Phone.ly's set-global-staff-size).
%
% Every run writes <output>-layout.txt for tests/ddlm-player.sh:
%   system <TAB> song <TAB> systems <TAB> staff height in pt (0.01pt)
%   page <TAB> song <TAB> card <TAB> its first system <TAB> systems <TAB>
%        its first bar <TAB> mark|rest|none   (one per card after the first)
%   finger <TAB> song <TAB> bar <TAB> written pitch <TAB> fingering
% one "system" line per staff, one "finger" line per printed fingering.

% written range, semitones above c' (written C4): C4 .. C6 (Zach,
% 2026-11-02: "I can play a written middle C up two octaves to a higehr
% C, no more")
#(define player-low 0)
#(define player-high 24)
% widest leap allowed at a join where the octave shift changes: a fifth
% (Zach, 2026-11-02: "make this smaller, like a fifth")
#(define player-join-limit 7)
% a system's budget, in 4/4 bars of up to 8 onsets
#(define player-system-budget 4)
#(define player-min-bars 2)
% systems one 5.5x4.25in card holds, measured on this book with Phone.ly's
% spacing (staff size 14, systems 9-10 staff spaces apart), both builds
% (with chords and without): at 6 a card, title card included, LilyPond
% compresses no card; at 7 on the cards after the first, a chords card is
% over-full (build.sh refuses either). 7 on the title card alone also
% fits, and saves no card in this book (the same 23 cards), so it is 6 too.
#(define player-card-systems-first 6)
#(define player-card-systems 6)
% playerLayout = ##f before the \include: keep the score's own breaks
% (tests/mellophone.sh's fixture needs its \break)
#(define player-layout-on (if (defined? 'playerLayout) playerLayout #t))

%% ---------------------------------------------------------------- music

#(define (player-note? m)
   (and (eq? (ly:music-property m 'name) 'NoteEvent)
        (ly:pitch? (ly:music-property m 'pitch #f))))

#(define (player-semis n) (ly:pitch-semitones (ly:music-property n 'pitch)))

#(define (player-not-notes? m)
   "Music that is not the part's notes: chord symbols, lyrics, figures."
   (and (eq? (ly:music-property m 'name) 'ContextSpeccedMusic)
        (memq (ly:music-property m 'context-type)
              '(ChordNames FiguredBass Lyrics NullVoice Devnull))))

#(define (player-top-notes! m)
   "Reduce every chord in M to its highest note, in place."
   (cond
    ((player-not-notes? m) #t)
    ((eq? (ly:music-property m 'name) 'EventChord)
     (let* ((els (ly:music-property m 'elements '()))
            (notes (filter player-note? els)))
       (if (> (length notes) 1)
           (let ((top (fold (lambda (n best)
                              (if (> (player-semis n) (player-semis best)) n best))
                            (car notes) (cdr notes))))
             (ly:music-set-property!
              m 'elements
              (filter (lambda (e) (or (not (player-note? e)) (eq? e top))) els))))))
    (else
     (let ((e (ly:music-property m 'element #f)))
       (if (ly:music? e) (player-top-notes! e)))
     (for-each player-top-notes! (ly:music-property m 'elements '())))))

#(define (player-named? names) (lambda (a) (memq (ly:music-property a 'name) names)))

#(define (player-note-item m notes line)
   "Add the note group NOTES (the notes of M) to LINE, and a breath after
it if a phrase ends on it."
   (let* ((arts (append (ly:music-property m 'elements '())
                        (append-map (lambda (n) (ly:music-property n 'articulations '()))
                                    notes)))
          (ends (any (lambda (a)
                       (or (and ((player-named? '(SlurEvent PhrasingSlurEvent)) a)
                                (eqv? (ly:music-property a 'span-direction) STOP))
                           ((player-named? '(BreathingEvent)) a)))
                     arts))
          (tied (any (player-named? '(TieEvent)) arts))
          (d (ly:music-property (car notes) 'duration #f))
          (long (and (ly:duration? d)
                     (not (ly:moment<? (ly:duration-length d) (ly:make-moment 1)))))
          (line (cons notes line)))
     (if (or ends (and long (not tied))) (cons 'breath line) line)))

#(define (player-top-voice elements)
   "The elements of a << >> that are not a lower voice. In << a \\\\ b >>,
which \\mellophonePart sees before LilyPond turns it into voices, b comes
after a VoiceSeparator; the player takes the top voice (item 7), so b is
left where it is written."
   (let loop ((els elements) (out '()))
     (cond ((null? els) (reverse out))
           ((eq? (ly:music-property (car els) 'name) 'VoiceSeparator) (reverse out))
           (else (loop (cdr els) (cons (car els) out))))))

#(define (player-lines m)
   "The lines of M, each a list in time order of note groups (lists of
NoteEvents) and the symbols rest and breath. Each part of a << >> is a
line of its own, but for the lower voices of a << ... \\\\ ... >>."
   (let ((lines '()))
     (define (walk m line)
       (let ((name (ly:music-property m 'name)))
         (cond
          ((player-not-notes? m) line)
          ((player-note? m) (player-note-item m (list m) line))
          ((eq? name 'EventChord)
           (let* ((els (ly:music-property m 'elements '()))
                  (notes (filter player-note? els)))
             (cond ((pair? notes) (player-note-item m notes line))
                   ((any (player-named? '(RestEvent MultiMeasureRestEvent SkipEvent)) els)
                    (cons 'rest line))
                   (else line))))
          ((or (memq name '(RestEvent MultiMeasureRestMusic MultiMeasureRestEvent
                            SkipEvent SkipMusic))
               (music-is-of-type? m 'mark-event))
           (cons 'rest line))
          ((eq? name 'BreathingEvent) (cons 'breath line))
          ((eq? name 'SimultaneousMusic)
           (for-each (lambda (e) (set! lines (cons (reverse (walk e '())) lines)))
                     (player-top-voice (ly:music-property m 'elements '())))
           (cons 'breath line))
          (else
           (let* ((e (ly:music-property m 'element #f))
                  (line (if (ly:music? e) (walk e line) line)))
             (fold walk line (ly:music-property m 'elements '())))))))
     (set! lines (cons (reverse (walk m '())) lines))
     (reverse lines)))

#(define (player-phrases line)
   "LINE's phrases: vectors #(groups rest-before?), groups in time order."
   (let loop ((items line) (cur '()) (rest? #f) (cur-rest? #f) (out '()))
     (define (close) (if (null? cur) out (cons (vector (reverse cur) cur-rest?) out)))
     (cond
      ((null? items) (reverse (close)))
      ((symbol? (car items))
       (if (null? cur)
           (loop (cdr items) '() (or rest? (eq? (car items) 'rest)) #f out)
           (loop (cdr items) '() (eq? (car items) 'rest) #f (close))))
      ((null? cur) (loop (cdr items) (list (car items)) #f rest? out))
      (else (loop (cdr items) (cons (car items) cur) rest? cur-rest? out)))))

#(define player-shifts '(0 -12 12))

#(define (player-cost<? a b)
   (cond ((null? a) #f)
         ((< (car a) (car b)) #t)
         ((> (car a) (car b)) #f)
         (else (player-cost<? (cdr a) (cdr b)))))

#(define (player-group-top g) (apply max (map player-semis g)))

#(define (player-phrase-tops p) (map player-group-top (vector-ref p 0)))

#(define (player-phrase-key p)
   "What makes two phrases the same for item 2's \"repeated or sequential
phrases take the same shift\": the same two notes, or, from three notes
on, the same intervals (a sequence: the same figure at another pitch).
A lone note is no phrase to repeat: #f."
   (let ((tops (player-phrase-tops p)))
     (cond ((>= (length tops) 3)
            (cons 'intervals (map - (cdr tops) (list-head tops (1- (length tops))))))
           ((= (length tops) 2) (cons 'notes tops))
           (else #f))))

#(define (player-leaders phrases)
   "Per phrase, the index of the first phrase with its key (itself when it
is the first), or #f."
   (let ((seen (make-hash-table)) (n (vector-length phrases)))
     (list->vector
      (map (lambda (i)
             (let ((key (player-phrase-key (vector-ref phrases i))))
               (and key
                    (or (hash-ref seen key)
                        (begin (hash-set! seen key i) i)))))
           (iota n)))))

#(define (player-choose phrases leaders targets)
   "The dynamic programme: per phrase, the index in player-shifts of its
shift. Costs, most important first: join leaps over player-join-limit,
notes out of range, repeats not on their first phrase's shift (TARGETS,
by phrase index), octave changes, leap size at changed joins, phrases
moved."
   (let* ((n (vector-length phrases))
          (k (length player-shifts))
          (best (make-vector n #f))     ; per phrase: vector of (cost . back)
          (own (lambda (i s)
                 (let ((out 0) (l (vector-ref leaders i)))
                   (for-each
                    (lambda (g)
                      (for-each (lambda (note)
                                  (let ((x (+ s (player-semis note))))
                                    (if (or (< x player-low) (> x player-high))
                                        (set! out (1+ out)))))
                                g))
                    (vector-ref (vector-ref phrases i) 0))
                   (list 0 out
                         (if (and l (not (= l i)) (vector-ref targets l)
                                  (not (= s (vector-ref targets l))))
                             1 0)
                         0 0 (if (zero? s) 0 1)))))
          (join (lambda (prev a p b)
                  (if (= a b)
                      (list 0 0 0 0 0 0)
                      (let* ((from (+ a (player-group-top (last (vector-ref prev 0)))))
                             (to (+ b (player-group-top (car (vector-ref p 0)))))
                             (leap (abs (- to from))))
                        (list (if (> leap player-join-limit) 1 0) 0 0 1
                              (* leap (if (vector-ref p 1) 1 2)) 0))))))
     (vector-set! best 0
                  (list->vector (map (lambda (s) (cons (own 0 s) #f)) player-shifts)))
     (do ((i 1 (1+ i))) ((= i n))
       (vector-set!
        best i
        (list->vector
         (map (lambda (s)
                (let ((o (own i s)))
                  (let pick ((j 0) (win #f))
                    (if (= j k)
                        win
                        (let* ((a (list-ref player-shifts j))
                               (c (map + (car (vector-ref (vector-ref best (1- i)) j))
                                       (join (vector-ref phrases (1- i)) a
                                             (vector-ref phrases i) s)
                                       o)))
                          (pick (1+ j)
                                (if (or (not win) (player-cost<? c (car win)))
                                    (cons c j) win)))))))
              player-shifts))))
     ;; walk back from the cheapest last choice
     (let* ((last-row (vector-ref best (1- n)))
            (choice (make-vector n 0)))
       (let back ((i (1- n))
                  (j (let pick ((j 1) (w 0))
                       (cond ((= j k) w)
                             ((player-cost<? (car (vector-ref last-row j))
                                             (car (vector-ref last-row w)))
                              (pick (1+ j) j))
                             (else (pick (1+ j) w))))))
         (if (>= i 0)
             (begin
               (vector-set! choice i j)
               (back (1- i) (or (cdr (vector-ref (vector-ref best i) j)) 0)))))
       choice)))

#(define (player-fit-line! line)
   "Choose and apply one octave shift per phrase of LINE. A repeat or
sequence is asked to take its first phrase's shift; that first phrase's
own choice can move once the repeats weigh in, so this runs again, with
the new targets, until they hold still (at most 4 rounds)."
   (let* ((phrases (list->vector (player-phrases line)))
          (n (vector-length phrases)))
     (if (> n 0)
         (let* ((leaders (player-leaders phrases))
                (choice
                 (let round ((r 0) (targets (make-vector n #f)))
                   (let* ((c (player-choose phrases leaders targets))
                          (next (make-vector n #f)))
                     (for-each (lambda (i)
                                 (let ((l (vector-ref leaders i)))
                                   (if (and l (not (= l i)))
                                       (vector-set! next l
                                                    (list-ref player-shifts (vector-ref c l))))))
                               (iota n))
                     (if (or (equal? next targets) (= r 3))
                         c
                         (round (1+ r) next))))))
           (do ((i 0 (1+ i))) ((= i n))
             (let ((s (list-ref player-shifts (vector-ref choice i))))
               (if (not (zero? s))
                   (for-each
                    (lambda (g)
                      (for-each
                       (lambda (note)
                         (ly:music-set-property!
                          note 'pitch
                          (ly:pitch-transpose (ly:music-property note 'pitch)
                                              (ly:make-pitch (/ s 12) 0 0))))
                       g))
                    (vector-ref (vector-ref phrases i) 0)))))))))

mellophonePart =
#(define-music-function (music) (ly:music?)
   "The profile's part: MUSIC written for F mellophone, chords reduced to
their top note, each phrase in the player's range."
   (let ((m #{ \transpose f c' $music #}))
     ;; q and bare durations would otherwise only be expanded after this
     (expand-repeat-notes!
      (expand-repeat-chords!
       (cons 'rhythmic-event (ly:parser-lookup '$chord-repeat-events)) m))
     (player-top-notes! m)
     (for-each player-fit-line! (player-lines m))
     m))

%% ---------------------------------------------------------------- report

#(define player-log-file (string-append (ly:parser-output-name) "-layout.txt"))
#(define player-log-port #f)
#(define (player-log . fields)
   (if (not player-log-port)
       (set! player-log-port (open-output-file player-log-file)))
   (display (string-join (map (lambda (f) (format #f "~a" f)) fields) "\t")
            player-log-port)
   (newline player-log-port)
   (force-output player-log-port))

% StaffSymbol -> song, filled by Player_layout_engraver's staff half
#(define player-staff-song (make-hash-table))

#(define (player-staff-systems grob)
   "Log a staff's system count and staff height, once, from its first piece."
   (let* ((orig (ly:grob-original grob))
          (pieces (if (ly:spanner? orig) (ly:spanner-broken-into orig) '())))
     (if (or (null? pieces) (eq? grob (car pieces)))
         (player-log "system"
                     (hashq-ref player-staff-song orig "?")
                     (max 1 (length pieces))
                     (let ((layout (ly:grob-layout grob)))
                       ;; staff-space units -> mm -> pt, to 0.01pt
                       (/ (round (* 100 4 (ly:grob-property grob 'staff-space 1)
                                    (ly:output-def-lookup layout 'output-scale)
                                    (/ 72.27 25.4)))
                          100.0))))))

%% ---------------------------------------------------------------- layout

% Staff half: names the staff's song (for the report) and counts onsets
% into player-onsets, once per moment with a note on the staff.
#(define player-onsets 0)

#(define (Player_staff_engraver context)
   (let ((counted #f) (symbol #f) (song #f))
     (make-engraver
      ((start-translation-timestep engraver) (set! counted #f))
      (listeners
       ((note-event engraver event)
        (if (not song)
            (let* ((origin (ly:event-property event 'origin #f))
                   (file (if (ly:input-location? origin)
                             (car (ly:input-file-line-char-column origin)) "?"))
                   (base (basename file)))
              (set! song (if (string-suffix? ".ly" base)
                             (substring base 0 (- (string-length base) 3))
                             base))))
        (if (not counted)
            (begin (set! counted #t) (set! player-onsets (1+ player-onsets))))))
      (acknowledgers
       ((staff-symbol-interface engraver grob source)
        (set! symbol grob)))
      ((finalize engraver)
       (if symbol (hashq-set! player-staff-song symbol (or song "?")))))))

% Score half: one record per bar start, line and page breaks set in
% finalize, once the whole song is known.
#(define (player-event-song event)
   (let* ((origin (ly:event-property event 'origin #f))
          (file (if (ly:input-location? origin)
                    (car (ly:input-file-line-char-column origin)) "?"))
          (base (basename file)))
     ;; a song's notes are in <song>.ly; chords/<song>.ily's are not its
     (and (string-suffix? ".ly" base)
          (substring base 0 (- (string-length base) 3)))))

% The cards for a song of S systems: the fewest that hold them (the first
% card holds player-card-systems-first, each after it player-card-systems),
% and before each card's first system a page break chosen in turn: of the
% system starts that still leave every card within its capacity, the one
% at a rehearsal mark, else one at a rest, else any; ties go to the one
% nearest an even split of what is left. KIND is a procedure: system ->
% 0 (mark), 1 (rest), 2 (neither). Returns the systems that start a card,
% after the first.
#(define (player-card-breaks S kind)
   (let* ((first player-card-systems-first)
          (more player-card-systems)
          (cards (if (<= S first) 1 (+ 1 (ceiling (/ (- S first) more))))))
     (let loop ((j 1) (prev 0) (acc '()))
       (if (>= j cards)
           (reverse acc)
           (let* ((cap (if (= j 1) first more))
                  (lo (max (1+ prev) (- S (* more (- cards j)))))
                  (hi (min (+ prev cap) (1- S)))
                  (target (+ prev (/ (- S prev) (- cards j -1))))
                  (better? (lambda (a b)
                             (or (< (kind a) (kind b))
                                 (and (= (kind a) (kind b))
                                      (< (abs (- a target)) (abs (- b target)))))))
                  (best (let pick ((b lo) (best #f))
                          (if (> b hi) best
                              (pick (1+ b) (if (or (not best) (better? b best)) b best))))))
             (loop (1+ j) best (cons best acc)))))))

#(define (Player_layout_engraver context)
   (let ((bars '())        ; newest first: #(column start-moment onsets-before mark? rest?)
         (mark #f)
         (rest-now #f)     ; a rest starts at this moment, and no note does
         (note-now #f)
         (rest-until #f)   ; where the latest rest heard ends
         (song #f)
         (columns '()))
     (make-engraver
      ((start-translation-timestep engraver)
       (set! mark #f) (set! rest-now #f) (set! note-now #f))
      (listeners
       ((mark-event engraver event) (set! mark #t))
       ((note-event engraver event)
        (set! note-now #t)
        (if (not song) (set! song (player-event-song event))))
       ((rest-event engraver event)
        (set! rest-now #t)
        (set! rest-until (+ (ly:moment-main (ly:context-current-moment context))
                            (ly:moment-main (ly:duration-length
                                             (ly:event-property event 'duration))))))
       ((multi-measure-rest-event engraver event)
        (set! rest-now #t)
        (set! rest-until (+ (ly:moment-main (ly:context-current-moment context))
                            (ly:moment-main (ly:duration-length
                                             (ly:event-property event 'duration)))))))
      ((process-music engraver)
       (let* ((col (ly:context-property context 'currentCommandColumn #f))
              (pos (ly:context-property context 'measurePosition (ly:make-moment 0)))
              (now (ly:context-current-moment context))
              ;; a breath before this moment: a rest ends here, or one
              ;; starts here with no note beside it
              (rest (or (and rest-until (equal? rest-until (ly:moment-main now)))
                        (and rest-now (not note-now)))))
         (if col (set! columns (cons col columns)))
         ;; a bar starts at its first moment, grace notes before the
         ;; downbeat included (a mark or a break goes before them)
         (if (and col (zero? (ly:moment-main pos))
                  (not (and (pair? bars)
                            (equal? (ly:moment-main now)
                                    (ly:moment-main (vector-ref (car bars) 1))))))
             (set! bars (cons (vector col now player-onsets mark rest) bars)))
         (if (and (pair? bars)
                  (equal? (ly:moment-main now) (ly:moment-main (vector-ref (car bars) 1))))
             (begin
               (if mark (vector-set! (car bars) 3 #t))
               (if rest (vector-set! (car bars) 4 #t))))))
      ((finalize engraver)
       (if player-layout-on
       (let* ((bars (list->vector (reverse bars)))
              (n (vector-length bars))
              (end (ly:moment-main (ly:context-current-moment context)))
              (cost (lambda (i)
                      (let* ((start (ly:moment-main (vector-ref (vector-ref bars i) 1)))
                             (stop (if (< (1+ i) n)
                                       (ly:moment-main (vector-ref (vector-ref bars (1+ i)) 1))
                                       end))
                             (onsets (- (if (< (1+ i) n)
                                            (vector-ref (vector-ref bars (1+ i)) 2)
                                            player-onsets)
                                        (vector-ref (vector-ref bars i) 2))))
                        (max (min (- stop start) 1) (/ onsets 8)))))
              (starts '()))
         ;; greedy systems: bar i starts a system when the current one is full
         ;; or a mark starts here, and the current one has player-min-bars
         (let loop ((i 1) (used (if (> n 0) (cost 0) 0)) (count 1))
           (if (< i n)
               (let ((c (cost i))
                     (enough (>= count player-min-bars))
                     (left (- n i)))
                 (if (and enough
                          (>= left player-min-bars)
                          (or (vector-ref (vector-ref bars i) 3)
                              (> (+ used c) player-system-budget)))
                     (begin (set! starts (cons i starts)) (loop (1+ i) c 1))
                     (loop (1+ i) (+ used c) (1+ count))))))
         (set! starts (reverse starts))
         ;; every column but the score's first and last: no break unless set
         (for-each (lambda (col)
                     (ly:grob-set-property! col 'line-break-permission '())
                     (ly:grob-set-property! col 'page-break-permission '()))
                   (if (> (length columns) 2) (cdr (reverse (cdr columns))) '()))
         (for-each (lambda (i)
                     (ly:grob-set-property! (vector-ref (vector-ref bars i) 0)
                                            'line-break-permission 'force))
                   starts)
         ;; the cards: page breaks only where player-card-breaks puts them
         (let* ((sys (list->vector (cons 0 starts)))
                (bar (lambda (k) (vector-ref bars (vector-ref sys k))))
                (kind (lambda (k) (cond ((vector-ref (bar k) 3) 0)
                                        ((vector-ref (bar k) 4) 1)
                                        (else 2)))))
           (if (> n 0)
               (for-each
                (lambda (k card)
                  (ly:grob-set-property! (vector-ref (bar k) 0)
                                         'page-break-permission 'force)
                  ;; page <TAB> song <TAB> card <TAB> its first system (from 1)
                  ;; <TAB> of systems <TAB> its first bar (from 1) <TAB>
                  ;; mark|rest|none
                  (player-log "page" (or song "?") card (1+ k) (vector-length sys)
                              (1+ (vector-ref sys k))
                              (list-ref '(mark rest none) (kind k))))
                (player-card-breaks (vector-length sys) kind)
                (iota (length (player-card-breaks (vector-length sys) kind)) 2))))))))))

#(define (player-fingering-direction grob) UP)

\layout {
  \context {
    \Score
    \consists #Player_layout_engraver
  }
  \context {
    \Staff
    \consists #Player_staff_engraver
    \override StaffSymbol.after-line-breaking = #player-staff-systems
  }
}
