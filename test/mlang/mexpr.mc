-- TODO: Change string variables to deBruijn indices
-- TODO: Generate unique symbols for data constructors
include "string.mc"

lang Var
  syn Expr =
  | TmVar (Dyn) -- String

  sem eval (env : Dyn) = -- (env : Env)
  | TmVar x ->
    let lookup = fix (lam lookup. lam x. lam env.
      if eqi (length env) 0
      then error (concat "Unknown variable: " x)
      else if eqstr (head env).0 x
      then (head env).1
      else lookup x (tail env)
    ) in
    eval env (lookup x env)
end

lang Fun = Var
  syn Expr =
  | TmLam (Dyn, Dyn) -- (String, Expr)
  | TmClos (Dyn, Dyn, Dyn) -- (String, Expr, Env)
  | TmApp (Dyn, Dyn) -- (Expr, Expr)

  sem apply (arg : Dyn) = -- (arg : Dyn)
  | TmClos t ->
      let x = t.0 in
      let body = t.1 in
      let env2 = t.2 in
      eval (cons (x, arg) env2) body
  | _ -> error "Bad application"

  sem eval (env : Dyn) = -- env : Env
  | TmLam t ->
    let x = t.0 in
    let body = t.1 in
    TmClos(x, body, env)
  | TmClos t -> TmClos t
  | TmApp t ->
    let t1 = t.0 in
    let t2 = t.1 in
    apply (eval env t2) (eval env t1)
end

lang Fix = Fun
  syn Expr =
  | TmFix

  sem apply (arg : Dyn) = -- (arg : Expr)
  | TmFix ->
  match arg with TmClos clos then
    let x = clos.0 in
    let body = clos.1 in
    let env2 = clos.2 in
    eval (cons (x, TmApp (TmFix, TmClos clos)) env2) body
  else
    error "Not fixing a function"

  sem eval (env : Dyn) = -- (env : Env)
  | TmFix -> TmFix
 end

lang Let = Var
  syn Expr =
  | TmLet (Dyn, Dyn, Dyn) -- (String, Expr, Expr)

  sem eval (env : Dyn) = -- (Env)
  | TmLet t ->
    let x = t.0 in
    let t1 = t.1 in
    let t2 = t.2 in
    eval (cons (x, eval env t1) env) t2
end

lang Const
  syn Const =

  syn Expr =
  | TmConst (Dyn) -- (Const)

  sem delta (arg : Dyn) = -- (arg : Expr)

  sem apply (arg : Dyn) = -- (arg : Expr)
  | TmConst c -> delta arg c

  sem eval (env : Dyn) = -- (env : Env)
  | TmConst c -> TmConst c
end

lang Unit = Const
  syn Const =
  | CUnit
end

lang Arith
  syn Const =
  | CInt (Dyn) -- (int)
  | CAddi
  | CAddi2 (Dyn)
  -- TODO: Add more operations
  -- TODO: Add floating point numbers (maybe in its own fragment)

  sem delta (arg : Dyn) = -- (arg : Expr)
  | CAddi ->
    match arg with TmConst c then
      match c with CInt n then
        TmConst(CAddi2 n)
      else error "Not adding a numeric constant"
    else error "Not adding a constant"
  | CAddi2 n1 ->
    match arg with TmConst c then
      match c with CInt n2 then
        TmConst(CInt (addi n1 n2))
      else error "Not adding a numeric constant"
    else error "Not adding a constant"
end

