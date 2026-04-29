%%%
%%% Acyclicity constraints of BMS (transitivity version)
%%% Time-stamp: <2025-12-08 14:11:10 banbara>
%%%

% Enforce acyclicity of references. (BMS5)
% Transitive closure must not contain a cycle.
closure(X,Y) :- r(X,Y).
closure(X,Z) :- r(Y,Z), closure(X,Y).
:- closure(X,Y), closure(Y,X).

