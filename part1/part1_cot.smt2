; ============================================================
; Part 1: 26 USC §152 - Dependent Defined
; Approach: Chain-of-Thought (CoT) Prompting
;
; CoT Reasoning Process:
;   Step 1: Read §152(a) — top-level structure: dependent = qualifying_child OR qualifying_relative
;   Step 2: Read §152(b) — exceptions that disqualify anyone from being a dependent
;   Step 3: Read §152(c) — break down qualifying child into 5 sub-conditions
;   Step 4: Read §152(d) — break down qualifying relative into 4 sub-conditions
;   Step 5: Compose all sub-conditions into a final is_dependent predicate
;   Step 6: Assert the exemption amount constant and run sanity check
; ============================================================

; ============================================================
; STEP 1: Declare all variables for taxpayer T and potential dependent D
; ============================================================

; --- §152(c)(2): Relationship types for Qualifying Child ---
; CoT: The statute lists: child, stepchild, eligible foster child, or their descendant,
;      OR sibling, step-sibling, half-sibling, or their descendant.
;      We collapse these into two Boolean flags.
(declare-const is_child_or_descendant Bool)   ; child/stepchild/foster/descendant of T
(declare-const is_sibling_or_descendant Bool) ; sibling/step/half-sibling/descendant of T

; --- §152(c)(1)(B): Residence ---
; CoT: D must have the same principal place of abode as T for MORE THAN HALF the tax year.
;      A tax year = 12 months, so more than half = more than 6 months.
(declare-const months_same_abode Int)  ; integer months D lived with T (0–12)

; --- §152(c)(1)(C): Age ---
; CoT: Three alternative ways to satisfy the age test:
;      (i) under age 19, OR
;      (ii) under age 24 AND a full-time student, OR
;      (iii) permanently and totally disabled (any age)
(declare-const age Int)                       ; D's age at end of tax year
(declare-const is_full_time_student Bool)     ; D is a full-time student
(declare-const is_permanently_disabled Bool)  ; D is permanently and totally disabled

; --- §152(c)(1)(D): Self-support ---
; CoT: D must NOT have provided more than half of their own support.
;      We represent D's self-support as a fraction [0.0, 1.0].
(declare-const d_self_support_ratio Real)     ; fraction of own support D provided

; --- §152(b)(1) / §152(c)(1)(E): Joint return ---
; CoT: D cannot have filed a joint return with a spouse,
;      UNLESS the return was filed solely to claim a refund
;      and neither D nor spouse would have tax liability.
(declare-const filed_joint_return Bool)
(declare-const filed_joint_only_for_refund Bool)

; --- §152(b)(3): Citizenship / Residency ---
; CoT: D must be a U.S. citizen, U.S. national, or resident of the U.S., Canada, or Mexico.
;      (Adopted child exception exists but is collapsed here.)
(declare-const is_us_citizen_or_national Bool)
(declare-const is_resident_us_canada_mexico Bool)

; --- §152(b)(2): Taxpayer eligibility ---
; CoT: If T is themselves a dependent of another taxpayer, T cannot claim dependents.
(declare-const taxpayer_is_dependent_of_another Bool)

; --- §152(d): Qualifying Relative additional variables ---

; §152(d)(2): Relationship types for Qualifying Relative
; CoT: A broader list than qualifying child: includes parents, grandparents,
;      aunts/uncles, in-laws, etc. OR anyone who is a member of T's household all year.
(declare-const is_specified_relative Bool)          ; one of the listed family relationships
(declare-const is_household_member_full_year Bool)  ; lived in T's household ALL 12 months

; §152(d)(1)(B): Gross income test
; CoT: D's gross income must be LESS THAN the exemption amount.
(declare-const gross_income Int)      ; D's gross income in dollars
(declare-const exemption_amount Int)  ; statutory exemption amount (e.g. $4,700 for 2023)

; §152(d)(1)(C): Support by taxpayer
; CoT: T must have provided MORE THAN HALF of D's total support for the year.
(declare-const taxpayer_support_ratio Real)  ; fraction of D's total support T provided

