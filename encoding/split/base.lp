%%%
%%% Base encodng of finding smallest BMS
%%% Time-stamp: <2025-12-08 14:02:48 banbara>
%%%

% Guess ground phrases.
{ p(1..textlength) }.

% Guess phrase references. (BMS1)
% r(I,J) means that position I refers to J (i.e. J is the parent node of I)
{ r(I,J) ; r(J,I) } 1 :- t(I,C), t(J,C), I < J, J <= textlength.

% Each node has at most one reference. (BMS2)
:- not { r(I,_) } 1, I=1..textlength.

% If T[i] has no reference, then a ground phrase must start at T[i]. (BMS3)
:- not p(I), 0 { r(I,_) } 0, I=1..textlength.

% If the previous reference cannot be merged with the reference of T[i], a phrase must start at T[i]. (BMS4)
:- not p(I), r(I,J), not r(I-1,J-1).

% objective function (MINP)
#minimize { 1,I : p(I) }.

