# Part 4: Model Refinement Notes

## Goal
Document all iterations, unexpected results, and how the two approaches were combined into a final verified model.

---

## Iteration Log

### Iteration 1 — Redundant Joint Return Check

**Issue**:
In the CoT approach, `no_joint_return_test` appears twice: once inside `is_qualifying_child` (§152(c)(1)(E)) and again inside `passes_exceptions` (§152(b)(1)). This creates a logical redundancy — for any path through `is_qualifying_child`, the joint return test is evaluated twice.

**Discovery method**: Reviewing the SMT structure after initial generation, comparing with the original statute. §152(b)(1) applies to ALL dependents (not just qualifying children), while §152(c)(1)(E) is technically a qualifying-child-specific clause. In practice they encode the same condition.

**Fix**:
Kept the redundancy intentionally. Because `is_qualifying_relative` does NOT include the joint return check directly, the `passes_exceptions` layer is what enforces it for qualifying relatives. Including `no_joint_return_test` inside `is_qualifying_child` is a faithful encoding of §152(c)(1)(E), even though it overlaps with §152(b)(1). The overlap is harmless and makes the QC sub-conditions self-contained and easier to audit.

**Result**: No code change. Added comment in both SMT files clarifying the intentional overlap.

---

### Iteration 2 — Numeric Precision: Real vs Rational

**Issue**:
Initial CoT SMT drafts used decimal literals (`0.5`, `1.0`) for the support fraction comparisons. When tested with Z3's Python API, the solver correctly handled these, but the SMT-LIB2 standard and some Z3 versions prefer rational literals (`(/ 1.0 2.0)`) for exact arithmetic.

**Discovery method**: Z3 successfully solved both forms, but online SMT validators flagged bare `0.5` as non-standard.

**Fix**:
The scenario files (`scenario_dependent.smt2`, `scenario_borderline.smt2`, `scenario_nondependent.smt2`) use `(/ 1.0 2.0)` for the exact 50% boundary. The Part 1 CoT file uses `0.5` directly (Z3 accepts both). The JSON approach file consistently uses `(/ 1.0 2.0)`.

**Result**: All files produce `sat`/`unsat` correctly. Precision issue does not affect any of the three scenarios.

---

### Iteration 3 — Household Member "Entire Year" vs "More Than Half"

**Issue**:
The qualifying relative relationship test (§152(d)(2)) includes "a member of the taxpayer's household." An early draft used `months_same_abode > 6` (the QC cohabitation threshold) as a proxy for this condition. This is incorrect: the statute requires household membership for the **entire** taxable year, not just more than half.

**Discovery method**: Cross-checking the JSON approach against the CoT approach. The JSON explicitly captured this as `full_year_household` (a Boolean flag), while the initial CoT draft had silently reused the months-based test.

**Fix**:
Added a separate `is_household_member_full_year` Boolean variable (CoT approach) and `full_year_household` (JSON approach), representing a distinct 12-month requirement. The `months_same_abode > 6` test remains exclusive to qualifying child cohabitation.

**Result**: This fix is critical for Part B (see `partB/`): the Robert scenario (3-month cohabitant) correctly fails both the QC test and the QR household test. The Part B scenario (Alex, 8-month non-relative cohabitant) also correctly fails the QR household test because 8 months ≠ full year.

---

---

### Iteration 4 — §152(d)(2) Relationship Enumeration (Cross-Approach Discovery)

**Issue**:
Both v1 SMT files used a single Boolean flag for the §152(d)(2) relationship test:
- CoT approach: `is_specified_relative Bool`
- JSON approach: `is_listed_relative Bool`

This is too abstract. The model cannot distinguish a parent (on the §152(d)(2) list) from a cousin or friend (not on the list). Setting the flag to `true` for a test scenario requires manual justification with no machine-checkable basis. Additionally, the Ruth test case (elderly parent as QR) could not be properly verified — the model would classify her correctly only if someone manually asserted `is_specified_relative = true`, with no formal grounding.

**Discovery method**: Cross-comparing the two approaches during Part 1 comparison. The JSON approach surfaced this issue when reviewing the `qr_relationship` field in the JSON schema — it named the flag `is_listed_relative` but never enumerated what "listed" means. Noticing the same pattern in the CoT approach confirmed this was a systematic problem, not an isolated one.

**Fix**:
Replaced both flags with five explicit Boolean variables matching §152(d)(2)(C)–(G):
- `is_parent_or_ancestor` — §152(d)(2)(C)
- `is_stepparent` — §152(d)(2)(D)
- `is_niece_or_nephew` — §152(d)(2)(E)
- `is_aunt_or_uncle` — §152(d)(2)(F)
- `is_in_law` — §152(d)(2)(G)

The §152(d)(2)(A) and (B) categories (child/descendant and sibling/descendant) reuse the existing QC relationship variables, which is legally correct — those relationship types qualify under both QC and QR rules.

**Result**: Ruth test case (elderly parent as QR) now correctly returns `sat` via the `is_parent_or_ancestor = true` path. Alex Part B (friend, 8 months) still correctly returns `unsat` — all 7 family categories and the household flag are `false`. Full 6-case test suite passes for both v2 SMT files.

---

## Combining the Two Approaches

### CoT Approach Strengths:
- The step-by-step reasoning process mirrors the statute's own structure, making it easy to verify each clause against the original legal text.
- Inline comments explain the legal rationale behind each SMT predicate.
- Well-suited for catching nuanced conditions (e.g., the "only to claim a refund" exception to the joint return rule).

### JSON Approach Strengths:
- The JSON intermediate representation provides a machine-readable, language-independent encoding of the legal structure before any code is written.
- The two-step process (extract → convert) separates legal interpretation from SMT syntax, reducing errors caused by trying to do both at once.
- The JSON schema can be reused for other formalisms (e.g., Prolog, Datalog) without re-prompting from scratch.
- Variable names in the JSON approach are more descriptive (`cohabitation_months`, `claimant_support_fraction`) than the CoT approach's shorter names (`months_same_abode`, `taxpayer_support_ratio`).

### Final Combined Solution:
The two approaches encode the same legal logic and agree on all test scenarios. The differences are surface-level (naming, style, prefix convention). A combined model would:
1. Use the JSON schema as the specification document (human-readable representation of the law).
2. Use the CoT SMT file as the primary Z3 input (more concise, better annotated).
3. Use the JSON SMT file as a cross-validation tool: any scenario that gives different results between the two files would indicate an encoding error.

All three Part 2 scenarios and the Part B scenario were tested against both encodings and produced identical results, confirming the two approaches are equivalent.
