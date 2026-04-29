#!/usr/bin/env python3.8

import argparse
import multiprocessing
import os
import time
import signal
import sys
import threading
from pysat.formula import WCNF, WCNFPlus
from pysat.examples.fm import FM
from pysat.examples.lsu import LSU, LSUPlus
from pysat.examples.rc2 import RC2, RC2Stratified

# 行バッファリングを無効にする
sys.stdout = os.fdopen(sys.stdout.fileno(), 'w', buffering=1)

def signal_handler(signum, frame):
    print(f"c Caught signal {signum}, terminating...")
    sys.exit(1)

signal.signal(signal.SIGTERM, signal_handler)
signal.signal(signal.SIGINT, signal_handler)

def worker(file_path, strategy, sat_solver, result_dict):
    if strategy != "lsu+":
        cnf = WCNF(from_file=file_path)
    else:
        cnf = WCNFPlus(from_file=file_path)

    solver = None
    solution = None

    try:
        if strategy == "fm":
            solver = FM(cnf, solver=sat_solver, verbose=2)
            solution = solver.compute()
        elif strategy == "lsu":
            solver = LSU(cnf, solver=sat_solver, verbose=2)
            solution = solver.solve()
        elif strategy == "lsu+":
            solver = LSUPlus(cnf, solver=sat_solver, verbose=2)
            solution = solver.solve()
        elif strategy == "rc2":
            solver = RC2(cnf, solver=sat_solver, verbose=2)

            def monitor():
                while True:
                    time.sleep(1)
                    result_dict["lower_bound"] = solver.cost

            monitor_thread = threading.Thread(target=monitor, daemon=True)
            monitor_thread.start()

            solution = solver.compute()
            monitor_thread.join(timeout=0)
        elif strategy == "rc2s":
            solver = RC2Stratified(cnf, solver=sat_solver, verbose=2)
            solution = solver.compute()

        if solution:
            result_dict["cost"] = solver.cost
            result_dict["lower_bound"] = solver.cost
            result_dict["upper_bound"] = solver.cost
            result_dict["status"] = "done"
        else:
            result_dict["status"] = "unsat"
            if hasattr(solver, "cost"):
                if strategy in ["rc2", "rc2s", "fm"]:
                    result_dict["lower_bound"] = solver.cost
                else:
                    result_dict["upper_bound"] = solver.cost

    except Exception as e:
        print(f"c Exception in worker: {e}")
        result_dict["status"] = "error"
        if solver and hasattr(solver, "cost"):
            if strategy in ["rc2", "rc2s", "fm"]:
                result_dict["lower_bound"] = solver.cost
            else:
                result_dict["upper_bound"] = solver.cost

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Solve a MaxSAT problem using PySAT with optional timeout.")
    parser.add_argument(
        "file",
        type=str,
        help="Path to the .wcnf.gz file containing the MaxSAT problem."
    )
    parser.add_argument(
        "-s", "--solver",
        type=str,
        choices=['cd', 'cd15', 'cd19', 'cms', 'gc3', 'gc4', 'g3', 'g4', 'g42', 'lgl', 'mcb', 'mcm', 'mpl', 'mg3', 'mc', 'm22', 'mgh'],
        default="g4",
        help="SAT solver to use (default: g4)."
    )
    parser.add_argument(
        "--strategy",
        type=str,
        choices=["fm", "lsu", "lsu+", "rc2", "rc2s"],
        default="rc2",
        help="Strategy to use for solving."
    )
    parser.add_argument(
        "-t", "--timeout",
        type=int,
        default=None,
        help="Maximum solving time in seconds (default: unlimited)."
    )

    args = parser.parse_args()

    print("c Received arguments:")
    print(f"c   File: {args.file}")
    print(f"c   Solver: {args.solver}")
    print(f"c   Strategy: {args.strategy}")
    print(f"c   Timeout: {args.timeout if args.timeout is not None else 'unlimited'} seconds")

    start = time.time()
    manager = multiprocessing.Manager()
    result = manager.dict()

    p = multiprocessing.Process(target=worker, args=(args.file, args.strategy, args.solver, result))
    p.start()
    p.join(args.timeout)

    if p.is_alive():
        print(f"c Timeout reached ({args.timeout} sec). Terminating solver...")
        p.terminate()
        p.join()
        result["status"] = "timeout"

    end = time.time()

    print(f"c Time taken: {end - start:.2f} seconds")

    if result.get("status") == "done" and "cost" in result:
        print(f"o {result['cost']}")

    lb = result.get("lower_bound", "*")
    ub = result.get("upper_bound", "*")
    print(f"c Bounds: [{lb}, {ub}]")

    status = result.get("status")
    if status == "done":
        print("s OPTIMUM FOUND")
    elif status == "unsat":
        print("s UNSATISFIABLE")
    else:
        print("s UNKNOWN")
