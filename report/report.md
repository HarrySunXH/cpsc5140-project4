# Project 4 Report: Legal Text to SMT Formalization

**Course**: CPSC 5140 - Law and LLMs
**Legal Text**: 26 U.S. Code § 152 — Dependent Defined
**Team Members**: [Your Name], [Teammate Name]
**Date**: 2026-03-30

---

## Part 1: Legal Text to SMT Translation

### Legal Text Summary

26 USC §152 defines a "dependent" as either a **qualifying child** or a **qualifying relative**.

**Qualifying Child (§152(c))** requires:
- Relationship: child, stepchild, sibling, step-sibling, or descendant thereof
- Residence: same principal abode as taxpayer for more than half the tax year
- Age: under 19, OR under 24 and a full-time student, OR permanently disabled
- Support: did not provide over half of own support
- Joint return: did not file a joint return with a spouse (or filed only to claim a refund)

**Qualifying Relative (§152(d))** requires:
- Relationship: specified family member OR member of taxpayer's household for the full year
- Gross income: less than the exemption amount ($4,700 for 2023)
- Support: taxpayer provided more than half of the individual's support
- Not a qualifying child: not a qualifying child of any taxpayer

**Exceptions (§152(b))**:
- Cannot be a dependent if they filed a joint return
- Must be a U.S. citizen/national or resident of U.S., Canada, or Mexico (with exceptions)

### Approach 1: Chain-of-Thought (CoT) Prompting

[Document your CoT prompting process here]

**Prompt used**: [Insert prompt]

**LLM Response / Reasoning steps**: [Insert transcript summary]

**Result**: See `part1/part1_cot.smt2`

### Approach 2: Structured JSON Intermediary

[Document teammate's JSON approach here]

**Prompt used**: [Insert prompt]

**JSON intermediate representation**: [Insert JSON]

**Result**: See `part1/part1_json.smt2`

### Comparison

| Criterion | CoT Approach | JSON Approach |
|---|---|---|
| Compiles with Z3 | | |
| Captures qualifying child correctly | | |
| Captures qualifying relative correctly | | |
| Handles exceptions | | |
| Test case accuracy | | |

---

## Part 2: Scenario Generation

### Scenario 1: Person IS a Dependent

[Insert scenario description]

See `part2/scenario_dependent.smt2`

### Scenario 2: Person is NOT a Dependent

[Insert scenario description]

See `part2/scenario_nondependent.smt2`

### Scenario 3: Borderline / Ambiguous Case

[Insert scenario description]

See `part2/scenario_borderline.smt2`

---

## Part 3: Compliance Verification

### Z3 Solver Results

| Scenario | Expected | Z3 Output | Correct? |
|---|---|---|---|
| Dependent | sat (is dependent) | | |
| Non-dependent | unsat / not dependent | | |
| Borderline | | | |

### Discussion

[Insert discussion of solver outputs here]

---

## Part 4: Model Refinement

### Iteration Log

| Iteration | Issue Found | Fix Applied |
|---|---|---|
| 1 | | |
| 2 | | |

### Combining Team Solutions

[Document how you merged CoT and JSON approaches]

---

## Part B: LLM vs SMT Divergence Analysis

### Scenario Description

[Insert scenario where LLM and SMT disagree]

### LLM Answer

[Insert LLM's initial answer (without CoT)]

### SMT Solver Answer

[Insert Z3 result]

### Legally Correct Answer

[Insert manual legal analysis]

### Chain-of-Thought Analysis

[Insert LLM's CoT reasoning steps]

### Divergence Analysis

| Step | LLM Reasoning | SMT Formalization | Match? |
|---|---|---|---|
| | | | |

**Root cause of discrepancy**: [LLM interpretation / SMT encoding / scenario specification]