; §152(d)(1)(A): Not a qualifying child
; CoT: A qualifying relative must NOT be a qualifying child of ANY taxpayer (not just T).
(declare-const is_qc_of_any_taxpayer Bool)

; ============================================================
; STEP 2: Define sub-conditions (§152(c) — Qualifying Child)
; ============================================================

; CoT Step 3a — §152(c)(2): Relationship test
(define-fun qc_relationship_test () Bool
  (or is_child_or_descendant
      is_sibling_or_descendant))

; CoT Step 3b — §152(c)(1)(B): Residence test
(define-fun qc_residence_test () Bool
  (> months_same_abode 6))

; CoT Step 3c — §152(c)(1)(C): Age test
(define-fun qc_age_test () Bool
  (or (< age 19)
      (and (< age 24) is_full_time_student)
      is_permanently_disabled))

; CoT Step 3d — §152(c)(1)(D): Support test (D did NOT provide more than half own support)
(define-fun qc_support_test () Bool
  (not (> d_self_support_ratio 0.5)))

; CoT Step 3e — §152(c)(1)(E) + §152(b)(1): Joint return test
(define-fun no_joint_return_test () Bool
  (or (not filed_joint_return)
      filed_joint_only_for_refund))

; CoT Step 3 (composite) — All five conditions must hold for a qualifying child
(define-fun is_qualifying_child () Bool
  (and qc_relationship_test
       qc_residence_test
       qc_age_test
       qc_support_test
       no_joint_return_test))

; ============================================================
; STEP 3: Define sub-conditions (§152(d) — Qualifying Relative)
; ============================================================

; CoT Step 4a — §152(d)(1)(A): D is NOT a qualifying child of any taxpayer
(define-fun qr_not_qualifying_child_test () Bool
  (not is_qc_of_any_taxpayer))

; CoT Step 4b — §152(d)(2): Relationship or household test
(define-fun qr_relationship_test () Bool
  (or is_specified_relative
      is_household_member_full_year))

; CoT Step 4c — §152(d)(1)(B): Gross income test
(define-fun qr_income_test () Bool
  (< gross_income exemption_amount))

; CoT Step 4d — §152(d)(1)(C): Taxpayer-provided support test
(define-fun qr_support_test () Bool
  (> taxpayer_support_ratio 0.5))

; CoT Step 4 (composite) — All four conditions for a qualifying relative
(define-fun is_qualifying_relative () Bool
  (and qr_not_qualifying_child_test
       qr_relationship_test
       qr_income_test
       qr_support_test))

; ============================================================
; STEP 4: Define §152(b) exceptions
; ============================================================

; CoT Step 2: Three exceptions that block dependent status regardless of §152(c)/(d):
;   (b)(1) Filed joint return (unless only for refund)
;   (b)(3) Not a citizen/resident of U.S., Canada, or Mexico
;   (b)(2) Taxpayer is themselves a dependent of another
(define-fun passes_exceptions () Bool
  (and no_joint_return_test
       (or is_us_citizen_or_national
           is_resident_us_canada_mexico)
       (not taxpayer_is_dependent_of_another)))

; ============================================================
; STEP 5: Final §152(a) definition — is_dependent
; ============================================================

; CoT Step 1 (final composition):
; D is a dependent of T iff:
;   (D is a qualifying child OR a qualifying relative)
;   AND all exceptions are satisfied
(define-fun is_dependent () Bool
  (and (or is_qualifying_child
           is_qualifying_relative)
       passes_exceptions))

; ============================================================
; STEP 6: Constraints and sanity check
; ============================================================

; Statutory exemption amount for tax year 2023
(assert (= exemption_amount 4700))

; Domain constraints
(assert (and (>= months_same_abode 0) (<= months_same_abode 12)))
(assert (>= age 0))
(assert (and (>= d_self_support_ratio 0.0) (<= d_self_support_ratio 1.0)))
(assert (and (>= taxpayer_support_ratio 0.0) (<= taxpayer_support_ratio 1.0)))
(assert (>= gross_income 0))

; Sanity check: verify that a valid dependent scenario is satisfiable
; (i.e., the model is not vacuously unsatisfiable)
(assert is_dependent)
(check-sat)
(get-model)
