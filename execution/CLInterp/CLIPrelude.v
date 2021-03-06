Require Import FunctionalExtensionality.
Require Import List.
Import ListNotations.
From Coq Require Import ZArith.
Require Import Basics.
Require Import Automation.
Require Import Monads.
Require Import Blockchain.
Require Import Extras.
Require Import Containers.


Require Import Serializable.
From RecordUpdate Require Import RecordUpdate.
Import RecordSetNotations.

Open Scope Z.
(** Basic datatypes needed for CL and CLVM *)
Inductive Val : Set := BVal : bool -> Val | ZVal : Z -> Val.
Parameter BoolObs : Z.
Parameter ZObs : Z.
Parameter TVar : Set.

Inductive Asset :=
| DKK
| USD.

Definition eqbA (a1 : Asset) (a2 : Asset)  : bool :=
  match a1, a2 with
  | DKK, DKK => true
  | USD, USD => true
  | _,_ => false
  end.

Inductive Party :=
| PartyN : nat -> Party.

Inductive ObsLabel : Set := LabZ (l: Z) | LabB (l: Z).

Definition to_sum (t : ObsLabel) :=
  match t with
  | LabZ l => inl l
  | LabB l => inr l
  end.

Definition of_sum (zz : Z + Z) : ObsLabel :=
  match zz with
  | inl l => LabZ l
  | inr r => LabB r
  end.

(** TODO: 
Proof of decideable equality and countability datatypes, needed for serialization
REFACTOR Proof of countable and decideable equality from serialization to nat *)

Lemma of_to_sum t : of_sum (to_sum t) = t.
Proof.
  now destruct t.
Qed.

Lemma to_sum_injective x y :
  to_sum x = to_sum y ->
  x = y.
Proof.
  intros eq.
  assert (of_sum (to_sum x) = of_sum (to_sum y)) by congruence.
  now rewrite !of_to_sum in H.
Qed.

Instance Obs_eqdec : stdpp.base.EqDecision ObsLabel.
Proof.
  intros x y.
  unfold base.Decision.
  destruct (stdpp.base.decide (to_sum x = to_sum y)).
  - left; apply to_sum_injective; auto.
  - right; intros xney.
    subst x.
    congruence.
Defined.


Definition to_nat (p : Party) :=
  match p with
  | PartyN n => n
  end.

Definition of_nat (n : nat) := PartyN n.

Lemma of_to_nat p : of_nat (to_nat p) = p.
Proof.
  now destruct p.
Qed.

Lemma to_int_injective x y  : to_nat x = to_nat y ->
                              x = y.
Proof. intros.
       assert (of_nat (to_nat x) = of_nat (to_nat y)) by congruence. now rewrite !of_to_nat in H0.
Qed.

Definition to_natA (a : Asset) :=
  match a with
  | DKK => 0%nat
  | USD => 1%nat
  end.

Definition of_natA (n : nat) :=
  match n with
  | 0%nat => DKK
  | _ => USD
  end.

Lemma of_to_natA a : of_natA (to_natA a) = a.
Proof.
  now destruct a.
Qed.

Lemma to_natA_injective x y  : to_natA x = to_natA y ->
                               x = y.
Proof. intros.
       assert (of_natA (to_natA x) = of_natA (to_natA y)) by congruence. now rewrite !of_to_natA in H0.
Qed.

Instance Asset_eqdec : stdpp.base.EqDecision Asset.
Proof.
  intros x y.
  unfold base.Decision.
  destruct (stdpp.base.decide (to_natA x = to_natA y)).
  - left; apply to_natA_injective; auto.
  - right; intros xney.
    subst x. congruence.
Defined.
Instance Party_eqdec : stdpp.base.EqDecision Party.
Proof.
  intros x y.
  unfold base.Decision.
  destruct (stdpp.base.decide (to_nat x = to_nat y)).
  - left; apply to_int_injective; auto.
  - right; intros xney.
    subst x. congruence.
Defined.

Instance Obs_countable : countable.Countable ObsLabel.
Proof.
  refine {| countable.encode t := countable.encode (to_sum t);
            countable.decode p := do zz <- countable.decode p;
                                     Some (of_sum zz) |}.
  intros x.
  rewrite countable.decode_encode.
  cbn.
  now rewrite of_to_sum.
