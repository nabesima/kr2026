%%%
%%% Acyclicity constraints of BMS (reachability version)
%%% Time-stamp: <2025-12-08 14:11:17 banbara>
%%%

% Enforce acyclicity of references. (BMS5)
% All nodes have out-degree one pointing to their roots who have self-loops, check that we can reach the root from each node.
reachable(I,I) :- 0 { r(I,_) } 0, I=1..textlength.
reachable(X,R) :- r(X,Y), reachable(Y,R).
:- p(I), not 1 { reachable(I,_) } 1.

