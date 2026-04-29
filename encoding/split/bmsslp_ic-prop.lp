%%%
%%% Interval constraint propagator of SLP
%%% Time-stamp: <2026-02-21 16:41:43 banbara>
%%%

#script (python)
# clingo の Propagator とは，
#   - ASP の grounding 後に，探索（SAT/CDNL）過程に介入できる拡張機構
# です．
#
# 具体的には，
#   - init() で監視対象（watch）を登録する
#   - propagate(control, changes) で，割当が変化した literal を受け取り，
#     必要なら nogood（禁止節）を追加し，伝播を進める
#   - undo() でバックトラックに合わせて内部状態を巻き戻す
#   - check() で全割当の最終チェックを行う
# という流れで使います．
#
# ここでは q(I,L) を watch し，
#   q が True になった瞬間に，既存の True な q と交差していないかを調べ，
#   交差していれば「両方 True を禁止する nogood」を追加して排除します．

import sys
from dataclasses import dataclass
from typing import Dict, List, Tuple, Optional

from clingo.application import Application, clingo_main

@dataclass(frozen=True)
class Interval:
    # q(I,L) に対応する参照区間 [I, I+L) を表す．
    i: int
    l: int
    @property
    def j(self) -> int:
        return self.i + self.l  # end (exclusive)

def violates_slp7(a: Interval, b: Interval) -> bool:
    # SLP7 の交差条件（a が左，b が右と仮定）を判定する．
    #
    # SLP7（元の ASP 制約）:
    #   :- q(I,L), q(J,M), I < J, J < I+L, I+L < J+M.
    #
    # ここでは a=(I,L), b=(J,M) を仮定し，
    #   a.i < b.i < a.j < b.j
    # のとき True を返す．
    return (a.i < b.i) and (b.i < a.j) and (a.j < b.j)

class SLP7Propagator:
    """
    この Propagator の方針:
      - watch: q(I,L) の solver literal を監視対象にする
      - q(I,L) が True になったものだけを「active」として保持する
      - 新しく True になった q が既存の active と交差するなら，
        その 2 つが同時に True になることを禁止する nogood（[lit, lit2]）を追加する

    nogood [lit, lit2] の意味:
      lit=True かつ lit2=True を同時に満たす割当を禁止する（つまり両立不可）．
    """

    def __init__(self):
        # lit -> Interval の対応表（solver literal をキーにする）
        self._lit2int: Dict[int, Interval] = {}
        # thread_id ごとの状態（-t で並列探索できるため）
        self._active: List[Dict[int, Interval]] = []   # lit -> Interval（true のみ）
        self._trail:  List[List[Tuple[int,int]]] = []  # (level, lit) の履歴（backtrack 用）

    def init(self, init):
        # init は grounding 後に 1 回だけ呼ばれる初期化フック．
        # ここで
        #   - thread ごとの辞書を初期化し，
        #   - q/2 を列挙して watch 登録する．
        self._active = [dict() for _ in range(init.number_of_threads)]
        self._trail  = [[] for _ in range(init.number_of_threads)]

        # q/2 を列挙して watch
        # symbolic_atoms.by_signature("q",2) で grounded な q(I,L) を走査できる．
        for atm in init.symbolic_atoms.by_signature("q", 2):
            sym = atm.symbol
            i = sym.arguments[0].number
            l = sym.arguments[1].number
            # atm.literal は program literal（内部表現）．
            # Propagator の propagate() で来るのは solver literal なので，
            # init.solver_literal(...) で変換しておく．
            lit = atm.literal          # program literal
            slit = init.solver_literal(lit)  # solver literal
            self._lit2int[slit] = Interval(i, l)
            init.add_watch(slit)

    def propagate(self, control, changes):
        # propagate は watch している solver literal の割当が変化したときに呼ばれる．
        # changes には変化した literal が列挙される．
        #
        # ここでは「True になった q(I,L)」だけを扱い，
        # それが既存 active と交差するなら nogood を追加する．
        tid = control.thread_id
        assign = control.assignment
        level = assign.decision_level

        active = self._active[tid]
        trail  = self._trail[tid]

        for lit in changes:
            # watched lit が true になったときだけ扱う
            if assign.value(lit) != True:
                continue

            # q(I,L) に対応する区間を取り出す
            itv = self._lit2int.get(lit)
            if itv is None:
                continue

            # 多重呼び出し対策（同じ lit が複数回 changes に来るケースに備える）
            if lit in active:
                continue

            # 既存の true 区間との SLP7 違反検出
            # 2区間の順序は両方向あり得るので両向きでチェック
            for lit2, itv2 in active.items():
                if violates_slp7(itv2, itv) or violates_slp7(itv, itv2):
                    # 両方 true を禁止する nogood を追加
                    # (lit, lit2) が同時に true なら矛盾，という節
                    if control.add_nogood([lit, lit2]):
                        control.propagate()
                    return

            # 問題なければ active に登録し，trail に記録する
            active[lit] = itv
            trail.append((level, lit))

    def undo(self, thread_id, assignment, changes):
        # undo はバックトラック（backjump）時に呼ばれる．
        # changes は「unassigned（未割当）に戻った watched literal」の列．
        #
        # 最小構成としては，
        #   - active から該当 lit を削除する
        # だけでも整合が取れる（SLP7 は True になった区間のみを見るため）．
        active = self._active[thread_id]
        # changes は「unassigned になった watched lit」の列
        for lit in changes:
            if lit in active:
                del active[lit]

        # trail は厳密には decision level で切り詰めるのが筋だが，
        # active を changes で同期できていれば最小構成としては十分．
        # きれいにするなら assignment.decision_level を参照して trail も pop する．

    def check(self, control):
        # check は全割当（モデル候補）時の最終確認用．
        # propagate だけで足りることが多いが，
        # 念のため active 同士を総当たりで見て交差が残っていないかを確認する．
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
