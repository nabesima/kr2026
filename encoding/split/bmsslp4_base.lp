%%%
%%% Base encodng of finding smallest SLP (version 4)
%%% Time-stamp: <2026-02-21 17:22:06 banbara>
%%%

%%%%%% BMS part

% Guess starting position of phrase
{ p(1..textlength) }.

% Guess phrase references. (restricted)
{ r(J,I) } 1 :- t(I,C), t(J,C), I < J, J <= textlength.

% Reference uniqueness
:- not { r(I,_) } 1, I=1..textlength.

% Ground phrase
:- not p(I), 0 { r(I,_) } 0, I=1..textlength.

% Phrase boundary
:- not p(I), r(I,J), not r(I-1,J-1).

% Objective function
#minimize { 1,I : p(I), I <= textlength }.

%%%%%% Extension to SLP

p(textlength+1).

% Phrase length
l(I,J-I) :- p(I), p(J), I<J, J <= textlength+1, not p(Z) : Z=I+1..J-1.

% Guess referenced intervals
{ q(J,L) : L=2..textlength+1-J } :- J=1..textlength-1.

% Channeling constraints
:- not q(J,L), r(I,J), l(I,L), L > 1.

% Start and end at phrase boundaries
:- l(J,L), q(J,L).
:- not p(J), q(J,L).
:- not p(J+L), q(J,L).

