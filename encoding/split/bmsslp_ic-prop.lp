%%%
%%% Interval constraint propagator of SLP
%%% Time-stamp: <2026-02-21 16:41:43 banbara>
%%%

#script (python)
# A Propagator in clingo is
#   an extension mechanism that can intervene in the search (SAT/CDNL) process
#   after ASP grounding.
#
# Specifically, the workflow is as follows:
#   - init() registers the literals to watch
#   - propagate(control, changes) receives literals whose assignments have changed,
#     and if necessary, adds nogoods (forbidden clauses) to advance propagation
#   - undo() rolls back the internal state on backtracking
#   - check() performs a final check on a complete assignment
#
# Here, we watch q(I,L), and the moment q becomes True,
#   we check whether it overlaps with any existing True q,
#   and if so, add a nogood forbidding both from being True simultaneously.

import sys
from dataclasses import dataclass
from typing import Dict, List, Tuple, Optional

from clingo.application import Application, clingo_main

@dataclass(frozen=True)
class Interval:
    # Represents the reference interval [I, I+L) corresponding to q(I,L).
    i: int
    l: int
    @property
    def j(self) -> int:
        return self.i + self.l  # end (exclusive)

def violates_slp7(a: Interval, b: Interval) -> bool:
    # Checks the overlap condition of SLP7 (assuming a is on the left, b is on the right).
    #
    # SLP7 (the original ASP constraint):
    #   :- q(I,L), q(J,M), I < J, J < I+L, I+L < J+M.
    #
    # Assuming a=(I,L) and b=(J,M), returns True when
    #   a.i < b.i < a.j < b.j.
    return (a.i < b.i) and (b.i < a.j) and (a.j < b.j)

class SLP7Propagator:
    """
    Strategy of this Propagator:
      - watch: monitor the solver literals of q(I,L)
      - keep only those q(I,L) that are True as "active"
      - if a newly True q overlaps with an existing active one,
        add a nogood ([lit, lit2]) forbidding the two from being True simultaneously

    Meaning of nogood [lit, lit2]:
      Forbids any assignment where both lit=True and lit2=True hold (i.e., they are mutually exclusive).
    """

    def __init__(self):
        # Lookup table from solver literal to Interval
        self._lit2int: Dict[int, Interval] = {}
        # Per-thread state (to support parallel search with -t)
        self._active: List[Dict[int, Interval]] = []   # lit -> Interval (only true ones)
        self._trail:  List[List[Tuple[int,int]]] = []  # history of (level, lit) for backtracking

    def init(self, init):
        # init is an initialization hook called once after grounding.
        # Here we
        #   - initialize per-thread dictionaries, and
        #   - enumerate q/2 and register watches.
        self._active = [dict() for _ in range(init.number_of_threads)]
        self._trail  = [[] for _ in range(init.number_of_threads)]

        # Enumerate q/2 and register watches.
        # symbolic_atoms.by_signature("q",2) iterates over all grounded q(I,L).
        for atm in init.symbolic_atoms.by_signature("q", 2):
            sym = atm.symbol
            i = sym.arguments[0].number
            l = sym.arguments[1].number
            # atm.literal is the program literal (internal representation).
            # Since propagate() receives solver literals,
            # we convert it using init.solver_literal(...) here.
            lit = atm.literal          # program literal
            slit = init.solver_literal(lit)  # solver literal
            self._lit2int[slit] = Interval(i, l)
            init.add_watch(slit)

    def propagate(self, control, changes):
        # propagate is called when the assignment of a watched solver literal changes.
        # changes lists the literals whose assignments have changed.
        #
        # Here we handle only q(I,L) that have become True,
        # and add a nogood if they overlap with any existing active interval.
        tid = control.thread_id
        assign = control.assignment
        level = assign.decision_level

        active = self._active[tid]
        trail  = self._trail[tid]

        for lit in changes:
            # Process only when the watched literal becomes true
            if assign.value(lit) != True:
                continue

            # Retrieve the interval corresponding to q(I,L)
            itv = self._lit2int.get(lit)
            if itv is None:
                continue

            # Guard against duplicate calls (in case the same lit appears multiple times in changes)
            if lit in active:
                continue

            # Detect SLP7 violation against existing true intervals.
            # Both orderings of the two intervals are possible, so check both directions.
            for lit2, itv2 in active.items():
                if violates_slp7(itv2, itv) or violates_slp7(itv, itv2):
                    # Add a nogood forbidding both from being true simultaneously
                    # (a clause stating that lit and lit2 cannot both be true)
                    if control.add_nogood([lit, lit2]):
                        control.propagate()
                    return

            # If no violation, register in active and record in trail
            active[lit] = itv
            trail.append((level, lit))

    def undo(self, thread_id, assignment, changes):
        # undo is called on backtracking (backjump).
        # changes is the list of watched literals that have become unassigned.
        #
        # As a minimal implementation,
        #   - removing the relevant lit from active
        # is sufficient for consistency (since SLP7 only examines True intervals).
        active = self._active[thread_id]
        # changes is the list of watched lits that became unassigned
        for lit in changes:
            if lit in active:
                del active[lit]

        # Strictly, the trail should be trimmed by decision level,
        # but as long as active is kept in sync via changes, this minimal form suffices.
        # For a cleaner implementation, pop the trail by referencing assignment.decision_level.

    def check(self, control):
        # check is used for final verification on a complete assignment (model candidate).
        # propagate alone is usually sufficient,
        # but we brute-force all pairs of active intervals as a safety check for any remaining overlaps.
        tid = control.thread_id
        active = list(self._active[tid].items())
        for idx in range(len(active)):
            lit1, itv1 = active[idx]
            for lit2, itv2 in active[idx+1:]:
                if violates_slp7(itv1, itv2) or violates_slp7(itv2, itv1):
                    control.add_nogood([lit1, lit2])
                    control.propagate()
                    return

def main(prg):
    # Register propagator before grounding
    prg.register_propagator(SLP7Propagator())
    prg.ground([("base", [])])
    prg.solve()
#end.