Defined.

Instance Party_countable : countable.Countable Party.
Proof.
  refine {| countable.encode t := countable.encode (to_nat t);
            countable.decode p := do zz <- countable.decode p;
                                     Some (of_nat zz) |}.
  intros x. rewrite countable.decode_encode. cbn. now rewrite of_to_nat.
Defined.


Instance Asset_countable : countable.Countable Asset.
Proof.
  refine {| countable.encode t := countable.encode (to_natA t);
            countable.decode p := do zz <- countable.decode p;
                                     Some (of_natA zz) |}.
  intros x. rewrite countable.decode_encode. cbn. now rewrite of_to_natA.
Defined.


Definition OLEq (l1: ObsLabel) (l2 : ObsLabel) :=
  match l1, l2 with
  | (LabZ z1) , (LabZ z2) => z1 =? z2
  | (LabB z1) , (LabB z2) => z1 =? z2
  | _ , _ => false 
  end.


(** Definition of environments for CL and CLVM *)
Inductive Var : Set := V1 | VS (v:Var).

Definition Env' A := list A.

Fixpoint lookupEnv {A} (v : Var) (env : Env' A) : option A :=
  match v, env with
  | V1, x::_ => Some x
  | VS v, _::xs => lookupEnv v xs
  | _,_ => None
  end.

Fixpoint StackLookupEnv {A} (n : nat) (env : Env' A) : option A :=
  match n, env with
  | O, x::_ => Some x
  | S n', _::xs => StackLookupEnv n' xs
  | _,_ => None
  end.

Fixpoint translateVarToNat (v : Var) :=
  match v with
  | V1 => O
  | VS v' => S (translateVarToNat v')
  end.


Definition Env := Env' Val.

Definition ExtEnv' A := ObsLabel -> Z -> A.

Definition adv_ext {A} (d : Z) (e : ExtEnv' A) : ExtEnv' A
  := fun l x => e l (d + x)%Z.


Definition ExtEnv := ExtEnv' Val.

Definition ExtMap := FMap (ObsLabel * Z) Val.

Definition ExtMap_to_ExtEnv (extM : ExtMap) : ExtEnv := fun l i => match FMap.find (l,i) extM with
                                                                   | None => ZVal 0
                                                                   | Some v => v
                                                                end.

(** Interfaces for advancing environments *)

Definition empt : FMap (ObsLabel * Z) Val := FMap.empty.

Fixpoint adv_map_aux (l : list (ObsLabel * Z * Val)) (d : Z) :=
  match l with
  | [] => []
  | (l , z , v)::tl => (l, z - d, v)::(adv_map_aux tl d)
  end.


Definition adv_map (d : Z) (e : ExtMap) : ExtMap
  := FMap.of_list (adv_map_aux (FMap.elements e) d).

(** Definition of transactions and traces for CL and CLVM along with combinators *)

Definition Trans := Party -> Party -> Asset -> Z.
Definition TransM := FMap Party (FMap Party (FMap Asset Z)).

Definition empty_trans : Trans := fun p1 p2 c => 0.
Definition empty_transM : TransM := FMap.empty.
(** TODO: Make party a part of the Eqb class to simplify *)
Definition singleton_trans (p1 p2 : Party) (a : Asset) (z: Z) : Trans :=
  match p1, p2 with
  | PartyN pn1, PartyN pn2 => if (pn1 =? pn2)%nat then empty_trans else
                                fun p1' p2' a' => match p1', p2' with
                                                  | PartyN pn1', PartyN pn2' =>
                                                    if ((pn1 =? pn1')%nat && ((pn2 =? pn2')%nat && (eqbA a a'))%bool)%bool
                                                    then z
                                                    else if andb (pn1 =? pn2')%nat (andb (pn2 =? pn1')%nat (eqbA a a'))
                                                         then -z
                                                         else 0
                                                  end
  end.


Definition singleton_transM (p1 p2 : Party) (a : Asset) (z: Z) : TransM :=
  match p1, p2 with
  | PartyN pn1, PartyN pn2 => if (pn1 =? pn2)%nat then FMap.empty else
                                let azp : FMap Asset Z := FMap.add a z FMap.empty in
                                let azm : FMap Asset Z := FMap.add a (-z) FMap.empty in
                                let p2azp : FMap Party (FMap Asset Z) := FMap.add p2 azp FMap.empty  in
                                let p1azm : FMap Party (FMap Asset Z) := FMap.add p1 azm FMap.empty  in
                                let p1p2azp : TransM := FMap.add p1 p2azp FMap.empty in
                                FMap.add p2 p1azm (p1p2azp)
  end.


Definition lookup_transM (p1 p2 : Party) (a : Asset) (t : TransM) :=
  do l1 <- FMap.find p1 t ;
  do l2 <- FMap.find p2 l1 ;
  FMap.find a l2.

Definition add_trans : Trans -> Trans -> Trans := fun t1 t2 p1 p2 c => (t1 p1 p2 c + t2 p1 p2 c).
Definition add_transM : TransM -> TransM -> TransM :=
  FMap.union_with (fun paz1 paz2 => Some (FMap.union_with (fun az1 az2 => Some (FMap.union_with (fun z1 z2 => Some (z1 + z2)) az1 az2) ) paz1 paz2)).

(** TODO 
    Refactor 
 *)

Fixpoint scale_aux3 (s : Z) (l : list (Asset * Z)) : FMap Asset Z :=
  match l with
  | [] => FMap.empty
  | (a, z)::tl => FMap.add a (z * s) (scale_aux3 s tl)
  end.

Fixpoint scale_aux2 (s: Z) (l : list (Party * (FMap Asset Z))) : FMap Party (FMap Asset Z) :=
  match l with
  | [] => FMap.empty
  | (p2, az)::tl => FMap.add p2 (scale_aux3 s (FMap.elements az)) (scale_aux2 s tl)
  end.

Fixpoint scale_aux1 (s: Z) (l : list (Party * (FMap Party (FMap Asset Z)))) : TransM :=
  match l with
  | [] => FMap.empty
  | (p1, paz)::tl => FMap.add p1 (scale_aux2 s (FMap.elements paz)) (scale_aux1 s tl)
  end.

Fixpoint scale_transM (s : Z) (t : TransM) :=
  scale_aux1 s (FMap.elements t).

Definition scale_trans : Z -> Trans -> Trans := fun s t p1 p2 c => (t p1 p2 c * s).

Definition Trace := nat -> Trans.

Definition TraceM := FMap nat TransM.

Definition const_trace (t : Trans) : Trace := fun x => t.
Definition empty_trace : Trace := const_trace empty_trans.

Definition empty_traceM : TraceM := FMap.empty.

Definition singleton_trace (t : Trans) : Trace
  := fun x => match x with 
              | O => t
              | _ => empty_trans
              end.

Definition singleton_traceM (t: TransM) : TraceM := FMap.add 0%nat t empty_traceM.

Definition scale_trace (s : Z) (t : Trace) : Trace
  := fun x => scale_trans s  (t x).

Definition scale_traceM (s : Z) (t: TraceM) : TraceM :=
  FMap.of_list (List.map (fun e : nat * TransM => match e with | (n,t1) => (n, (scale_transM s t1)) end) (FMap.elements t)).

Definition delay_trace (d : nat) (t : Trace) : Trace :=
  fun x => if (leb d x)
           then t (x - d)%nat
           else empty_trans.

Definition delay_traceM (d : nat) (t : TraceM) : TraceM :=
  FMap.of_list
    (List.map (fun e : nat * TransM => match e with
                                       | (n,trans) =>
                                         ((n + d)%nat, trans) end)
              (FMap.elements t)).

Definition add_trace (t1 t2 : Trace) : Trace 
  := fun x => add_trans (t1 x) (t2 x).

Definition add_traceM (t1 t2 : TraceM) : TraceM :=
  FMap.union_with (fun trans1 trans2 => Some (add_transM trans1 trans2)) t1 t2.

Lemma lookupTranslateSound : forall (A: Type) (env : (Env' A)) (v : Var),  lookupEnv v env = StackLookupEnv (translateVarToNat v) env. 
Proof.
  intros. generalize dependent v. induction env.
  - intros. destruct v; reflexivity.
  - intros v. destruct v.
    + reflexivity.
    + cbn. apply IHenv.
Qed.
