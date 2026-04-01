; ============================================================
; Part B — SMT Encoding of Divergence Scenario
; Scenario: "Alex — The 8-Month Roommate"
; ============================================================
;
; Taxpayer:  Dave (age 38, U.S. citizen, not a dependent of anyone else)
; Potential Dependent: Alex (age 35, Dave's friend — no family relationship)
;
; Facts:
;   - Alex has NO family relationship to Dave (friend only) ✗
;   - Alex lived with Dave for exactly 8 months of the tax year ✗
;     (not the ENTIRE year required for non-relative household members)
;   - Alex is 35 years old (fails QC age test; not a student; not disabled) ✗
;   - Alex earned $3,000 gross income (below $4,700 exemption) ✓
;   - Dave provided 65% of Alex's total support ✓
;   - Alex did not file a joint return ✓
;   - Alex is a U.S. citizen ✓
;   - Dave is not a dependent of anyone ✓
;
; LLM Answer (no CoT): YES — Alex is a dependent
;   (LLM focused on support% and income, skipped the relationship test)
;
; Z3 Answer:           NO  — Alex is NOT a dependent
;   (fails §152(d)(2): not an enumerated relative, not a full-year household member)
;
; Legally Correct:     NO  — Z3 is correct
;
; See partB/analysis.md for the full divergence analysis.
; ============================================================

; --- Variable declarations (using same names as part1_cot.smt2) ---
(declare-const is_child_or_descendant Bool)
(declare-const is_sibling_or_descendant Bool)
(declare-const months_same_abode Int)
(declare-const age Int)
(declare-const is_full_time_student Bool)
(declare-const is_permanently_disabled Bool)
(declare-const d_self_support_ratio Real)
(declare-const filed_joint_return Bool)
(declare-const filed_joint_only_for_refund Bool)
(declare-const is_us_citizen_or_national Bool)
(declare-const is_resident_us_canada_mexico Bool)
(declare-const taxpayer_is_dependent_of_another Bool)
(declare-const is_specified_relative Bool)
(declare-const is_household_member_full_year Bool)
(declare-const gross_income Int)
(declare-const exemption_amount Int)
(declare-const taxpayer_support_ratio Real)
(declare-const is_qc_of_any_taxpayer Bool)

; --- §152 rule definitions (same encoding as part1_cot.smt2) ---
(define-fun qc_relationship_test () Bool
  (or is_child_or_descendant is_sibling_or_descendant))
(define-fun qc_residence_test () Bool
  (> months_same_abode 6))
(define-fun qc_age_test () Bool
  (or (< age 19)
      (and (< age 24) is_full_time_student)
      is_permanently_disabled))
(define-fun qc_support_test () Bool
  (not (> d_self_support_ratio (/ 1.0 2.0))))
(define-fun no_joint_return_test () Bool
  (or (not filed_joint_return) filed_joint_only_for_refund))
(define-fun is_qualifying_child () Bool
  (and qc_relationship_test qc_residence_test qc_age_test
       qc_support_test no_joint_return_test))

(define-fun qr_not_qc_test () Bool
  (not is_qc_of_any_taxpayer))
(define-fun qr_relationship_test () Bool
  (or is_specified_relative is_household_member_full_year))
(define-fun qr_income_test () Bool
  (< gross_income exemption_amount))
(define-fun qr_support_test () Bool
  (> taxpayer_support_ratio (/ 1.0 2.0)))
(define-fun is_qualifying_relative () Bool
  (and qr_not_qc_test qr_relationship_test qr_income_test qr_support_test))

(define-fun passes_exceptions () Bool
  (and no_joint_return_test
       (or is_us_citizen_or_national is_resident_us_canada_mexico)
       (not taxpayer_is_dependent_of_another)))

(define-fun is_dependent () Bool
  (and (or is_qualifying_child is_qualifying_relative)
       passes_exceptions))

; --- Scenario-specific facts (Alex's case) ---
(assert (= exemption_amount 4700))
(assert (= is_child_or_descendant false))           ; friend, not child/descendant
(assert (= is_sibling_or_descendant false))         ; friend, not sibling
(assert (= months_same_abode 8))                    ; lived together 8 months (not >6 for QC, but fails QR full-year)
(assert (= age 35))                                 ; age 35 — fails QC age test
(assert (= is_full_time_student false))
(assert (= is_permanently_disabled false))
(assert (= d_self_support_ratio (/ 35.0 100.0)))    ; Alex provides 35% own support
(assert (= filed_joint_return false))               ; no joint return
(assert (= filed_joint_only_for_refund false))
(assert (= is_us_citizen_or_national true))         ; U.S. citizen
(assert (= is_resident_us_canada_mexico false))
(assert (= taxpayer_is_dependent_of_another false)) ; Dave is not someone else's dependent
(assert (= is_specified_relative false))            ; friend ≠ enumerated relative under §152(d)(2)
(assert (= is_household_member_full_year false))    ; 8 months ≠ entire taxable year
(assert (= gross_income 3000))                      ; $3,000 < $4,700 exemption ✓
(assert (= taxpayer_support_ratio (/ 65.0 100.0))) ; Dave provides 65% of Alex's support ✓
(assert (= is_qc_of_any_taxpayer false))            ; Alex is not a QC of any taxpayer

; ============================================================
; Check 1: Is Alex a dependent? (LLM said YES — expect unsat, i.e., CANNOT be dependent)
; ============================================================
(push)
(assert is_dependent)
(check-sat)   ; Expected: unsat — confirms Alex is NOT a dependent
(pop)

; ============================================================
; Check 2: Assert NOT is_dependent (expect sat — consistent with facts)
; ============================================================
(assert (not is_dependent))
(check-sat)   ; Expected: sat
(get-value (is_qualifying_child))
(get-value (qc_relationship_test))   ; false — not a child/sibling
(get-value (qc_age_test))            ; false — age 35
(get-value (is_qualifying_relative))
(get-value (qr_relationship_test))   ; FALSE — key failure: not listed relative, not full-year member
(get-value (is_specified_relative))  ; false
(get-value (is_household_member_full_year)) ; false (8 months ≠ full year)
(get-value (qr_income_test))         ; true ($3,000 < $4,700)
(get-value (qr_support_test))        ; true (0.65 > 0.5)
(get-value (is_dependent))           ; false