lang Bool
  syn Const =
  | CBool (Dyn) -- (bool)
  | CNot
  | CAnd
  | CAnd2 (Dyn) -- (Expr)
  | COr
  | COr2 (Dyn) -- (Expr)

  syn Expr =
  | TmIf (Dyn, Dyn, Dyn)

  sem delta (arg : Dyn) = -- (arg : Expr)
  | CNot ->
    match arg with TmConst c then
      match c with CBool b then
        TmConst(CBool (not b))
      else error "Not negating a boolean constant"
    else error "Not negating a constant"
  | CAnd ->
    match arg with TmConst c then
      match c with CBool b then
        TmConst(CAnd2 b)
      else error "Not and-ing a boolean constant"
    else error "Not and-ing a constant"
  | CAnd2 b1 ->
    match arg with TmConst c then
      match c with CBool b2 then
        TmConst(CBool (and b1 b2))
      else error "Not and-ing a boolean constant"
    else error "Not and-ing a constant"
  | COr ->
    match arg with TmConst c then
      match c with CBool b then
        TmConst(COr2 b)
      else error "Not or-ing a boolean constant"
    else error "Not or-ing a constant"
  | COr2 b1 ->
    match arg with TmConst c then
      match c with CBool b2 then
        TmConst(CBool (or b1 b2))
      else error "Not or-ing a boolean constant"
    else error "Not or-ing a constant"

  sem eval (env : Dyn) = -- (env : Env)
  | TmIf t ->
    let cond = t.0 in
    let thn  = t.1 in
    let els  = t.2 in
    match eval env cond with TmConst c then
      match c with CBool b then
        if b then eval env thn else eval env els
      else error "Condition is not a boolean"
    else error "Condition is not a constant"
end

lang Seq = Arith
  syn Const =
  | CSeq (Dyn) -- ([Expr])
  | CNth
  | CNth2 (Dyn) -- ([Expr])

  syn Expr =
  | TmSeq (Dyn) -- ([Expr])

  sem delta (arg : Dyn) = -- (arg : Expr)
  | CNth ->
    match arg with TmConst c then
      match c with CSeq tms then
        TmConst(CNth2 tms)
      else error "Not nth of a sequence"
    else error "Not nth of a constant"
  | CNth2 tms ->
    match arg with TmConst c then
      match c with CInt n then
        nth tms n
      else error "n in nth is not a number"
    else error "n in nth is not a constant"

  sem eval (env : Dyn) = -- (env : Expr)
  | TmSeq tms ->
    let vs = map (eval env) tms in
    TmConst(CSeq vs)
end

lang Tuple = Arith
  syn Expr =
  | TmTuple (Dyn) -- ([Expr])
  | TmProj (Dyn, Dyn) -- (Expr, int)

  sem eval (env : Dyn) = -- (env : Expr)
  | TmTuple tms ->
    let vs = map (eval env) tms in
    TmTuple(vs)
  | TmProj t ->
    let tup = t.0 in
    let idx = t.1 in
    match eval env tup with TmTuple tms then
      nth tms idx
    else error "Not projecting from a tuple"
end

lang Data
  -- TODO: Constructors have no generated symbols
  syn Expr =
  | TmConDef (Dyn, Dyn) -- (String, Expr)
  | TmConFun (Dyn) -- (String)
  | TmCon (Dyn, Dyn) -- (String, Expr)
  | TmMatch (Dyn, Dyn, Dyn, Dyn, Dyn) -- (Expr, String, String, Expr, Expr)

  sem apply (arg : Dyn) = -- (arg : Dyn)
  | TmConFun k -> TmCon (k, arg)

  sem eval (env : Dyn) = -- (env : Env)
  | TmConDef t ->
    let k = t.0 in
    let body = t.1 in
    eval (cons (k, TmConFun(k)) env) body
  | TmConFun t -> TmConFun t
  | TmCon t -> TmCon t
  | TmMatch t ->
    let target = t.0 in
    let k2 = t.1 in
    let x = t.2 in
    let thn = t.3 in
    let els = t.4 in
    match eval env target with TmCon t1 then
      let k1 = t1.0 in
      let v = t1.1 in
      if eqstr k1 k2
      then eval (cons (x, v) env) thn
      else eval env els
    else error "Not matching on constructor"
end

lang Utest
  syn Expr =
  | TmUtest (Dyn, Dyn, Dyn) -- (Expr, Expr, Expr)

  sem eq (e1 : Dyn) = -- (e1 : Expr)
  | _ -> error "Equality not defined for expression"

  sem eval (env : Dyn) = -- (env : Env)
  | TmUtest t ->
    let test = t.0 in
    let expected = t.1 in
    let next = t.2 in
    let v1 = eval env test in
    let v2 = eval env expected in
    let _ = if eq v1 v2 then print "Test passed\n" else print "Test failed\n" in
    eval env next
