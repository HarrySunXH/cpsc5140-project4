# Project 4 Report: Legal Text to SMT Formalization

**Course**: CPSC 5140 - Law and LLMs
**Legal Text**: 26 U.S. Code § 152 — Dependent Defined
**Student**: Harry Sun
**Date**: 2026-03-31

---

## Part 1: Legal Text to SMT Translation

### Legal Text Summary

26 USC §152 defines a "dependent" as either a **qualifying child** (§152(c)) or a **qualifying relative** (§152(d)), subject to exceptions in §152(b).

**Qualifying Child (§152(c))** — all five conditions must hold:
- **Relationship** §152(c)(2): child, stepchild, foster child, or sibling/step-sibling/half-sibling, or any descendant thereof
- **Residence** §152(c)(1)(B): same principal place of abode as taxpayer for **more than half** the tax year (>6 months)
- **Age** §152(c)(1)(C): under 19, OR under 24 and a full-time student, OR permanently and totally disabled
- **Self-support** §152(c)(1)(D): D did **not** provide more than half of their own support
- **Joint return** §152(c)(1)(E): D did not file a joint return with a spouse (exception: filed solely to claim a refund)

**Qualifying Relative (§152(d))** — all four conditions must hold:
- **Not a qualifying child** §152(d)(1)(A): D is not a qualifying child of any taxpayer
- **Relationship** §152(d)(2): either an enumerated family member (child, parent, sibling, grandparent, etc.) OR a member of T's household for the **entire** taxable year (12 months)
- **Gross income** §152(d)(1)(B): D's gross income is less than the exemption amount ($4,700 for 2023)
- **Support** §152(d)(1)(C): taxpayer provided **more than half** of D's total support

**Exceptions (§152(b))**:
- §152(b)(1): D filed a joint return (unless solely to claim a refund with no tax liability)
- §152(b)(3): D is not a U.S. citizen/national or resident of U.S., Canada, or Mexico
- §152(b)(2): Taxpayer T is themselves a dependent of another taxpayer

---

### Approach 1: Chain-of-Thought (CoT) Prompting

**Technique**: The LLM was prompted to reason step-by-step through the statute before producing SMT code. Each subsection was analyzed for its logical structure (AND/OR, comparisons, negations) before writing the corresponding predicate.

**Iterative development process** (full transcript: `part1/transcripts/transcript_cot_part1.md`):

**Iteration 1 — Initial CoT translation:**

Prompt: *"Translate 26 USC §152(a)–(d) into SMT-LIB2 using Chain-of-Thought reasoning: think step by step through each subsection..."*

LLM reasoning produced a five-step plan:
1. §152(a) → `is_dependent = is_qualifying_child ∨ is_qualifying_relative`
2. §152(b) → `passes_exceptions` (3-way AND: joint return, citizenship, taxpayer not a dependent)
3. §152(c) → `is_qualifying_child` (5-way AND: relationship, residence, age, self-support, no joint return)
4. §152(d) → `is_qualifying_relative` (4-way AND: not QC, relationship, income, support)
5. Final composition: `is_dependent = (QC ∨ QR) ∧ passes_exceptions`

Z3 sanity check (Iteration 1): `sat` ✓ — model is not vacuously unsatisfiable.

**Iteration 2 — Z3 compilation check and precision fix:**

Decimal literals (`0.5`) in support ratio comparisons were flagged as non-standard in strict SMT-LIB2. Replaced with `(/ 1.0 2.0)` in scenario files for exact arithmetic at the 50% boundary. Part 1 CoT file retains `0.5` (Z3 accepts both; precision only matters at exact thresholds).

**Iteration 3 — Manual test case reveals abstraction flaw:**

Prompt: *"Walk through Bob's elderly mother Ruth (age 72, earns $0, Bob provides 80% of support) against the SMT model."*

Finding: The v1 `qr_relationship_test` collapsed all §152(d)(2) relationships into one Boolean `is_specified_relative`. This is a black box — the model cannot distinguish a parent (on the list) from a cousin (not on the list). Any scenario can set the flag to `true` without justification.

**Iteration 4 — Refinement: enumerate §152(d)(2) relationships explicitly:**

Prompt: *"Replace `is_specified_relative` with explicit Boolean variables for each §152(d)(2)(A)–(G) category."*

Added five new variables:
- `is_parent_or_ancestor` — §152(d)(2)(C): father, mother, or ancestor
- `is_stepparent` — §152(d)(2)(D): stepfather or stepmother
- `is_niece_or_nephew` — §152(d)(2)(E): child of T's sibling
- `is_aunt_or_uncle` — §152(d)(2)(F): sibling of T's parent
- `is_in_law` — §152(d)(2)(G): in-laws

