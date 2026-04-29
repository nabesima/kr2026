# Supplementary Materials for KR 2026 Paper

**"Optimal Dictionary-Based Compression with Answer Set Programming: Encodings and Empirical Analysis"**  
Mutsunori Banbara, Hideo Bannai, Takashi Horiyama, Dominik Köppl, Takuya Mieno, Hideotomo Nabeshima  
*Proceedings of the 23rd International Conference on Principles of Knowledge Representation and Reasoning (KR 2026)*

---

## Repository Structure

```
.
├── encoding/          ASP encodings
├── raw-instances/     Original Calgary Corpus benchmark files
├── asp-instances/     Benchmark instances in ASP fact format
│   ├── 3000/          Instances storing up to 3000 characters
│   └── 10000/         Instances storing up to 10000 characters
├── maxsat-instances/  Scripts for generating and solving MaxSAT instances
├── bin/               MaxSAT solver binaries and wrappers
├── bms-log/           Experiment logs for BMS minimization
└── graphs/            Figures used in the paper (PDF)
```

---

## Encodings (`encoding/`)

ASP encodings for computing smallest Bidirectional Macro Schemes (BMSs) and Straight-Line Programs (SLPs).

### BMS Encodings

| File | Paper Name | Description |
|------|-----------|-------------|
| `ASP-closure.lp`    | closure      | Acyclicity via transitive closure |
| `ASP-reachable.lp`  | reachability | Acyclicity via reachability to ground phrases |
| `ASP-acyclicity.lp` | acyclicity   | Acyclicity via clingo's `#edge` directive |
| `ASP-order.lp`      | order        | Acyclicity via inductive vertex-ordering |

The `split/` subdirectory contains the modular components shared across encodings (`base.lp`, `edge.lp`, `order.lp`, `reachable.lp`, `transitive.lp`).

**Usage example:**
```
clingo encoding/ASP-acyclicity.lp asp-instances/3000/book1.lp -c textlength=100
```

### SLP Encoding

| File | Paper Name | Description |
|------|-----------|-------------|
| `bmsslp3.lp` | bmsslp | ASP encoding for SLP minimization |

### Running Example (`input.lp`)

The instance used for the running example (Figure 1) in the paper. It encodes a string `T` as ASP facts:

```
#const textlength=N.
t(i, c).   % T[i] = c  (character c at position i, as ASCII value)
```

---

## Benchmark Instances

### Raw Calgary Corpus Files (`raw-instances/`)

