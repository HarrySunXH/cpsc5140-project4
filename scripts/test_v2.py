from z3 import *

v = {
    'is_child_or_descendant': Bool('is_child_or_descendant'),
    'is_sibling_or_descendant': Bool('is_sibling_or_descendant'),
    'months_same_abode': Int('months_same_abode'),
    'age': Int('age'),
    'is_full_time_student': Bool('is_full_time_student'),
    'is_permanently_disabled': Bool('is_permanently_disabled'),
    'd_self_support_ratio': Real('d_self_support_ratio'),
    'filed_joint_return': Bool('filed_joint_return'),
    'filed_joint_only_for_refund': Bool('filed_joint_only_for_refund'),
    'is_us_citizen_or_national': Bool('is_us_citizen_or_national'),
    'is_resident_us_canada_mexico': Bool('is_resident_us_canada_mexico'),
    'taxpayer_is_dependent_of_another': Bool('taxpayer_is_dependent_of_another'),
    'is_parent_or_ancestor': Bool('is_parent_or_ancestor'),
    'is_stepparent': Bool('is_stepparent'),
    'is_niece_or_nephew': Bool('is_niece_or_nephew'),
    'is_aunt_or_uncle': Bool('is_aunt_or_uncle'),
    'is_in_law': Bool('is_in_law'),
    'is_household_member_full_year': Bool('is_household_member_full_year'),
    'gross_income': Int('gross_income'),
    'exemption_amount': Int('exemption_amount'),
    'taxpayer_support_ratio': Real('taxpayer_support_ratio'),
    'is_qc_of_any_taxpayer': Bool('is_qc_of_any_taxpayer'),
}

no_jt = Or(Not(v['filed_joint_return']), v['filed_joint_only_for_refund'])
is_qc = And(
    Or(v['is_child_or_descendant'], v['is_sibling_or_descendant']),
    v['months_same_abode'] > 6,
    Or(v['age'] < 19, And(v['age'] < 24, v['is_full_time_student']), v['is_permanently_disabled']),
    Not(v['d_self_support_ratio'] > 0.5),
    no_jt)
is_qr = And(
    Not(v['is_qc_of_any_taxpayer']),
    Or(v['is_child_or_descendant'], v['is_sibling_or_descendant'],
       v['is_parent_or_ancestor'], v['is_stepparent'],
       v['is_niece_or_nephew'], v['is_aunt_or_uncle'],
       v['is_in_law'], v['is_household_member_full_year']),
    v['gross_income'] < v['exemption_amount'],
    v['taxpayer_support_ratio'] > 0.5)
exc = And(no_jt,
          Or(v['is_us_citizen_or_national'], v['is_resident_us_canada_mexico']),
          Not(v['taxpayer_is_dependent_of_another']))
is_dep = And(Or(is_qc, is_qr), exc)

domain = [
    v['exemption_amount'] == 4700,
    And(v['months_same_abode'] >= 0, v['months_same_abode'] <= 12),
    v['age'] >= 0,
    And(v['d_self_support_ratio'] >= 0, v['d_self_support_ratio'] <= 1),
    And(v['taxpayer_support_ratio'] >= 0, v['taxpayer_support_ratio'] <= 1),
    v['gross_income'] >= 0]

all_false_new = [
    v['is_parent_or_ancestor'] == False,
    v['is_stepparent'] == False,
    v['is_niece_or_nephew'] == False,
    v['is_aunt_or_uncle'] == False,
    v['is_in_law'] == False]

def run(facts, assert_dep):
    s = Solver()
    s.add(domain)
    s.add(facts)
    s.add(is_dep if assert_dep else Not(is_dep))
    return s.check()