Updated `qr_relationship_test` now enumerates all 8 paths (7 family categories + full-year household). Z3 re-verification: all prior test cases still pass; Ruth case (QR via parent) newly testable and returns `sat`. ✓

**Result**: See `part1/part1_cot.smt2` (v2). Z3 confirms `sat`.

---

### Approach 2: Structured JSON Intermediary

**Technique**: A two-step process separating legal interpretation from SMT coding. Step 1: extract §152 into a JSON schema (conditions, types, parameters) — no code yet. Step 2: mechanically convert JSON to SMT-LIB2.

**Iterative development process** (full transcript: `part1/transcripts/transcript_json_part1.md`):

**Iteration 1 — JSON extraction:**

Prompt: *"Produce a JSON object representing the logical structure of §152. Do not write any code yet."*

Output: A JSON schema with all four statute sections. The JSON correctly captured the disjunctive/conjunctive structure and numeric thresholds. Two issues spotted during review:
- `no_joint_return` was a `ref` pointer in the QC branch — corrected to be defined once and reused
- `full_year_household` requirement was correctly distinguished from the QC `>6 months` threshold

**Iteration 2 — SMT translation and Z3 check:**

Prompt: *"Convert the JSON schema to SMT-LIB2 using `json_` prefix on all names."*

Result: `part1_json.smt2` v1. Z3 sanity check: `sat` ✓

**Iteration 3 — Cross-approach comparison finds shared flaw:**

Comparing with the CoT transcript's Iteration 3: the JSON model had the same `is_listed_relative` black-box problem. Cross-checking the two approaches surfaced this issue.

**Iteration 4 — Enumerate §152(d)(2) in JSON schema and regenerate SMT:**

Updated JSON `qr_relationship` to list all 8 conditions explicitly using the same variable names as the CoT approach for consistency. SMT regenerated as v2.

Re-verification: 5 test cases all pass (Emma, Robert, Maya, Ruth, Alex). ✓

**JSON Intermediate Representation** (excerpt — v2, full JSON in transcript):
```json
"qualifying_relative": {
  "conditions": [
    { "id": "qr_not_qc", "clause": "§152(d)(1)(A)", "type": "NOT" },
    { "id": "qr_relationship", "clause": "§152(d)(2)", "type": "OR",
      "conditions": [
        {"id": "rel_child_stepchild_foster", "clause": "§152(d)(2)(A)"},
        {"id": "rel_sibling_half_step",      "clause": "§152(d)(2)(B)"},
        {"id": "is_parent_or_ancestor",      "clause": "§152(d)(2)(C)"},
        {"id": "is_stepparent",              "clause": "§152(d)(2)(D)"},
        {"id": "is_niece_or_nephew",         "clause": "§152(d)(2)(E)"},
        {"id": "is_aunt_or_uncle",           "clause": "§152(d)(2)(F)"},
        {"id": "is_in_law",                  "clause": "§152(d)(2)(G)"},
        {"id": "full_year_household",        "description": "non-relative, entire year"}
      ]
    },
    { "id": "qr_gross_income",      "clause": "§152(d)(1)(B)", "operator": "<" },
    { "id": "qr_claimant_support",  "clause": "§152(d)(1)(C)", "operator": ">" }
  ]
}
```

**Result**: See `part1/part1_json.smt2` (v2). Z3 confirms `sat` ✓

---

### Comparison and Cross-Validation

Both approaches were cross-validated on 5 test cases after v2 refinement:

