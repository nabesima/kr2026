%%%
%%% Acyclicity constraints of BMS (order encoding version)
%%% Time-stamp: <2025-12-08 14:57:33 banbara>
%%%
%%% This encoding is based on 
%%% http://www.aaai.org/ocs/index.php/KR/KR14/paper/view/8025
%%% 

% Enforce acyclicity of references. (BMS5)
node(X) :- X=1..textlength.
pair(I,J) :- t(I,C), t(J,C), I != J, node(I), node(J).
order(X,Y) :- pair(X,Y), not r(X,Y).
order(X,Y) :- pair(X,Y), order(Y).
order(X) :- node(X), order(X,Y) : pair(X,Y).
:- node(X), not order(X).

