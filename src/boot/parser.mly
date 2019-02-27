/*
   Miking is licensed under the MIT license.
   Copyright (C) David Broman. See file LICENSE.txt

   parser.mly includes the grammar for parsing the two languages 'mcore' and
   'Ragnar'. The latter is used for implementing the Miking compiler.
*/

%{

  open Ustring.Op
  open Msg
  open Ast

  (** Create a new info, taking left and right part *)
  let mkinfo fi1 fi2 =
    match (fi1,fi2) with
      | (Info(fn,r1,c1,_,_), Info(_,_,_,r2,c2)) -> Info(fn,r1,c1,r2,c2)
      | (Info(fn,r1,c1,r2,c2), NoInfo) -> Info(fn,r1,c1,r2,c2)
      | (NoInfo, Info(fn,r1,c1,r2,c2)) -> Info(fn,r1,c1,r2,c2)
      | (_,_) -> NoInfo

   (** Add fix-point, if recursive function *)
  let addrec x t =
    let rec hasx t = match t with
      | TmVar(_,y,_,_) ->  x =. y
      | TmLam(_,y,_,t1) -> if x =. y then false else hasx t1
      | TmClos(_,_,_,_,_,_) -> failwith "Cannot happen"
      | TmApp(_,t1,t2) -> hasx t1 || hasx t2
      | TmConst(_,_) -> false
      | TmFix(_) -> false
      | TmTyLam(fi,x,k,t1) -> hasx t1
      | TmTyApp(fi,t1,ty1) -> hasx t1
      | TmDive(_) -> false
      | TmIfexp(_,_,None) -> false
      | TmIfexp(_,_,Some(t1)) -> hasx t1
      | TmChar(_,_) -> false
      | TmUC(fi,uct,ordered,uniqueness) ->
          let rec work uc = match uc with
          | UCNode(uc1,uc2) -> work uc1 || work uc2
          | UCLeaf(tms) -> List.exists hasx tms
          in work uct
      | TmUtest(fi,t1,t2,tnext) -> hasx t1 || hasx t2 || hasx tnext
      | TmNop -> false
    in
    if hasx t then TmApp(NoInfo,TmFix(NoInfo), (TmLam(NoInfo,x,TyDyn,t))) else t

(* Create kind when optionally available *)
let mkopkind fi op =
  match op with
  | None -> KindStar(fi)
  | Some(k) -> k

%}

/* Misc tokens */
%token EOF
%token <Ustring.ustring Ast.tokendata> IDENT
%token <Ustring.ustring Ast.tokendata> STRING
%token <Ustring.ustring Ast.tokendata> CHAR
%token <int Ast.tokendata> UINT
%token <float Ast.tokendata> UFLOAT

/* Keywords */
%token <unit Ast.tokendata> IF
%token <unit Ast.tokendata> THEN
%token <unit Ast.tokendata> ELSE
%token <unit Ast.tokendata> TRUE
%token <unit Ast.tokendata> FALSE
%token <unit Ast.tokendata> MATCH
%token <unit Ast.tokendata> WITH
%token <unit Ast.tokendata> CASE
%token <unit Ast.tokendata> UTEST
%token <unit Ast.tokendata> TYPE
%token <unit Ast.tokendata> DATA
%token <unit Ast.tokendata> LANG
%token <unit Ast.tokendata> MCORE
%token <unit Ast.tokendata> LET
%token <unit Ast.tokendata> LAM
%token <unit Ast.tokendata> BIGLAM
%token <unit Ast.tokendata> ALL
%token <unit Ast.tokendata> NOP
%token <unit Ast.tokendata> FIX
%token <unit Ast.tokendata> DIVE
%token <unit Ast.tokendata> IFEXP




%token <unit Ast.tokendata> EQ            /* "="   */
%token <unit Ast.tokendata> ARROW         /* "->"  */
%token <unit Ast.tokendata> ADD           /* "+"   */
%token <unit Ast.tokendata> SUB           /* "-"   */
%token <unit Ast.tokendata> MUL           /* "*"   */
%token <unit Ast.tokendata> DIV           /* "/"   */
%token <unit Ast.tokendata> MOD           /* "%"   */
%token <unit Ast.tokendata> LESS          /* "<"   */
%token <unit Ast.tokendata> LESSEQUAL     /* "<="  */
%token <unit Ast.tokendata> GREAT         /* ">"   */
%token <unit Ast.tokendata> GREATEQUAL    /* ">="  */
%token <unit Ast.tokendata> SHIFTLL       /* "<<"  */
%token <unit Ast.tokendata> SHIFTRL       /* ">>"  */
%token <unit Ast.tokendata> SHIFTRA       /* ">>>" */
%token <unit Ast.tokendata> EQUAL         /* "=="  */
%token <unit Ast.tokendata> NOTEQUAL      /* "!="  */
%token <unit Ast.tokendata> NOT           /* "!"   */
%token <unit Ast.tokendata> OR            /* "||"  */
%token <unit Ast.tokendata> AND           /* "&&"  */
%token <unit Ast.tokendata> CONCAT        /* "++"  */
%token <unit Ast.tokendata> DOLLAR        /* "$"   */



/* Symbolic Tokens */
%token <unit Ast.tokendata> LPAREN        /* "("   */
%token <unit Ast.tokendata> RPAREN        /* ")"   */
%token <unit Ast.tokendata> LSQUARE       /* "["   */
%token <unit Ast.tokendata> RSQUARE       /* "]"   */
%token <unit Ast.tokendata> LCURLY        /* "{"   */
%token <unit Ast.tokendata> RCURLY        /* "}"   */
%token <unit Ast.tokendata> CONS          /* "::"  */
%token <unit Ast.tokendata> COLON         /* ":"   */
%token <unit Ast.tokendata> COMMA         /* ","   */
%token <unit Ast.tokendata> DOT           /* "."   */
%token <unit Ast.tokendata> BAR           /* "|"   */
%token <unit Ast.tokendata> ARROW         /* "->"  */
%token <unit Ast.tokendata> DARROW        /* "=>"  */

