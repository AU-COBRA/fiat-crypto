Require Import Zpower ZArith.
Require Import List.
Require Import Crypto.Galois.BaseSystem Crypto.Galois.GaloisTheory.
Require Import Util.ListUtil.
Require Import VerdiTactics.
Open Scope Z_scope.

Module Type PseudoMersenneBaseParams (Import B:BaseCoefs) (Import M:Modulus).
  (* TODO: do we actually want B and M "up there" in the type parameters? I was
  * imagining writing something like "Paramter Module M : Modulus". *)

  Parameter k : Z.
  Parameter c : Z.
  Axiom modulus_pseudomersenne : primeToZ modulus = 2^k - c.

  Axiom base_matches_modulus :
    forall i j,
    (i   <  length base)%nat ->
    (j   <  length base)%nat ->
    (i+j >= length base)%nat->
    let b := nth_default 0 base in
    let r := (b i * b j)  /   (2^k * b (i+j-length base)%nat) in
              b i * b j = r * (2^k * b (i+j-length base)%nat).

  (* Probably implied by modulus_pseudomersenne. *)
  Axiom k_nonneg : 0 <= k.

End PseudoMersenneBaseParams.

Module Type GFrep (Import M:Modulus).
  Module Import GF := GaloisTheory M.
  (* TODO: could GF notation be in Galois, not GaloisTheory *)
  Parameter T : Type.
  Parameter fromGF : GF -> T.
  Parameter toGF : T -> GF.

  Parameter rep : T -> GF -> Prop.
  Local Notation "u '~=' x" := (rep u x) (at level 70).
  Axiom fromGF_rep : forall x, fromGF x ~= x.
  Axiom rep_toGF : forall u x, u ~= x -> toGF u = x.

  Parameter add : T -> T -> T.
  Axiom add_rep : forall u v x y, u ~= x -> v ~= y -> add u v ~= (x+y)%GF.

  Parameter sub : T -> T -> T.
  Axiom sub_rep : forall u v x y, u ~= x -> v ~= y -> sub u v ~= (x-y)%GF.

  Parameter mul : T -> T -> T.
  Axiom mul_rep : forall u v x y, u ~= x -> v ~= y -> mul u v ~= (x*y)%GF.

End GFrep.

