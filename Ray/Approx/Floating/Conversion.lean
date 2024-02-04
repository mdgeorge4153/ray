import Ray.Approx.Floating.Basic
import Ray.Approx.Floating.Neg
import Ray.Approx.Floating.Standardization
import Ray.Approx.Rat

open Pointwise

/-!
## Conversion from `ℕ`, `ℤ`, `ℚ`, `Float` to `Floating`
-/

open Set
open scoped Real
namespace Floating

/-!
## Normalization given `n ∈ [2^62, 2^63]`
-/

/-- A normalized `n, s` pair ready for conversion to `Floating`  -/
structure Convert where
  n : ℕ
  s : ℤ
  norm : n ∈ Ico (2^62) (2^63)

noncomputable def Convert.val (x : Convert) : ℝ := x.n * 2^(x.s - 2^63)

lemma Convert.n_mod (x : Convert) : x.n % 2^64 = x.n := by
  rw [Nat.mod_eq_of_lt]
  have h := x.norm
  simp only [mem_Ico] at h
  norm_num only at h ⊢
  omega

/-- Build a `Floating` out of `n * 2^(s - 2^63)`, rounding if required -/
@[irreducible, pp_dot] def Convert.finish (x : Convert) (up : Bool) : Floating :=
  if s0 : x.s < 0 then bif up then min_norm else 0 else
  if 2^64 ≤ x.s then nan else
  have e : x.n % 2^64 = x.n := x.n_mod
  { n := ⟨x.n⟩
    s := x.s
    zero_same := by
      intro n0; contrapose n0
      simp only [Int64.ext_iff, Int64.n_zero, UInt64.eq_zero_iff_toNat_eq_zero, UInt64.toNat_cast,
        UInt64.size_eq_pow, e]
      have h := x.norm
      norm_num [mem_Ico] at h
      omega
    nan_same := by
      intro nm; contrapose nm
      simp only [Int64.ext_iff, Int64.n_min, UInt64.eq_iff_toNat_eq, UInt64.toNat_cast,
        UInt64.size_eq_pow, UInt64.toNat_2_pow_63, e]
      have h := x.norm
      norm_num [mem_Ico] at h ⊢
      omega
    norm := by
      intro _ _ _
      have h := x.norm
      simp only [mem_Ico] at h
      rw [Int64.abs_eq_self']
      · simp only [UInt64.le_iff_toNat_le, up62, UInt64.toNat_cast, UInt64.size_eq_pow, e, x.norm.1]
      · simp only [Int64.isNeg_eq_le, UInt64.toNat_cast, UInt64.size_eq_pow, e,
          decide_eq_false_iff_not, not_le, x.norm.2] }

/-- Build a `Floating` out of `n * 2^(s - 2^63)`, rounding if required -/
@[irreducible] def convert_tweak (n : ℕ) (s : ℤ) (norm : n ∈ Icc (2^62) (2^63)) : Convert :=
  if e : n = 2^63 then ⟨2^62, s + 1, by decide⟩
  else ⟨n, s, norm.1, norm.2.lt_of_ne e⟩

/-- `Convert.finish` is correct -/
lemma Convert.approx_finish (x : Convert) (up : Bool) :
    x.val ∈ rounds (approx (x.finish up)) !up := by
  rw [finish, val]
  by_cases s0 : x.s < 0
  · simp only [s0, bif_eq_if, dite_eq_ite, ite_true]
    induction up
    · simp only [ite_false, ne_eq, zero_ne_nan, not_false_eq_true, approx_eq_singleton, val_zero,
        Bool.not_false, mem_rounds_singleton, gt_iff_lt, two_zpow_pos, mul_nonneg_iff_of_pos_right,
        Nat.cast_nonneg, ite_true]
    · simp only [ite_true, ne_eq, min_norm_ne_nan, not_false_eq_true, approx_eq_singleton,
        val_min_norm, Bool.not_true, mem_rounds_singleton, ite_false]
      refine le_trans (mul_le_mul_of_nonneg_right (Nat.cast_le.mpr x.norm.2.le) two_zpow_pos.le) ?_
      simp only [Nat.cast_pow, Nat.cast_ofNat, ne_eq, OfNat.ofNat_ne_zero, not_false_eq_true,
        pow_mul_zpow]
      exact zpow_le_of_le (by norm_num) (by omega)
  simp only [s0, dite_eq_ite, ite_false]
  by_cases s1 : 2^64 ≤ x.s
  · simp only [s1, ite_true, approx_nan, rounds_univ, mem_univ]
  have n1' : x.n < 2^64 := lt_trans x.norm.2 (by norm_num)
  have n1 : (x.n : ℤ) < 2^64 := lt_trans (Nat.cast_lt.mpr x.norm.2) (by norm_num)
  have xne : (x.n : UInt64) ≠ 2^63 := by
    simp only [ne_eq, UInt64.eq_iff_toNat_eq, UInt64.toNat_cast, UInt64.size_eq_pow,
      UInt64.toNat_2_pow_63, Nat.mod_eq_of_lt n1']
    exact x.norm.2.ne
  have n0 : (⟨↑x.n⟩ : Int64).isNeg = false := by
    simp only [Int64.isNeg_eq_le, UInt64.toNat_cast, UInt64.size_eq_pow, Nat.mod_eq_of_lt n1',
      decide_eq_false_iff_not, not_le]
    exact x.norm.2
  simp only [approx, s1, ite_false, ext_iff, n_nan, Int64.ext_iff, Int64.n_min, s_nan, xne,
    false_and]
  simp only [not_le, not_lt] at s1 s0
  rw [Floating.val]
  simp only [Int64.coe_of_nonneg n0, UInt64.toNat_cast, Int.ofNat_emod,
    UInt64.toInt, UInt64.toInt_intCast, Int.emod_eq_of_lt s0 s1, mem_rounds_singleton,
    Bool.not_eq_true', gt_iff_lt, two_zpow_pos, mul_le_mul_right, UInt64.size_eq_pow, Nat.cast_pow,
    Nat.cast_two, Int.emod_eq_of_lt (Nat.cast_nonneg _) n1, Int.cast_Nat_cast, le_refl, ite_self]

/-- `convert_tweak` is correct -/
lemma val_convert_tweak (n : ℕ) (s : ℤ) (norm : n ∈ Icc (2^62) (2^63)) :
    (convert_tweak n s norm).val = n * 2^(s - 2^63) := by
  rw [Convert.val, convert_tweak]
  by_cases e : n = 2^63
  · simp only [e, dite_true, Nat.cast_pow, Nat.cast_ofNat, ne_eq, OfNat.ofNat_ne_zero,
      not_false_eq_true, pow_mul_zpow, gt_iff_lt, zero_lt_two, OfNat.ofNat_ne_one, zpow_inj]
    omega
  · simp only [e, dite_false]

/-- Prove a `(convert_tweak _ _ _).finish _` call is correct, in context. -/
lemma approx_convert {a : ℝ} {n : ℕ} {s : ℤ} {norm : n ∈ Icc (2^62) (2^63)} {up : Bool}
    (an : if up then a ≤ ↑n * 2^(s - 2^63) else ↑n * 2^(s - 2^63) ≤ a) :
    a ∈ rounds (approx ((convert_tweak n s norm).finish up)) !up := by
  by_cases cn : (convert_tweak n s norm).finish up = nan
  · simp only [cn, approx_nan, rounds_univ, mem_univ]
  have h := Convert.approx_finish (convert_tweak n s norm) up
  simp only [val_convert_tweak, approx, cn, ite_false, mem_rounds_singleton,
    Bool.not_eq_true'] at h ⊢
  induction up
  · exact le_trans h an
  · exact le_trans an h

/-!
## Conversion from `ℕ`
-/

/-- Conversion from `ℕ` to `Floating`, rounding up or down -/
@[irreducible] def ofNat (n : ℕ) (up : Bool) : Floating :=
  let t := n.log2
  -- If `t ≤ 62`, use `of_ns` to shift left.  If `t > 62`, shift right.
  if t62 : t ≤ 62 then of_ns n (2^63) else
  let s := t - 62
  let x := convert_tweak (n.shiftRightRound s up) (s + 2^63) (by
    simp only [Nat.shiftRightRound_eq_rdiv, mem_Icc]
    by_cases n0 : n = 0
    · simp only [n0, Nat.log2_zero, zero_le, not_true_eq_false] at t62
    constructor
    · apply Nat.le_rdiv_of_mul_le (pow_pos (by norm_num) _)
      rw [←pow_add, ←Nat.le_log2 n0]
      omega
    · refine Nat.rdiv_le_of_le_mul (le_trans Nat.lt_log2_self.le ?_)
      rw [←pow_add]
      exact pow_le_pow_right (by norm_num) (by omega))
  x.finish up

/-- Conversion from `ℕ` literals to `Floating`, rounding down arbitrarily.
    Use `Interval.ofNat` if you want something trustworthy (it rounds both ways). -/
instance {n : ℕ} [n.AtLeastTwo] : OfNat Floating n := ⟨.ofNat n false⟩

/-- `ofNat` rounds the desired way -/
lemma approx_ofNat (n : ℕ) (up : Bool) : ↑n ∈ rounds (approx (.ofNat n up : Floating)) !up := by
  have t0 : (2:ℝ) ≠ 0 := by norm_num
  have e63 : (2^63 : UInt64).toInt = 2^63 := by decide
  rw [ofNat]
  simp only
  by_cases n62 : n.log2 ≤ 62
  · have lt : n < 2^63 :=
      lt_of_lt_of_le Nat.lt_log2_self (pow_le_pow_right (by norm_num) (by omega))
    have nn : (n : Int64) ≠ Int64.min := by
      simp only [ne_eq, Int64.ext_iff, Int64.ofNat_eq_coe, Int64.n_min, UInt64.eq_iff_toNat_eq,
        UInt64.toNat_cast, UInt64.size_eq_pow, UInt64.toNat_2_pow_63]
      norm_num only at lt ⊢
      rw [Nat.mod_eq_of_lt (by omega)]
      omega
    simp only [n62, tsub_eq_zero_of_le, CharP.cast_eq_zero, dite_true, approx, of_ns_eq_nan_iff,
      nn, if_false, val_of_ns nn, mem_rounds_singleton, e63, sub_self, Bool.not_eq_true', zpow_zero,
      mul_one, Int64.toInt_ofNat lt, Int.cast_Nat_cast, le_refl, ite_self]
  · simp only [n62, dite_false]
    apply approx_convert
    simp only [Nat.shiftRightRound_eq_rdiv]
    induction up
    · simp only [ite_false]
      refine le_trans (mul_le_mul_of_nonneg_right Nat.rdiv_le two_zpow_pos.le) ?_
      simp only [Nat.cast_pow, Nat.cast_ofNat, div_mul_eq_mul_div, mul_div_assoc, zpow_div_pow t0]
      apply mul_le_of_le_one_right (Nat.cast_nonneg _)
      exact zpow_le_one_of_nonpos (by norm_num) (by omega)
    · simp only [ite_true]
      refine le_trans ?_ (mul_le_mul_of_nonneg_right Nat.le_rdiv two_zpow_pos.le)
      simp only [Nat.cast_pow, Nat.cast_ofNat, div_mul_eq_mul_div, mul_div_assoc, zpow_div_pow t0]
      apply le_mul_of_one_le_right (Nat.cast_nonneg _)
      exact one_le_zpow_of_nonneg (by norm_num) (by omega)

/-- `approx_ofNat`, down version -/
lemma ofNat_le {n : ℕ} (h : (ofNat n false) ≠ nan) : (ofNat n false).val ≤ n := by
  simpa only [approx, h, ite_false, Bool.not_false, mem_rounds_singleton, ite_true] using
    approx_ofNat n false

/-- `approx_ofNat`, up version -/
lemma le_ofNat {n : ℕ} (h : (ofNat n true) ≠ nan) : n ≤ (ofNat n true).val := by
  simpa only [approx, h, ite_false, Bool.not_true, mem_rounds_singleton] using approx_ofNat n true

/-!
## Conversion from `ℤ`
-/

/-- Conversion from `ℤ` -/
@[irreducible] def ofInt (n : ℤ) (up : Bool) : Floating :=
  bif n < 0 then -ofNat (-n).toNat !up else .ofNat n.toNat up

/-- `ofInt` rounds the desired way -/
lemma approx_ofInt (n : ℤ) (up : Bool) : ↑n ∈ rounds (approx (ofInt n up)) !up := by
  rw [ofInt]
  by_cases n0 : n < 0
  · have e : (n : ℝ) = -↑(-n).toNat := by
      have e : (n : ℝ) = -↑(-n) := by simp only [Int.cast_neg, neg_neg]
      have le : 0 ≤ -n := by omega
      rw [e, ←Int.toNat_of_nonneg le, neg_inj, Int.cast_ofNat]
      rw [Int.toNat_of_nonneg le]
    simpa only [e, n0, decide_True, cond_true, approx_neg, rounds_neg, Bool.not_not, mem_neg,
      neg_neg] using approx_ofNat (-n).toNat (!up)
  · have e : (n : ℝ) = ↑n.toNat := by
      rw [←Int.toNat_of_nonneg (not_lt.mp n0), Int.cast_ofNat]
      simp only [Int.toNat_of_nonneg (not_lt.mp n0)]
    simp only [e, n0, decide_False, cond_false, approx_ofNat]

/-- `approx_ofInt`, down version -/
lemma ofInt_le {n : ℤ} (h : (ofInt n false) ≠ nan) : (ofInt n false).val ≤ n := by
  simpa only [approx, h, ite_false, Bool.not_false, mem_rounds_singleton, ite_true] using
    approx_ofInt n false

/-- `approx_ofInt`, up version -/
lemma le_ofInt {n : ℤ} (h : (ofInt n true) ≠ nan) : n ≤ (ofInt n true).val := by
  simpa only [approx, h, ite_false, Bool.not_true, mem_rounds_singleton] using
    approx_ofInt n true

#exit

/-!
## Conversion from `ℚ`
-/

/-- Conversion from `ℚ`, rounding up or down -/
@[irreducible] def ofRat (x : ℚ) (up : Bool) : Floating :=
  let r := x.log2
  sorry
  /-
  -- Our rational is `x = a / b`.  The `Int64` result `y` should satisfy
  --   `y * 2^s ≈ a / b`
  -- and should be normalized as
  --   `log2 |y| = 62`
  --   `log2 |y| = 62`
  -- We can do this via an exact integer division if we merge `2^s` into either `a` or `b`.
  -- This might be expensive if `s` is large, but we can worry about that later.
  let (a,b) := bif s.isNeg then (x.num >>> ↑s, x.den) else (x.num, x.den <<< s.n.toNat)
  let d := a.rdiv b up
  bif |d| < 2^63 then ⟨d⟩ else nan
  -/

/-- `ofRat` rounds the desired way -/
lemma approx_ofRat (x : ℚ) (up : Bool) : ↑x ∈ rounds (approx (ofRat x up)) !up := by
  by_cases n : ofRat x up = nan
  · simp only [n, approx_nan, rounds_univ, mem_univ]
  rw [approx_eq_singleton n, ofRat]
  by_cases sn : s.isNeg
  · simp only [Bool.cond_decide, sn, cond_true, neg_neg, Bool.cond_self]
    by_cases dn : |Int.rdiv (x.num >>> ↑s) ↑x.den up| < 2 ^ 63
    · simp only [dn, ite_true, Int64.toInt_ofInt dn, val]
      rw [←Int64.coe_lt_zero_iff] at sn
      generalize (s : ℤ) = s at sn dn
      have e : s = -(-s).toNat := by rw [Int.toNat_of_nonneg (by omega), neg_neg]
      rw [e] at dn ⊢; clear e sn
      generalize (-s).toNat = s at dn
      simp only [Int.shiftRight_neg, Int.shiftLeft_eq_mul_pow, zpow_neg,
        mul_inv_le_iff two_pow_pos, Nat.cast_pow, Nat.cast_ofNat, zpow_coe_nat, ge_iff_le] at dn ⊢
      nth_rw 1 [←Rat.num_div_den x]
      simp only [Rat.cast_div, Rat.cast_coe_int, Rat.cast_coe_nat, ←mul_div_assoc,
        Int64.toInt_ofInt dn]
      induction up
      · simp only [Bool.not_false, mem_rounds_singleton, mul_inv_le_iff two_pow_pos, ←
          mul_div_assoc, mul_comm _ (x.num : ℝ), ite_true, ge_iff_le]
        refine le_trans Int.rdiv_le ?_
        simp only [Int.cast_mul, Int.cast_pow, Int.int_cast_ofNat, le_refl]
      · simp only [rounds, ← div_eq_mul_inv, mem_singleton_iff, Bool.not_true, ite_false,
          exists_eq_left, le_div_iff two_pow_pos, mem_setOf_eq, ge_iff_le]
        refine le_trans (le_of_eq ?_) Int.le_rdiv
        simp only [div_eq_mul_inv, Int.cast_mul, Int.cast_pow, Int.int_cast_ofNat]; ring_nf
    · rw [ofRat, sn, cond_true] at n
      simp only [bif_eq_if, dn, decide_False, ite_false, not_true_eq_false] at n
  · simp only [Bool.cond_decide, sn, cond_false, val._eq_1, mem_rounds_singleton,
      Bool.not_eq_true']
    simp only [Bool.not_eq_true] at sn
    by_cases dn : |Int.rdiv x.num (x.den <<< s.n.toNat) up| < 2 ^ 63
    · simp only [dn, ite_true, Int64.toInt_of_isNeg_eq_false sn, zpow_ofNat]
      rw [Int64.toInt_ofInt dn, Nat.shiftLeft_eq]
      generalize s.n.toNat = s; clear dn
      induction up
      · simp only [ite_true]
        refine le_trans (mul_le_mul_of_nonneg_right Int.rdiv_le two_pow_pos.le) (le_of_eq ?_)
        simp only [div_eq_mul_inv, Nat.cast_mul, mul_inv, Nat.cast_pow, Nat.cast_two,  mul_assoc,
          inv_mul_cancel two_pow_pos.ne', mul_one]
        nth_rw 3 [←Rat.num_div_den x]
        simp only [← div_eq_mul_inv, Rat.cast_div, Rat.cast_coe_int, Rat.cast_coe_nat]
      · simp only [ite_false]
        refine le_trans (le_of_eq ?_) (mul_le_mul_of_nonneg_right Int.le_rdiv two_pow_pos.le)
        simp only [div_eq_mul_inv, Nat.cast_mul, mul_inv, Nat.cast_pow, Nat.cast_two,  mul_assoc,
          inv_mul_cancel two_pow_pos.ne', mul_one]
        nth_rw 1 [←Rat.num_div_den x]
        simp only [← div_eq_mul_inv, Rat.cast_div, Rat.cast_coe_int, Rat.cast_coe_nat]
    · rw [ofRat, sn, cond_false] at n
      simp only [Bool.cond_decide, dn, ite_false, not_true_eq_false] at n

/-- `approx_ofRat`, down version -/
lemma ofRat_le {x : ℚ} (h : ofRat x false ≠ nan) : (.ofRat x false).val ≤ x := by
  simpa only [approx, h, ite_false, Bool.not_false, mem_rounds_singleton, ite_true] using
    approx_ofRat x false (s := s)

/-- `approx_ofRat`, up version -/
lemma le_ofRat {x : ℚ} (h : ofRat x true ≠ nan) : x ≤ (ofRat x true).val := by
  simpa only [approx, h, ite_false, Bool.not_true, mem_rounds_singleton] using
    approx_ofRat x true (s := s)

#exit

/-!
## Conversion from `Float`
-/

/-- Convert a `Float` to `Floating` -/
@[irreducible] def ofFloat (x : Float) : Floating :=
  let xs := x.abs.scaleB (-s)
  bif xs ≤ 0.5 then 0 else
  let y : Int64 := ⟨xs.toUInt64⟩
  bif y == 0 || y.isNeg then nan else
  ⟨bif x < 0 then -y else y⟩
