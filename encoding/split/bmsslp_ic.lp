%%%
%%% Interval constraints of SLP
%%% Time-stamp: <2026-02-21 16:37:28 banbara>
%%%

% Interval constraints (disjoint or nested)
:- q(I,L), q(J,M), I < J, J < I+L, I+L < J+M.

