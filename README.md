# Project 4: Legal Text to SMT Formalization

**Course**: CPSC 5140 - Law and LLMs
**Legal Text**: 26 U.S. Code § 152 — Dependent Defined
**Team Members**: [Your Name], [Teammate Name]

## Overview

This project translates 26 USC §152 into SMT (Satisfiability Modulo Theories) formalism,
generates compliant/non-compliant scenarios using LLMs, and verifies compliance using the Z3 SMT solver.

## Repository Structure

```
project4/
├── part1/                          # Legal text → SMT translation
│   ├── part1_cot.smt2              # CoT prompting approach
│   ├── part1_json.smt2             # JSON intermediary approach
│   └── transcripts/                # LLM conversation logs
├── part2/                          # Scenario generation
│   ├── scenario_dependent.smt2     # Person IS a dependent
│   ├── scenario_nondependent.smt2  # Person is NOT a dependent
│   └── scenario_borderline.smt2    # Ambiguous/borderline case
├── part3/                          # Z3 compliance verification
│   └── z3_outputs.txt              # Solver outputs
├── part4/                          # Model refinement notes
│   └── refinement_notes.md
├── partB/                          # LLM vs SMT divergence analysis
│   ├── scenario_partB.txt
│   └── analysis.md
└── report/
    └── report.md                   # Final report
```

## Approach

| | Person 1 | Person 2 |
|---|---|---|
| **Technique** | Chain-of-Thought (CoT) prompting | Structured JSON intermediary |
| **Part 1 output** | `part1_cot.smt2` | `part1_json.smt2` |

## Running the SMT Solver

Install Z3:
```bash
pip install z3-solver
```

Run a scenario:
```bash
python -c "from z3 import *; exec(open('part3/verify.py').read())"
```

Or use the online Z3 solver: https://jfmc.github.io/z3-play/