| Test Case | CoT v2 | JSON v2 | Match? | Notes |
|---|---|---|---|---|
| Sanity check (any valid dependent) | sat | sat | ✓ | |
| Emma (age 10, daughter, QC) | dependent | dependent | ✓ | QC path |
| Robert (age 45, colleague, fails all) | not dependent | not dependent | ✓ | |
| Maya (age 22, student, 50% support) | dependent | dependent | ✓ | QC borderline |
| **Ruth (age 72, Bob's mother, QR)** | **dependent** | **dependent** | ✓ | **New: tests `is_parent_or_ancestor`** |

The Ruth test case was only made possible after the Iteration 3/4 refinement. It confirmed that the QR path through `is_parent_or_ancestor` works correctly in both encodings.

| Criterion | CoT Approach | JSON Approach |
|---|---|---|
| Compiles with Z3 | ✓ sat | ✓ sat |
| §152(d)(2) relationships enumerated | ✓ (v2) | ✓ (v2) |
| Full-year vs >6 months distinction | ✓ | ✓ |
| Handles §152(b) exceptions correctly | ✓ | ✓ |
| Test case accuracy (5 cases) | 5/5 ✓ | 5/5 ✓ |
| Separation of legal reasoning from coding | Mixed | ✓ (two-step) |
| Human-readable intermediate form | No | ✓ (JSON schema) |
| Inline legal annotations | Extensive | Minimal |

**Key finding from iteration**: Both approaches independently produced the same `is_specified_relative` abstraction flaw. Cross-comparing the two transcripts was what identified the problem. This confirms the value of using two different approaches in parallel — each serves as a check on the other.

---

## Part 2: Scenario Generation

### Scenario 1: Person IS a Dependent — Emma

**Taxpayer**: Alice (age 35)
**Potential Dependent**: Emma (age 10, Alice's biological daughter)

Facts:
- Emma is Alice's biological daughter → QC relationship test ✓
- Emma lives with Alice all 12 months → QC residence test (12 > 6) ✓
- Emma is age 10 (< 19) → QC age test ✓
- Alice provides 100% of Emma's support → QC self-support test (0.0 not > 0.5) ✓
- Emma earned $0, filed no joint return, is a U.S. citizen ✓

Expected result: Emma IS a dependent (qualifying child). See `part2/scenario_dependent.smt2`.

---

### Scenario 2: Person is NOT a Dependent — Robert

**Taxpayer**: Bob (age 40)
**Potential Dependent**: Robert (age 45, Bob's work colleague)

Facts:
- Robert is a colleague with no family relationship → QC relationship test ✗
- Robert lived with Bob for only 3 months → QC residence test (3 ≤ 6) ✗; QR household test (3 ≠ 12) ✗
- Robert is 45 years old → QC age test ✗
- Robert earns $60,000 → QR income test ($60,000 > $4,700) ✗
- Robert provides all his own support → QC self-support test ✗; QR support test ✗

Expected result: Robert is NOT a dependent. Fails all tests on multiple dimensions. See `part2/scenario_nondependent.smt2`.

---

### Scenario 3: Borderline / Ambiguous Case — Maya

**Taxpayer**: Carol (age 50)
**Potential Dependent**: Maya (age 22, Carol's biological daughter, full-time student)

Facts:
- Maya is Carol's biological daughter → QC relationship test ✓
- Maya lives with Carol for exactly 7 months → QC residence test (7 > 6) ✓
- Maya is 22 and a full-time student → QC age test (< 24 AND student) ✓
- Maya provides **exactly 50%** of her own support → QC self-support test: NOT(0.5 > 0.5) = NOT(False) = **True** ✓ (borderline)
- Carol provides **exactly 50%** of Maya's total support → QR support test: 0.5 > 0.5 = **False** ✗ (borderline)
- Maya earns $4,600 (below $4,700 exemption)
- No joint return, U.S. citizen

**Borderline analysis**: The exact 50% self-support boundary sits precisely at the statutory threshold. §152(c)(1)(D) uses "not more than half" (i.e., ≤ 0.5), so 50% passes QC. But §152(d)(1)(C) uses "more than half" (strict > 0.5), so 50% from Carol fails QR. This asymmetry — QC uses non-strict ≤, QR uses strict > — is correctly captured by the SMT encoding and is not obvious from reading the statute casually.

Expected result: Maya IS a dependent (via qualifying child, barely). See `part2/scenario_borderline.smt2`.

---

## Part 3: Compliance Verification

### Z3 Solver Results

| Scenario | Expected | Z3 `is_dependent` | Correct? |
|---|---|---|---|
| Emma (age 10, daughter) | IS dependent | True | ✓ YES |
| Robert (age 45, colleague) | NOT dependent | False | ✓ YES |
| Maya (age 22, student, 50% support) | IS dependent | True | ✓ YES |

All three scenarios correctly classified. Full Z3 output in `part3/z3_outputs.txt`.

### Discussion

**Emma**: The clearest case. Z3 confirms `sat` with `is_qualifying_child = True` on all five conditions. Emma also passes the qualifying relative test, demonstrating that a QC can simultaneously pass the QR test (both paths evaluate to True, but the final `is_dependent` only requires one).

**Robert**: Z3 correctly returns `is_dependent = False`. The model evaluates all sub-conditions and reports which tests fail — QC fails on relationship, age, and residence; QR fails on relationship, income, and support. The multi-failure provides confidence the model is not giving the right answer for the wrong reason.

**Maya**: The borderline case is the most instructive. Z3 confirms:
- `qc_support_test = True` (0.5 is not > 0.5 — passes QC)
- `qr_support_test = False` (0.5 is not > 0.5 — fails QR)

This demonstrates that the SMT encoding correctly distinguishes between the two support tests and captures the asymmetry in the statute. An encoding that accidentally used the same comparison for both would produce incorrect results here.

---

## Part 4: Model Refinement

### Iteration Log

| Iteration | Issue Found | Fix Applied | Impact |
|---|---|---|---|
| 1 | `no_joint_return_test` appears in both `is_qualifying_child` and `passes_exceptions` — redundant | Kept intentionally; overlap is faithful to both §152(c)(1)(E) and §152(b)(1); harmless in Z3 | Style only — no correctness impact |
| 2 | Decimal literals `0.5` vs rational `(/ 1.0 2.0)` — non-standard in strict SMT-LIB2 | Scenario files use `(/ 1.0 2.0)` for exact borderline boundaries; Part 1 CoT uses `0.5` (Z3 accepts both) | Correctness unaffected; precision issue only at exact boundary |
| 3 | QR household member requirement ("entire year") initially confused with QC cohabitation (">6 months") | Added distinct Boolean `is_household_member_full_year` / `full_year_household` for QR; kept `months_same_abode > 6` for QC only | **Critical fix** — affects Part B scenario result |

### Combining the Two Approaches

The two approaches are functionally equivalent and agree on all test cases. Their differences are:
- **Naming**: CoT uses shorter names (`months_same_abode`); JSON uses descriptive names (`cohabitation_months`)
- **Process**: CoT mixes legal analysis and coding; JSON separates them into two steps
- **Documentation**: CoT has richer inline SMT comments; JSON has a standalone machine-readable specification

The JSON schema can serve as the canonical specification document for future encodings (Prolog, Datalog, other proof assistants), while the CoT SMT file serves as the primary Z3 input due to its conciseness and annotations.

---

## Part B: LLM vs SMT Divergence Analysis

### Scenario Description

**Taxpayer**: Dave (age 38)
**Potential Dependent**: Alex (age 35, Dave's friend — no family relationship)

- Alex lived with Dave for **8 months** of the tax year
- Dave provided **65%** of Alex's support
- Alex earned **$3,000** (below the $4,700 exemption)
- Alex is a U.S. citizen, filed no joint return
- Dave is not a dependent of anyone

### LLM Answer (without CoT)

**Prompt**: "Is Alex a dependent of Dave under 26 USC §152? Answer yes or no."

**LLM Answer**: **YES** (dependent)

**LLM Reasoning**: The LLM identified that Dave provides >50% support, Alex's income is below the exemption amount, Alex filed no joint return, and Alex is a U.S. citizen. It concluded all qualifying relative requirements are met.

### SMT Solver Answer

**Z3 Result**: `is_dependent = False` — Alex is **NOT** a dependent.

Z3 evaluation:
- `json_qr_relationship = False`
  - `is_listed_relative = False` (friend ≠ enumerated relative)
  - `full_year_household = False` (8 months ≠ 12 months)
- `json_qualifying_relative = False` (relationship test fails, propagates)
- `json_is_dependent = False`

### Legally Correct Answer

**Alex is NOT a dependent.** The SMT solver is correct.

Under §152(d)(2), a qualifying relative must either be an enumerated family member or a member of the taxpayer's household for the **entire** taxable year. Alex is a friend (not an enumerated relative) and lived with Dave for only 8 months (not the full 12 months). The relationship test fails regardless of whether income, support, and citizenship conditions are met.

### Chain-of-Thought Analysis

When re-prompted with explicit CoT instruction to check each §152(d) condition in order, the LLM correctly:
1. Identified that Alex is not an enumerated relative
2. Recognized that 8 months ≠ entire year for household membership
3. Concluded Alex fails the relationship test → NOT a dependent

CoT resolved the error by forcing the model to enumerate and apply every condition, including the structural gating condition that the model had skipped.

### Divergence Analysis

| Check | LLM (no CoT) | LLM (with CoT) | SMT | Correct? |
|---|---|---|---|---|
| QC path | Fails (no family, age 35) | Fails | False | ✓ All agree |
| QR: not a QC | Passes | Passes | True | ✓ All agree |
| **QR: relationship test** | **Assumed / skipped** | Fails (not relative, 8 months ≠ 12) | **False** | ✗ No-CoT LLM wrong |
| QR: gross income | Passes ($3k < $4.7k) | Passes (moot) | True | ✓ |
| QR: support fraction | Passes (65% > 50%) | Passes (moot) | True | ✓ |
| Citizenship, joint return | Passes | Passes (moot) | True | ✓ |
| **Final answer** | **YES (wrong)** | **NO (correct)** | **NO (correct)** | SMT + CoT correct |

**Root cause**: LLM's omission of the §152(d)(2) relationship test.

The LLM without CoT focused on the numerically salient conditions (income threshold, support percentage) and treated the relationship requirement as automatically satisfied because Alex "lives with Dave." It missed two critical details:
1. Non-family members only qualify if they are household members for the **entire** year, not part of the year.
2. The "member of household" category exists only for individuals who are not already enumerated relatives — it is a fallback, not a default.

The SMT encoding eliminates this failure mode by making the relationship test an explicit logical conjunction. The solver cannot "skip" a condition — it evaluates all of them simultaneously. This illustrates the core value of formal verification for legal reasoning: it is immune to the selective attention errors that affect LLMs under sparse prompting conditions.