Module GFPseudoMersenneBase (BC:BaseCoefs) (M:Modulus) (P:PseudoMersenneBaseParams BC M) <: GFrep M.
  Module Import GF := GaloisTheory M.
  Module EC <: BaseCoefs.
    Definition base := BC.base ++ (map (Z.mul (2^(P.k))) BC.base).
    
    Lemma base_positive : forall b, In b base -> b > 0.
    Proof.
      unfold base. intros.
      rewrite in_app_iff in H.
      destruct H. {
        apply BC.base_positive; auto.
      } {
        specialize BC.base_positive.
        induction BC.base; intros. {
          simpl in H; intuition.
        } {
          simpl in H.
          destruct H; subst.
          replace 0 with (2 ^ P.k * 0) by auto.
          apply (Zmult_gt_compat_l a 0 (2 ^ P.k)).
          rewrite Z.gt_lt_iff.
          apply Z.pow_pos_nonneg; intuition.
          pose proof P.k_nonneg; omega.
          apply H0; left; auto.
          apply IHl; auto.
          intros. apply H0; auto. right; auto.
        }
      }
    Qed.

    Lemma base_length_nonzero : (0 < length BC.base)%nat.
    Proof.
      assert (nth_default 0 BC.base 0 = 1) by (apply BC.b0_1).
      unfold nth_default in H.
      case_eq (nth_error BC.base 0); intros;
        try (rewrite H0 in H; omega).
      apply (nth_error_value_length _ 0 BC.base z); auto.
    Qed.

    Lemma b0_1 : forall x, nth_default x base 0 = 1.
    Proof.
      intros. unfold base.
      rewrite nth_default_app.
      assert (0 < length BC.base)%nat by (apply base_length_nonzero).
      destruct (lt_dec 0 (length BC.base)); try apply BC.b0_1; try omega.
    Qed.

    Lemma two_k_nonzero : 2^P.k <> 0.
      pose proof (Z.pow_eq_0 2 P.k P.k_nonneg).
      intuition.
    Qed.

    Lemma map_nth_default_base_high : forall n, (n < (length BC.base))%nat -> 
      nth_default 0 (map (Z.mul (2 ^ P.k)) BC.base) n =
      (2 ^ P.k) * (nth_default 0 BC.base n).
    Proof.
      intros.
      erewrite map_nth_default; auto.
    Qed.

    Lemma base_good_over_boundary : forall
      (i : nat)
      (l : (i < length BC.base)%nat)
      (j' : nat)
      (Hj': (i + j' < length BC.base)%nat)
      ,
      2 ^ P.k * (nth_default 0 BC.base i * nth_default 0 BC.base j') =
      2 ^ P.k * (nth_default 0 BC.base i * nth_default 0 BC.base j') /
      (2 ^ P.k * nth_default 0 BC.base (i + j')) *
      (2 ^ P.k * nth_default 0 BC.base (i + j'))
    .
    Proof. intros.
      remember (nth_default 0 BC.base) as b.
      rewrite Zdiv_mult_cancel_l by (exact two_k_nonzero).
      replace (b i * b j' / b (i + j')%nat * (2 ^ P.k * b (i + j')%nat))
       with  ((2 ^ P.k * (b (i + j')%nat * (b i * b j' / b (i + j')%nat)))) by ring.
      rewrite Z.mul_cancel_l by (exact two_k_nonzero).
      replace (b (i + j')%nat * (b i * b j' / b (i + j')%nat))
       with ((b i * b j' / b (i + j')%nat) * b (i + j')%nat) by ring.
      subst b.
      apply (BC.base_good i j'); omega.
    Qed.

    Lemma base_good :
      forall i j, (i+j < length base)%nat ->
      let b := nth_default 0 base in
      let r := (b i * b j) / b (i+j)%nat in
      b i * b j = r * b (i+j)%nat.
    Proof.
      intros.
      subst b. subst r.
      unfold base in *.
      rewrite app_length in H; rewrite map_length in H.
      repeat rewrite nth_default_app.
      destruct (lt_dec i (length BC.base));
        destruct (lt_dec j (length BC.base));
        destruct (lt_dec (i + j) (length BC.base));
        try omega.
      { (* i < length BC.base, j < length BC.base, i + j < length BC.base *)
        apply BC.base_good; auto.
      } { (* i < length BC.base, j < length BC.base, i + j >= length BC.base *)
        rewrite (map_nth_default _ _ _ _ 0) by omega.
        apply P.base_matches_modulus; omega.
      } { (* i < length BC.base, j >= length BC.base, i + j >= length BC.base *)
        do 2 rewrite map_nth_default_base_high by omega.
        remember (j - length BC.base)%nat as j'.
        replace (i + j - length BC.base)%nat with (i + j')%nat by omega.
        replace (nth_default 0 BC.base i * (2 ^ P.k * nth_default 0 BC.base j'))
           with (2 ^ P.k * (nth_default 0 BC.base i * nth_default 0 BC.base j'))
           by ring.
        eapply base_good_over_boundary; eauto; omega.
      } { (* i >= length BC.base, j < length BC.base, i + j >= length BC.base *)
        do 2 rewrite map_nth_default_base_high by omega.
        remember (i - length BC.base)%nat as i'.
        replace (i + j - length BC.base)%nat with (j + i')%nat by omega.
        replace (2 ^ P.k * nth_default 0 BC.base i' * nth_default 0 BC.base j)
           with (2 ^ P.k * (nth_default 0 BC.base j * nth_default 0 BC.base i'))
           by ring.
        eapply base_good_over_boundary; eauto; omega.
      }
    Qed.
  End EC.

  Module E := BaseSystem EC.
  Module B := BaseSystem BC.

  Definition T := B.digits.
  Local Hint Unfold T.
  Definition toGF (us : T) : GF := GF.inject (B.decode us).
  Local Hint Unfold toGF.
  Definition rep (us : T) (x : GF) := (length us <= length BC.base)%nat /\ toGF us = x.
  Local Notation "u '~=' x" := (rep u x) (at level 70).
  Local Hint Unfold rep.

  Lemma rep_toGF : forall us x, us ~= x -> toGF us = x.
  Proof.
    autounfold; intuition.
  Qed.

  Definition fromGF (x : GF) := B.encode x.

  Lemma fromGF_rep : forall x : GF, fromGF x ~= x.
  Proof.
    intros. unfold fromGF, rep.
    split. {
      unfold B.encode; simpl.
      apply EC.base_length_nonzero.
    } {
      unfold toGF.
      rewrite B.encode_rep.
      rewrite GF.inject_eq; auto.
    }
  Qed.

  Definition add (us vs : T) := B.add us vs.
  Lemma add_rep : forall u v x y, u ~= x -> v ~= y -> add u v ~= (x+y)%GF.
  Proof.
    autounfold; intuition. {
      unfold add.
      rewrite B.add_length_le_max.
      B.case_max; try rewrite Max.max_r; omega.
    }
    unfold toGF in *; unfold B.decode in *.
    rewrite B.add_rep.
    rewrite inject_distr_add.
    subst; auto.
  Qed.

  Definition sub (us vs : T) := B.sub us vs.
  Lemma sub_rep : forall u v x y, u ~= x -> v ~= y -> sub u v ~= (x-y)%GF.
  Proof.
    autounfold; intuition. {
      (*unfold add.
      rewrite B.add_length_le_max.
      B.case_max; try rewrite Max.max_r; omega.*)
      admit.
    }
    unfold toGF in *; unfold B.decode in *.
    rewrite B.sub_rep.
    rewrite inject_distr_sub.
    subst; auto.
  Qed.

  Lemma decode_short : forall (us : B.digits), 
    (length us <= length BC.base)%nat -> B.decode us = E.decode us.
  Proof.
    intros.
    unfold B.decode, B.decode', E.decode, E.decode'.
    rewrite combine_truncate_r.
    rewrite (combine_truncate_r us EC.base).
    f_equal; f_equal.
    unfold EC.base.
    rewrite firstn_app_inleft; auto; omega.
  Qed.

  Lemma extended_base_length:
      length EC.base = (length BC.base + length BC.base)%nat.
  Proof.
    unfold EC.base; rewrite app_length; rewrite map_length; auto.
  Qed.

  Lemma mul_rep_extended : forall (us vs : B.digits),
      (length us <= length BC.base)%nat -> 
      (length vs <= length BC.base)%nat ->
      B.decode us * B.decode vs = E.decode (E.mul us vs).
  Proof.
      intros. 
      rewrite E.mul_rep by (unfold EC.base; simpl_list; omega).
      f_equal; rewrite decode_short; auto.
  Qed.

  (* Converts from length of E.base to length of B.base by reduction modulo M.*)
  Definition reduce (us : E.digits) : B.digits :=
    let high := skipn (length BC.base) us in
    let low := firstn (length BC.base) us in
    let wrap := map (Z.mul P.c) high in
    B.add low wrap.

  Lemma Prime_nonzero: forall (p : Prime), primeToZ p <> 0.
  Proof.
    unfold Prime. intros.
    destruct p.
    simpl. intro.
    subst.
    apply Znumtheory.not_prime_0; auto.
  Qed.

  Lemma mod_mult_plus: forall a b c, (b <> 0) -> (a * b + c) mod b = c mod b.
  Proof.
    intros.
    rewrite Zplus_mod.
    rewrite Z.mod_mul; auto; simpl.
    rewrite Zmod_mod; auto.
  Qed.

  (* a = r + s(2^k) = r + s(2^k - c + c) = r + s(2^k - c) + cs = r + cs *) 
  Lemma pseudomersenne_add: forall x y, (x + ((2^P.k) * y)) mod modulus = (x + (P.c * y)) mod modulus.
  Proof.
    intros.
    replace (2^P.k) with (((2^P.k) - P.c) + P.c) by auto.
    rewrite Z.mul_add_distr_r.
    rewrite Zplus_mod.
    rewrite <- P.modulus_pseudomersenne.
    rewrite Z.mul_comm.
    rewrite mod_mult_plus; try apply Prime_nonzero.
    rewrite <- Zplus_mod; auto.
  Qed.

  Lemma extended_shiftadd: forall (us : E.digits), E.decode us =
      B.decode (firstn (length BC.base) us) +
      (2^P.k * B.decode (skipn (length BC.base) us)).
  Proof.
    intros.
    unfold B.decode, E.decode; rewrite <- B.mul_each_rep.
    replace B.decode' with E.decode' by auto.
    unfold EC.base.
    replace (map (Z.mul (2 ^ P.k)) BC.base) with (E.mul_each (2 ^ P.k) BC.base) by auto.
    rewrite E.base_mul_app.
    rewrite <- E.mul_each_rep; auto.
  Qed.

  Lemma reduce_rep : forall us, B.decode (reduce us) mod modulus = (E.decode us) mod modulus.
  Proof.
    intros.
    rewrite extended_shiftadd.
    rewrite pseudomersenne_add.
    unfold reduce.
    remember (firstn (length BC.base) us) as low.
    remember (skipn (length BC.base) us) as high.
    unfold B.decode.
    rewrite B.add_rep.
    replace (map (Z.mul P.c) high) with (B.mul_each P.c high) by auto.
    rewrite B.mul_each_rep; auto.
  Qed.

  Lemma reduce_length : forall us, 
      (length us <= length EC.base)%nat ->
      (length (reduce us) <= length (BC.base))%nat.
  Proof.
    intros.
    unfold reduce.
    remember (map (Z.mul P.c) (skipn (length BC.base) us)) as high.
    remember (firstn (length BC.base) us) as low.
    assert (length low >= length high)%nat. {
      subst. rewrite firstn_length.
      rewrite map_length.
      rewrite skipn_length.
      destruct (le_dec (length BC.base) (length us)). {
        rewrite Min.min_l by omega.
        rewrite extended_base_length in H. omega.
      } {
        rewrite Min.min_r by omega. omega.
      }
    }
    assert ((length low <= length BC.base)%nat)
      by (rewrite Heqlow; rewrite firstn_length; apply Min.le_min_l).
    assert (length high <= length BC.base)%nat 
      by (rewrite Heqhigh; rewrite map_length; rewrite skipn_length;
      rewrite extended_base_length in H; omega).
    rewrite B.add_trailing_zeros; auto.
    rewrite (B.add_same_length _ _ (length low)); auto.
    rewrite app_length.
    rewrite B.length_zeros; intuition.
  Qed.

  Definition mul (us vs : T) := reduce (E.mul us vs).
  Lemma mul_rep : forall u v x y, u ~= x -> v ~= y -> mul u v ~= (x*y)%GF.
  Proof.
    autounfold; unfold mul; intuition. {
      rewrite reduce_length; try omega.
      rewrite E.mul_length.
      rewrite extended_base_length.
      omega.
    }
    unfold mul.
    unfold toGF in *.
    rewrite inject_mod_eq.
    rewrite reduce_rep.
    rewrite E.mul_rep; try (rewrite extended_base_length; omega).
    rewrite <- inject_mod_eq.
    rewrite inject_distr_mul.
    subst; auto.
    replace (E.decode u) with (B.decode u) by (apply decode_short; omega).
    replace (E.decode v) with (B.decode v) by (apply decode_short; omega).
    auto.
  Qed.

  Definition add_to_nth n (x:Z) xs :=
    set_nth n (x + nth_default 0 xs n) xs.
  Hint Unfold add_to_nth.

  (* i must be in the domain of BC.base *)
  Definition cap i := 
    if eq_nat_dec i (pred (length BC.base))
    then (2^P.k) / nth_default 0 BC.base i
    else nth_default 0 BC.base (S i) / nth_default 0 BC.base i.

  Definition carry i us :=
    let di := nth_default 0 us      i in
    let us' := set_nth i (di mod cap i) us in
    if eq_nat_dec i (pred (length BC.base))
    then add_to_nth   0   (P.c * (di / cap i)) us'
    else add_to_nth (S i) (      (di / cap i)) us'.

  Lemma carry_length : forall i us,
    (length       us     <= length BC.base)%nat ->
    (length (carry i us) <= length BC.base)%nat.
  Proof.
    unfold carry, add_to_nth; intros; break_if; subst; repeat (rewrite length_set_nth); auto.
  Qed.

  Lemma fold_right_accumulate_init : forall v0 xs,
    fold_right B.accumulate v0 xs = v0 + fold_right B.accumulate 0 xs.
  Proof.
    induction xs; boring.
  Qed.

  Lemma Zplus_assoc_l : forall n m p, n + m + p = (n + m) + p.
  Proof.
    auto.
  Qed.

  Lemma In_app_nil : forall {T} l l' (a : T), l = l' ++ a :: nil -> In a l.
  Proof.
    boring.
  Qed.


  Lemma base_div_2k : forall l x, BC.base = l ++ x :: nil ->
    2 ^ P.k = (2 ^ P.k / x) * x.
  Proof.
    intros.
    rewrite Z.mul_comm.
    apply Z_div_exact_full_2; apply In_app_nil in H; try (apply BC.base_positive in H; omega).
  Admitted.

  Lemma nth_error_last : forall {T} l (x y : T),
    nth_error (l ++ x :: nil) (length l) = Some y -> y = x.
  Proof.
    intros.
    rewrite nth_error_app in H; break_if; try omega.
    replace (length l - length l)%nat with 0%nat in * by omega; simpl in *.
    unfold value in H; congruence.
  Qed.

  Lemma carry_rep : forall i us x
    (Hi : (i < length BC.base)%nat)
    (Hl : length us = length BC.base),
    us ~= x ->
    carry i us ~= x.
  Proof.
    split; [pose proof carry_length; boring|].
    unfold rep, toGF, B.decode, B.decode', B.accumulate,
      carry, add_to_nth, cap, nth_default in *; intros.
    pose proof (list012 BC.base).
    pose proof (list012 us).
    repeat break_or_hyp;
        break_exists; subst;
        match goal with [H: BC.base =_ |- _] => rewrite H in * end;
        distr_length. {
      intuition; simpl in *.
      destruct i; try omega.
      subst; galois.
      replace x0 with 1 by (pose proof B.base_eq_1cons; congruence).
      rewrite Zdiv_1_r.
      replace ((P.c * (x1 / (2 ^ P.k)) + x1 mod (2 ^ P.k)) * 1 + 0)
        with (x1 mod (2 ^ P.k) + (P.c * (x1 / (2 ^ P.k))))
        by ring.
      rewrite <- pseudomersenne_add; f_equal; ring_simplify.
      rewrite Z.add_comm; symmetry.
      apply Z_div_mod_eq.
      admit.
    } {
      break_if. {
        intuition; subst x.
        repeat (rewrite combine_set_nth).
        nth_inbounds.
        nth_inbounds.
        nth_inbounds.
        nth_inbounds.
        nth_inbounds; [|distr_length; eapply NPeano.Nat.min_case; omega].
        nth_inbounds; [|distr_length; eapply NPeano.Nat.min_case; omega].
        unfold splice_nth.

        rewrite firstn0, app_nil_l.
        rewrite (skipn_all (S i)) by (distr_length; eapply NPeano.Nat.min_case; omega).
        rewrite fold_right_cons.
        replace x0 with 1 by (pose proof B.base_eq_1cons; congruence).
        rewrite firstn_combine.
        rewrite skipn_app_inleft by (distr_length; repeat (eapply NPeano.Nat.min_case); subst; omega).
        rewrite skipn_combine.
        rewrite fold_right_app.
        
        subst i; rewrite plus_comm; simpl.
        do 2 rewrite firstn_app_sharp by omega.
        rewrite combine_app_samelength by omega.
        rewrite fold_right_app; simpl.
        fold B.accumulate.
        rewrite fold_right_accumulate_init.
        rewrite (fold_right_accumulate_init (x5*x2+0)).

        galois.
        rewrite Zplus_assoc.
        rewrite Zplus_assoc.
        rewrite Zplus_mod.
        rewrite Zplus_assoc.
        rewrite Zplus_assoc.
        rewrite (Zplus_mod (x3 * 1 + x5 * x2 + 0)).
        f_equal.
        rewrite Z.add_cancel_r.
        assert (x = x0) as A0 by admit.
        assert (x = 1). {
          replace x with (nth_default 0 BC.base 0); try apply BC.b0_1.
          rewrite H0, A0; auto.
        }
        assert (x6 = x5). {
          apply (nth_error_last (x3 :: x4)); auto.
          replace (length (x3 :: x4)) with (length x1 + 1)%nat; auto.
          replace (length (x3 :: x4)) with (length x4 + 1)%nat by distr_length.
          omega.
        }
        assert (x7 = x2). {
          apply (nth_error_last (x0 :: x1)); auto.
          replace (length (x0 :: x1)) with (length x1 + 1)%nat by distr_length; auto.
        }
        assert (x8 = x3). {
          replace (length x1 + 1)%nat with (S (length x1))%nat in H4 by omega.
          simpl in H4; unfold value in *; congruence.
        }
        assert ((x3 * 1 + x5 * x2 + 0) =
          x3 + (x5 mod (2 ^ P.k / x2))* x2 + (x5 / (2 ^ P.k / x2) * (2 ^ P.k))) as A1. {
          ring_simplify.
          rewrite Zplus_assoc_reverse.
          rewrite (Z.add_cancel_l _ _ x3).
          rewrite (base_div_2k (x0 :: x1) x2) at 3; auto.
          rewrite Z.mul_assoc.
          do 2 rewrite <- (Z.mul_comm x2).
          rewrite <- (Zmult_plus_distr_r).
          f_equal.
          rewrite Zplus_comm.
          rewrite Z.mul_comm.
          rewrite <- Z.div_mod; auto.
          assert (2 ^ P.k / x2 <> 0) by admit; auto.
        }
        rewrite A1; subst.
        rewrite (Z.mul_comm _ (2 ^ P.k)).
        rewrite pseudomersenne_add; subst.
        apply Zmod_eq; ring_simplify; auto.
      }
  Abort.

End GFPseudoMersenneBase.