The 46 original files from the [Calgary Corpus](http://www.data-compression.info/Corpora/CalgaryCorpus/), a standard benchmark set in compression research comprising plain text, source code, manuals, and binary files.

### ASP Instances (`asp-instances/`)

Pre-converted instances in ASP fact format, ready for use with clingo.

- `asp-instances/3000/` — 46 instances (prefixes up to 3000 characters); used in the main BMS experiments (lengths 100, 300, 500, 1000 are controlled via `-c textlength=K`)
- `asp-instances/10000/` — 46 instances (prefixes up to 10000 characters); used in the scalability experiments (Table 4 of the paper)

---

## MaxSAT Instances (`maxsat-instances/`)

MaxSAT instances can be very large (exceeding 10<sup>8</sup> variables for longer inputs) and are therefore not included in this repository. The following scripts are provided instead for generating and solving MaxSAT instances.

| File | Description |
|------|-------------|
| `genwcnf.rb`    | Generates weighted CNF (WCNF) instances from raw inputs |
| `bms_solver.py` | Solves BMS instances via PySAT (source: [koeppl/satcomp](https://github.com/koeppl/satcomp/blob/main/src/bms_solver.py)) |

---

## Solver Binaries (`bin/`)

The MaxCDCL-openwbo and WMaxCDCL-openwbo binaries were downloaded from the [MaxSAT Evaluation 2024](https://maxsat-evaluations.github.io/2024/) and compiled locally.

| File | Description |
|------|-------------|
| `MaxCDCL2024-openwbo`    | MaxCDCL-openwbo binary (MaxSAT Evaluation 2024) |
| `MaxCDCL2024-openwbo.sh` | Wrapper script for MaxCDCL-openwbo |
| `WMaxCDCL2024-openwbo`   | WMaxCDCL-openwbo binary (MaxSAT Evaluation 2024) |
| `WMaxCDCL2024-openwbo.sh`| Wrapper script for WMaxCDCL-openwbo |
| `pysatsolver.py`         | PySAT-based MaxSAT solver script |

---

## Experiment Logs

All logs are gzip-compressed (`.log.gz`). Each log file records the full solver output for a single instance, including the command used, host, date, solving statistics, and the optimal solution (if found).

### BMS Experiment Logs (`bms-log/`)

#### Main Experiments (Table 1)

Directory naming convention: `{length}-{id}-{type}-{solver}/`

- `{length}`: input text length (100, 300, 500, or 1000)
- `{id}`: two-digit experiment identifier
- `{type}`: `ASP` or `MaxSAT`
- `{solver}`: solver/encoding name

| Directory suffix | Paper Name | Type | Instances |
|-----------------|-----------|------|-----------|
| `ASP-closure`          | closure      | ASP    | 46 |
| `ASP-reachability`     | reachability | ASP    | 46 |
| `ASP-acyclicity`       | acyclicity   | ASP    | 46 |
| `ASP-order`            | order        | ASP    | 46 |
| `MaxSAT-MaxCDCL-openwbo`  | MaxCDCL-openwbo  | MaxSAT | 46 / 42 / 33 / 26 |
| `MaxSAT-WMaxCDCL-openwbo` | WMaxCDCL-openwbo | MaxSAT | 46 / 42 / 33 / 26 |
| `MaxSAT-PySAT-g42`        | PySAT-g42        | MaxSAT | 46 / 42 / 33 / 26 |
| `MaxSAT-PySAT-mgh`        | PySAT-mgh        | MaxSAT | 46 / 42 / 33 / 26 |

MaxSAT instance counts vary by length (100 / 300 / 500 / 1000) because instances exceeding 10<sup>8</sup> variables were excluded from encoding.

Log files for ASP experiments are in `{dir}/bms3000/` (one `.log.gz` per instance).  
Log files for MaxSAT experiments are in `{dir}/bms/{length}/` (one `.log.gz` per instance).

#### Scalability Experiments (Table 4)

Directory naming convention: `{length}-ASP-{encoding}/`

- `{length}`: input text length (2000, 3000, 4000, 5000, 6000, 7000, 8000, or 10000)
- `{encoding}`: `acyclicity` or `order`

Each directory contains logs for 12 representative instances. Logs at lengths 8000 and 10000 confirm that no instance could be solved within the time limit at those lengths.

Log files are in `{dir}/bms3000/` for lengths 2000 and 3000, and in `{dir}/bms10000/` for lengths 4000 and above (one `.log.gz` per instance).

---

## Figures (`graphs/`)

PDF figures included in the paper.

| File | Figure |
|------|--------|
| `fig-bms-cactus-{100,300,500,1000}.pdf` | Cactus plots of BMS solving times by input length |
| `fig-bms-constraints-all.pdf`           | Cactus plot of number of constraints across all BMS instances |
| `fig-bms-variables-all.pdf`             | Cactus plot of number of variables across all BMS instances |
| `fig-bms-upset-solver-comparison.pdf`   | UpSet plot of BMS instances solved by each solver group |

---

## Experimental Setup

- **ASP solver**: clingo 5.7.1 (`--configuration=trendy --opt-strategy=usc`)
- **MaxSAT solvers**: MaxCDCL-openwbo, WMaxCDCL-openwbo (MaxSAT Evaluation 2024); [PySAT](https://pysathq.github.io/) 1.8.dev13 with RC2 algorithm (Glucose 4.2.1 and [MiniSAT GitHub version](https://github.com/niklasso/minisat)) running on Python 3.8
- **Machine**: Intel Xeon Platinum 8480+, 512 GiB RAM
- **Time limit**: 3600 seconds per instance
