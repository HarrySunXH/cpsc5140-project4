; ============================================================
; Part 1: 26 USC §152 - Dependent Defined
; Approach: Structured JSON Intermediary
;
; Process:
;   Step 1: Prompt LLM to extract §152 into a structured JSON schema
;           capturing all conditions, their types (AND/OR), and parameters.
;   Step 2: Review and correct the JSON intermediate representation.
;   Step 3: Prompt LLM to mechanically convert JSON → SMT-LIB2.
;
; See transcript: part1/transcripts/transcript_json_part1.md
; ============================================================

; ============================================================
; Variable Declarations
; (derived from JSON schema field names — see transcript)
; ============================================================

; Relationship flags — §152(c)(2) qualifying child relationship
(declare-const rel_child_stepchild_foster Bool)   ; child, stepchild, eligible foster child, or descendant
(declare-const rel_sibling_half_step Bool)        ; sibling, half-sibling, step-sibling, or descendant

; Cohabitation — §152(c)(1)(B)
(declare-const cohabitation_months Int)           ; integer months of shared principal abode

; Age and student/disability status — §152(c)(1)(C)
(declare-const person_age Int)
(declare-const enrolled_full_time Bool)           ; full-time student per §152(f)(2)
(declare-const totally_disabled Bool)             ; permanently and totally disabled per §22(e)(3)

; Self-support fraction — §152(c)(1)(D)
(declare-const self_support_fraction Real)        ; [0.0, 1.0] — fraction of support D provided for themselves

; Joint return — §152(b)(1) / §152(c)(1)(E)
(declare-const joint_return_filed Bool)
(declare-const joint_return_refund_only Bool)     ; true iff filed solely to claim refund (no tax liability)

; Citizenship / residency — §152(b)(3)
(declare-const citizen_or_national Bool)          ; U.S. citizen or national
(declare-const resident_us_can_mex Bool)          ; resident of U.S., Canada, or Mexico

; Taxpayer eligibility — §152(b)(2)
(declare-const claimant_is_dependent Bool)        ; true if the taxpayer is themselves a dependent

; Qualifying Relative variables — §152(d)
; v2 refinement: §152(d)(2)(A)-(G) enumerated explicitly rather than collapsed into one flag.
; (A) and (B) are reused from the QC relationship variables above.
(declare-const is_parent_or_ancestor Bool)        ; §152(d)(2)(C): parent, grandparent, or ancestor
(declare-const is_stepparent Bool)                ; §152(d)(2)(D): stepfather or stepmother
(declare-const is_niece_or_nephew Bool)           ; §152(d)(2)(E): child of T's brother or sister
(declare-const is_aunt_or_uncle Bool)             ; §152(d)(2)(F): sibling of T's father or mother
(declare-const is_in_law Bool)                    ; §152(d)(2)(G): son/daughter/father/mother/brother/sister-in-law
(declare-const full_year_household Bool)          ; non-relative member of T's household the ENTIRE tax year
(declare-const d_gross_income Int)                ; D's gross income in dollars
(declare-const exemption_threshold Int)           ; §151(d) exemption amount (e.g. $4,700 for 2023)
(declare-const claimant_support_fraction Real)    ; [0.0, 1.0] — fraction of D's support T provided
(declare-const qc_of_anyone Bool)                 ; true if D is a qualifying child of ANY taxpayer

; ============================================================
; Predicate Definitions
; (mechanically converted from JSON schema)
; ============================================================

; --- Qualifying Child sub-conditions ---

; JSON field: "qc_relationship" → OR of two relationship flags
(define-fun json_qc_relationship () Bool
  (or rel_child_stepchild_foster rel_sibling_half_step))

; JSON field: "qc_cohabitation" → cohabitation_months must exceed 6
(define-fun json_qc_cohabitation () Bool
  (> cohabitation_months 6))

; JSON field: "qc_age" → three-way OR
(define-fun json_qc_age () Bool
  (or (< person_age 19)
      (and (< person_age 24) enrolled_full_time)
      totally_disabled))

; JSON field: "qc_self_support" → D did NOT provide more than half own support
(define-fun json_qc_self_support () Bool
  (not (> self_support_fraction (/ 1.0 2.0))))

; JSON field: "no_joint_return" → used by both QC and exceptions
(define-fun json_no_joint_return () Bool
  (or (not joint_return_filed) joint_return_refund_only))

; JSON composite: qualifying_child → all 5 sub-conditions
(define-fun json_qualifying_child () Bool
  (and json_qc_relationship
       json_qc_cohabitation
       json_qc_age
       json_qc_self_support
       json_no_joint_return))

; --- Qualifying Relative sub-conditions ---

; JSON field: "qr_not_qc" → D is not a QC of any taxpayer
(define-fun json_qr_not_qc () Bool
  (not qc_of_anyone))

; JSON field: "qr_relationship" → OR of all §152(d)(2)(A)-(G) categories plus full-year household
; v2: enumerated from corrected JSON schema (see transcript_json_part1.md Prompt 5)
(define-fun json_qr_relationship () Bool
  (or rel_child_stepchild_foster    ; §152(d)(2)(A): reuses QC variable
      rel_sibling_half_step         ; §152(d)(2)(B): reuses QC variable
      is_parent_or_ancestor         ; §152(d)(2)(C)
      is_stepparent                 ; §152(d)(2)(D)
      is_niece_or_nephew            ; §152(d)(2)(E)
      is_aunt_or_uncle              ; §152(d)(2)(F)
      is_in_law                     ; §152(d)(2)(G)
      full_year_household))

; JSON field: "qr_gross_income" → D's income strictly below exemption threshold
(define-fun json_qr_gross_income () Bool
  (< d_gross_income exemption_threshold))

; JSON field: "qr_claimant_support" → T provided strictly more than half of D's support
(define-fun json_qr_claimant_support () Bool
  (> claimant_support_fraction (/ 1.0 2.0)))

; JSON composite: qualifying_relative → all 4 sub-conditions
(define-fun json_qualifying_relative () Bool
  (and json_qr_not_qc
       json_qr_relationship
       json_qr_gross_income
       json_qr_claimant_support))

; --- §152(b) Exceptions ---

; JSON field: "exceptions" → 3 conditions (AND)
(define-fun json_passes_exceptions () Bool
  (and json_no_joint_return
       (or citizen_or_national resident_us_can_mex)
       (not claimant_is_dependent)))

; --- Top-level predicate ---

; JSON field: "is_dependent" → (QC OR QR) AND passes_exceptions
(define-fun json_is_dependent () Bool
  (and (or json_qualifying_child json_qualifying_relative)
       json_passes_exceptions))

; ============================================================
; Domain Constraints and Sanity Check
; ============================================================

; Statutory exemption amount
(assert (= exemption_threshold 4700))

; Domain bounds
(assert (and (>= cohabitation_months 0) (<= cohabitation_months 12)))
(assert (>= person_age 0))
(assert (and (>= self_support_fraction 0.0) (<= self_support_fraction 1.0)))
(assert (and (>= claimant_support_fraction 0.0) (<= claimant_support_fraction 1.0)))
(assert (>= d_gross_income 0))

; Sanity check: verify at least one valid dependent assignment exists
(assert json_is_dependent)
(check-sat)
(get-model)