tests = [
    ("1. Sanity check (any dependent)", [], True),
    ("2. Emma (QC: daughter age 10)", [
        v['is_child_or_descendant'] == True, v['is_sibling_or_descendant'] == False,
        v['months_same_abode'] == 12, v['age'] == 10,
        v['is_full_time_student'] == False, v['is_permanently_disabled'] == False,
        v['d_self_support_ratio'] == 0.0, v['filed_joint_return'] == False,
        v['filed_joint_only_for_refund'] == False, v['is_us_citizen_or_national'] == True,
        v['is_resident_us_canada_mexico'] == False,
        v['taxpayer_is_dependent_of_another'] == False,
        v['is_household_member_full_year'] == True, v['gross_income'] == 0,
        v['taxpayer_support_ratio'] == 1.0, v['is_qc_of_any_taxpayer'] == False
    ] + all_false_new, True),
    ("3. Robert (NOT dependent: colleague)", [
        v['is_child_or_descendant'] == False, v['is_sibling_or_descendant'] == False,
        v['months_same_abode'] == 3, v['age'] == 45,
        v['is_full_time_student'] == False, v['is_permanently_disabled'] == False,
        v['d_self_support_ratio'] == 1.0, v['filed_joint_return'] == False,
        v['filed_joint_only_for_refund'] == False, v['is_us_citizen_or_national'] == True,
        v['is_resident_us_canada_mexico'] == False,
        v['taxpayer_is_dependent_of_another'] == False,
        v['is_household_member_full_year'] == False, v['gross_income'] == 60000,
        v['taxpayer_support_ratio'] == 0.0, v['is_qc_of_any_taxpayer'] == False
    ] + all_false_new, False),
    ("4. Maya (borderline QC: student, 50% support)", [
        v['is_child_or_descendant'] == True, v['is_sibling_or_descendant'] == False,
        v['months_same_abode'] == 7, v['age'] == 22,
        v['is_full_time_student'] == True, v['is_permanently_disabled'] == False,
        v['d_self_support_ratio'] == RealVal('1/2'), v['filed_joint_return'] == False,
        v['filed_joint_only_for_refund'] == False, v['is_us_citizen_or_national'] == True,
        v['is_resident_us_canada_mexico'] == False,
        v['taxpayer_is_dependent_of_another'] == False,
        v['is_household_member_full_year'] == False, v['gross_income'] == 4600,
        v['taxpayer_support_ratio'] == RealVal('1/2'), v['is_qc_of_any_taxpayer'] == False
    ] + all_false_new, True),
    ("5. Ruth (QR via parent: age 72, lives in nursing home)", [
        v['is_child_or_descendant'] == False, v['is_sibling_or_descendant'] == False,
        v['months_same_abode'] == 0, v['age'] == 72,
        v['is_full_time_student'] == False, v['is_permanently_disabled'] == False,
        v['d_self_support_ratio'] == 0.0, v['filed_joint_return'] == False,
        v['filed_joint_only_for_refund'] == False, v['is_us_citizen_or_national'] == True,
        v['is_resident_us_canada_mexico'] == False,
        v['taxpayer_is_dependent_of_another'] == False,
        v['is_parent_or_ancestor'] == True, v['is_stepparent'] == False,
        v['is_niece_or_nephew'] == False, v['is_aunt_or_uncle'] == False,
        v['is_in_law'] == False,
        v['is_household_member_full_year'] == False, v['gross_income'] == 0,
        v['taxpayer_support_ratio'] == RealVal('4/5'), v['is_qc_of_any_taxpayer'] == False
    ], True),
    ("6. Alex (NOT dependent: friend, 8 months, Part B)", [
        v['is_child_or_descendant'] == False, v['is_sibling_or_descendant'] == False,
        v['months_same_abode'] == 8, v['age'] == 35,
        v['is_full_time_student'] == False, v['is_permanently_disabled'] == False,
        v['d_self_support_ratio'] == RealVal('35/100'), v['filed_joint_return'] == False,
        v['filed_joint_only_for_refund'] == False, v['is_us_citizen_or_national'] == True,
        v['is_resident_us_canada_mexico'] == False,
        v['taxpayer_is_dependent_of_another'] == False,
        v['is_household_member_full_year'] == False, v['gross_income'] == 3000,
        v['taxpayer_support_ratio'] == RealVal('65/100'), v['is_qc_of_any_taxpayer'] == False
    ] + all_false_new, False),
]

print("=== part1_cot.smt2 v2 — Full Test Suite ===")
all_pass = True
for name, facts, expect_dep in tests:
    r = run(facts, expect_dep)
    ok = str(r) == "sat"
    all_pass = all_pass and ok
    print("  {}: {} {}".format(name, r, "OK" if ok else "FAIL"))
print("\nAll tests passed: {}".format(all_pass))