end

lang MExpr = Fun + Fix + Let
           + Seq + Tuple + Data + Utest
           + Const + Arith + Bool + Unit
  sem eq (e1 : Dyn) = -- (e1 : Expr)
  | TmConst c2 -> const_expr_eq c2 e1
  | TmCon d2 -> data_eq d2 e1
  | TmTuple tms2 -> tuple_eq tms2 e1
  | TmSeq seq2 -> seq_eq seq2 e1

  sem const_expr_eq (c1 : Dyn) = -- (c1 : Const)
  | TmConst c2 -> const_eq c1 c2
  | _ -> false

  sem const_eq (c1 : Dyn) = -- (c1 : Const)
  | CUnit -> is_unit c1
  | CInt n2 -> int_eq n2 c1
  | CBool b2 -> bool_eq b2 c1

  sem is_unit =
  | CUnit -> true
  | _ -> false

  sem int_eq (n1 : Dyn) = -- (n1 : Int)
  | CInt n2 -> eqi n1 n2
  | _ -> false

  sem bool_eq (b1 : Dyn) = -- (b1 : Bool)
  | CBool b2 -> or (and b1 b2) (and (not b1) (not b2))
  | _ -> false

  sem data_eq (d1 : Dyn) = -- (d1 : (String, Expr))
  | TmCon d2 ->
    let tail = lam l. slice l 1 (length l) in
    let head = lam l. nth l 0 in
    let eqchar = lam c1. lam c2. eqi (char2int c1) (char2int c2) in
    let eqstr = fix (lam eqstr. lam s1. lam s2.
        if neqi (length s1) (length s2)
        then false
        else if eqi (length s1) 0
             then true
             else if eqchar (head s1) (head s2)
             then eqstr (tail s1) (tail s2)
             else false
    ) in
    let k1 = d1.0 in
    let k2 = d2.0 in
    let v1 = d1.1 in
    let v2 = d2.1 in
    and (eqstr k1 k2) (eq v1 v2)

  sem tuple_eq (tms1 : Dyn) =
  | TmTuple tms2 ->
    let zip_with = fix (lam zip_with. lam f. lam xs. lam ys.
      if eqi (length xs) 0
      then []
      else if eqi (length ys) 0
      then []
      else
        let x = nth xs 0 in
        let y = nth ys 0 in
        let xs2 = slice xs 1 (length xs) in
        let ys2 = slice ys 1 (length ys) in
        cons (f x y) (zip_with f xs2 ys2)
    ) in
    let for_all = fix (lam for_all. lam p. lam xs.
      if eqi (length xs) 0
      then true
      else and (p (nth xs 0)) (for_all p (slice xs 1 (length xs)))
    ) in
    and (eqi (length tms1) (length tms2))
        (for_all (lam b.b) (zip_with eq tms1 tms2))
  | _ -> false

  sem seq_eq (seq1 : Dyn) =
  | TmSeq seq2 ->
    let zip_with = fix (lam zip_with. lam f. lam xs. lam ys.
      if eqi (length xs) 0
      then []
      else if eqi (length ys) 0
      then []
      else
        let x = nth xs 0 in
        let y = nth ys 0 in
        let xs2 = slice xs 1 (length xs) in
        let ys2 = slice ys 1 (length ys) in
        cons (f x y) (zip_with f xs2 ys2)
    ) in
    let for_all = fix (lam for_all. lam p. lam xs.
      if eqi (length xs) 0
      then true
      else and (p (nth xs 0)) (for_all p (slice xs 1 (length xs)))
    ) in
    and (eqi (length seq1) (length seq2))
        (for_all (lam b.b) (zip_with eq seq1 seq2))
  | _ -> false
end