%start main

%left OR   /*prec 2*/
%left AND  /*prec 3*/
%left LESS LESSEQUAL GREAT GREATEQUAL EQUAL NOTEQUAL /*prec 6*/
%left CONCAT
%left SHIFTLL SHIFTRL SHIFTRA
%nonassoc NOT /*prec 8 */
%left ADD SUB /*prec 8*/
%left MUL DIV MOD /*prec 9*/




%type <Ast.tm> main

%%

main:
  | LANG MCORE mcore_scope EOF
      { $3 }


mcore_scope:
  | { TmNop }
  | UTEST atom atom mcore_scope
      { let fi = mkinfo $1.i (tm_info $3) in
        TmUtest(fi,$2,$3,$4) }
  | LET IDENT EQ mc_term mcore_scope
      { let fi = mkinfo $1.i (tm_info $4) in
        TmApp(fi,TmLam(fi,$2.v,TyDyn,$5),$4) }
  | TYPE IDENT mcore_scope
      { TmNop } /* TODO */
  | DATA ty_data mcore_scope
      { TmNop } /* TODO */


mc_term:
  | cases
      { $1 }
  | LAM IDENT ty_op DOT mc_term
      { let fi = mkinfo $1.i (tm_info $5) in
        TmLam(fi,$2.v,$3,$5) }
  | BIGLAM IDENT opkind DOT mc_term
      { let fi = mkinfo $1.i (tm_info $5) in
        TmTyLam(fi,$2.v,mkopkind $2.i $3,$5) }
  | MATCH mc_term WITH mc_term
      { TmNop }

cases:
  | case
      { $1 }
  | case BAR cases
      { $1 }


case:
  | left
      { $1 }
  | CASE IDENT LPAREN rev_comma_name_lst RPAREN DARROW left
      { TmNop } /* TODO */
  | CASE IDENT DARROW left
      { TmNop } /* TODO */


left:
  | atom
      { $1 }
  | left atom
      { let fi = mkinfo (tm_info $1) (tm_info $2) in
        TmApp(fi,$1,$2) }
  | left LSQUARE ty RSQUARE
      { let fi = mkinfo (tm_info $1) $4.i in
        TmTyApp(fi,$1,$3) }

atom:
  | LPAREN rev_comma_tm_lst RPAREN
    { $2 } /* TODO */
  | IDENT                { TmVar($1.i,$1.v,noidx,false) }
  | CHAR                 { TmChar($1.i, List.hd (ustring2list $1.v)) }
  | STRING               { ustring2uctm $1.i $1.v }
  | UINT                 { TmConst($1.i,CInt($1.v)) }
  | UFLOAT               { TmConst($1.i,CFloat($1.v)) }
  | TRUE                 { TmConst($1.i,CBool(true)) }
  | FALSE                { TmConst($1.i,CBool(false)) }
  | NOP                  { TmNop }
  | FIX                  { TmFix($1.i) }
  | DIVE                 { TmDive($1.i) }
  | IFEXP                { TmIfexp($1.i,None,None) }



rev_comma_name_lst:
  | IDENT
    { [($1.i,$1.v)] }
  | rev_comma_name_lst COMMA IDENT
    { ($3.i,$3.v)::$1 }


rev_comma_tm_lst:
  | mc_term
     { $1 } /* TODO list */
  | rev_comma_tm_lst COMMA mc_term
     { $3 } /* TODO list */

rev_comma_ty_lst:
  | ty
    { [$1] }
  | rev_comma_ty_lst COMMA ty
    { $3::$1 }


ty_op:
  | COLON ty
      { $2 }
  |
      { TyDyn }


ty_data:
  | IDENT LPAREN rev_comma_ty_lst RPAREN DARROW IDENT
     { TmNop } /* TODO */
  | IDENT DARROW IDENT
     { TmNop } /* TODO */


ty:
  | ty_left
      { $1 }
  | ty_left ARROW ty
      { let fi = mkinfo (ty_info $1) (ty_info $3) in
        TyArrow(fi,$1,$3) }
  | ALL IDENT opkind DOT ty
      { let fi = mkinfo $1.i (ty_info $5) in
        TyAll(fi,$2.v,mkopkind $2.i $3,$5) }
  | LAM IDENT opkind DOT ty
      { let fi = mkinfo $1.i (ty_info $5) in
        TyLam(fi,$2.v,mkopkind $2.i $3,$5) }


ty_left:
  | ty_atom
      { $1 }
  | ty_left ty_atom
      { let fi = mkinfo (ty_info $1) (ty_info $2) in
        TyApp(fi,$1,$2) }

ty_atom:
  | IDENT
      {match Ustring.to_utf8 $1.v with
       | "Bool" -> TyGround($1.i,GBool)
       | "Int" -> TyGround($1.i,GInt)
       | "Float" -> TyGround($1.i,GFloat)
       | "String" -> TyGround($1.i,GVoid)  (* TODO *)
       | "Void" -> TyGround($1.i,GVoid)
       | _ -> TyVar($1.i,$1.v,-1)
      }
  | LPAREN ty RPAREN
      { $2 }


opkind:
  |
      { None }
  | CONS kind
      { Some($2) }


kind:
  | kindatom
      { $1 }
  | kindatom ARROW kind
      { let fi = mkinfo (kind_info $1) (kind_info $3) in
        KindArrow(fi,$1,$3) }

kindatom:
  | MUL
      { KindStar($1.i) }
  | LPAREN kind RPAREN
      { $2 }
