\version "2.24.3"

% This style sheet contains general formatting for brass band charts. It
% consists of various functions I've defined to express notation and 
% instructions commonly found in New Orleans street band charts which 
% I've transcribed into LilyPond.
%
% To-do:
% * separate out scheme function definitions into a separate file
% * use overrides for vanilla LilyPond functions when possible to avoid
%   having to use function calls i.e. use standard LilyPond syntax 
%   wherever possible

\pointAndClickOff

\header {
  tagline = ""
}

% DEFINITIONS

% This MarkLine context is used to create a line at the top of the score 
% containing instructions that should only be printed once. This 
% workaround is necessary mostly because \textMark events would 
% otherwise be printed on each staff
% \layout {
%   \context {
%     \name "MarkLine"
%     \type "Engraver_group"
%     \consists Output_property_engraver
%     \consists Axis_group_engraver
%     \consists Mark_engraver
%     \consists Text_mark_engraver
%     \consists Metronome_mark_engraver
%     \consists Staff_collecting_engraver
%     \consists Chord_name_engraver
%     \override RehearsalMark.extra-spacing-width = #'(0 . 1)
%     \override MetronomeMark.extra-spacing-width = #'(0.5 . 0)
%     \override VerticalAxisGroup.minimum-Y-extent = #'(-2 . 2)
%     \override VerticalAxisGroup.staff-staff-spacing =
%     #'((basic-distance . 1)
%        (minimum-distance . 1)
%        (padding . 1)
%        (stretchability . 3))
%   }
%   \context {
%     \Score
%     \remove Mark_engraver
%     \remove Text_mark_engraver
%     \remove Metronome_mark_engraver
%     \remove Staff_collecting_engraver
%     \accepts MarkLine

%     \numericTimeSignature
%     % rehearsalMarkFormatter = #format-mark-padded-box-letters
%   }
% }

% This is the styling for rehearsal marks in boxes
% #(define (format-mark-padded-box-letters mark context)
%  (make-bold-markup
%    #{ \markup % \with-color #highlightColor
%      #(make-box-markup
%        (make-pad-markup-markup 0.5
%          (markup #:with-color black
%           (make-markletter-markup
%            mark)))) #} ))

% padded-box markup command
#(define-markup-command (padded-box layout props text) (markup?)
  #:properties ((box-padding 0.5))
  "Draw a padded box around text."
  (interpret-markup layout props
    #{\markup \override #`(box-padding . ,box-padding) \box
               { \bold #text } #}))

% unfoldToChart meant to be a way of compressing repeats for brevity in
% parts while having a verbose full score. Never really developed this
% and I don't use it ever
unfoldToChart = #(define-music-function
  (m) (ly:music?)
  (make-music
    'UnfoldedRepeatedMusic
    'elements
    '()
    'repeat-count
    (ly:music-property m 'repeat-count)
    'element
    (ly:music-property m 'element)))

% Used to make score proportionally formatted, I think
makePercent =
#(define-music-function (note) (ly:music?)
   "Make a percent repeat the same length as NOTE."
   (make-music 'PercentEvent
               'length (ly:music-length note)))

\defineBarLine "||-.|:" #'("||" ".|:" ".|:")
\defineBarLine "|.-.|:" #'("|." ".|:" ".|:")

% Mandatory Layout Variables
% Could be handled much better than having these variables outside the
% functions. Need to learn more about default settings in scheme
% or perhaps using context properties.
cue-pad = #0.5
cue-offset = #-8
label-pad = #2

% Special formatting for numbers at end of lines
numRepeats = #(define-scheme-function
  (arg)(markup?)
  #{
    % \tweak direction #DOWN
    % \tweak Y-offset #cue-offset
    \textEndMark
    \markup { #arg }
  #})

% This might be redundant with padded-box from above
cueBox = #(define-scheme-function
  (arg)(markup?)
  #{
    \tweak direction #DOWN
    \tweak Y-offset #cue-offset
    \textEndMark
    \markup \fill-line {
      \box \pad-markup #cue-pad \column { 
        \line { \small #arg }
      }
    }
  #})

% Creates a custom kind of textMark with tweaks
lineNote =
  #(define-scheme-function
       (arg)
       (markup?)
      #{ 
        \tweak padding #0
        \tweak X-offset #2
        \textMark 
        \markup \pad-markup #0.5 { \italic \small #arg } #})

% Creates a custom kind of textMark with tweaks
lineLabel =
  #(define-scheme-function
       (arg)
       (markup?)
      #{ 
        \tweak padding #0
        \tweak X-offset #-2
        \textMark 
        \markup \pad-markup #1 { #arg } #})
  