main
use MExpr in
let id = TmLam ("x", TmVar "x") in
let bump = TmLam ("x", TmApp (TmApp (TmConst CAddi, TmVar "x"), TmConst(CInt 1))) in
let fst = TmLam ("t", TmProj (TmVar "t", 0)) in
let app_id_unit = TmApp (id, TmConst CUnit) in
let app_bump_3 = TmApp (bump, TmConst(CInt 3)) in
let app_fst =
  TmApp (fst, TmTuple([TmApp (TmConst CNot, TmConst(CBool false))
                      ,TmApp (TmApp (TmConst CAddi, TmConst (CInt 1)), TmConst(CInt 2))])) in
utest eval [] app_id_unit with TmConst CUnit in
utest eval [] app_bump_3 with TmConst (CInt 4) in
utest eval [] app_fst with TmConst (CBool true) in

let unit = TmConst CUnit in

let data_decl = TmConDef ("Foo",
                  TmMatch (TmApp (TmVar "Foo", TmTuple [unit, unit])
                          ,"Foo", "u", TmProj(TmVar "u",0)
                          ,id)) in
utest eval [] data_decl with unit in

let utest_test1 = TmUtest (TmConst (CInt 1), TmConst (CInt 1), unit) in
let utest_test2 =
  TmUtest (TmTuple [TmConst (CInt 1),
                    TmApp (TmApp (TmConst CAddi, TmConst (CInt 1)), TmConst (CInt 2))]
          ,TmTuple [TmConst (CInt 1), TmConst (CInt 3)], unit)
in
let utest_test3 =
  TmConDef ("Foo",
    TmUtest (TmApp (TmVar "Foo", unit), TmApp (TmVar "Foo", unit), unit))
in
utest eval [] utest_test1 with unit in
utest eval [] utest_test2 with unit in
utest eval [] utest_test3 with unit in

-- Implementing an interpreter
let num = lam n. TmApp (TmVar "Num", TmConst(CInt n)) in
let one = num 1 in -- Num 1
let two = num 2 in -- Num 2
let three = num 3 in -- Num 3
let add = lam n1. lam n2. TmApp (TmVar "Add", TmTuple([n1, n2])) in
let add_one_two = add one two in -- Add (Num 1, Num 2)
let num_case = lam arg. lam els. -- match arg with Num n then Num n else els
    TmMatch (arg, "Num", "n", TmApp (TmVar "Num", (TmVar "n")), els)
in
-- match arg with Add t then
--   let e1 = t.0 in
--   let e2 = t.1 in
--   match eval e1 with Num n1 then
--     match eval e2 with Num n2 then
--       Num (addi n1 n2)
--     else ()
--   else ()
-- else els
let result =
  TmApp (TmVar "Num", (TmApp (TmApp (TmConst CAddi, TmVar "n1"), TmVar "n2"))) in
let match_inner =
  TmMatch (TmApp (TmVar "eval", TmVar "e2")
          ,"Num", "n2", result
          ,unit) in
let match_outer =
  TmMatch (TmApp (TmVar "eval", TmVar "e1")
          ,"Num", "n1", match_inner
          ,unit) in
let deconstruct = lam t.
  TmLet ("e1", TmProj (t, 0)
        ,TmLet ("e2", TmProj(t, 1), match_outer)) in
let add_case = lam arg. lam els.
  TmMatch (arg, "Add", "t", deconstruct (TmVar "t"), els) in
let eval_fn = -- fix (lam eval. lam e. match e with then ... else ())
  TmApp (TmFix, TmLam ("eval", TmLam ("e",
         num_case (TmVar "e") (add_case (TmVar "e") unit)))) in

let wrap_in_decls = lam t. -- con Num in con Add in let eval = ... in t
  TmConDef("Num", TmConDef ("Add", TmLet ("eval", eval_fn, t))) in

let eval_add1 = wrap_in_decls (TmApp (TmVar "eval", add_one_two)) in
let add_one_two_three = add (add one two) three in
let eval_add2 = wrap_in_decls (TmApp (TmVar "eval", add_one_two_three)) in

utest eval [] eval_add1 with TmCon("Num", TmConst(CInt 3)) in
utest eval [] eval_add2 with TmCon("Num", TmConst(CInt 6)) in

()