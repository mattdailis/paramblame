open Ftal;;

let expr str = Parse.parse_string Parse.expression_eof str

let factorial = expr {|
lam (x2 : int).
  let fact : * -> int -> int = lam(fact : *).lam(x : int).
    if x = 0 then 1 else x * (fact : * => * -> int -> int) fact (x - 1)
  in fact (fact : * -> int -> int => *) x2
|} 

let swap_int_bool = expr {|
  pi2 ((Lam X. Lam Y. lam (p : <X,Y>). < pi2 p, pi1 p >) [int] [bool] <1, true>)
|}

let swap_bool_int = expr {|
  pi1 ((Lam X. Lam Y. lam (p : <X,Y>). < pi2 p, pi1 p >) [bool] [int] <true, 1>)
|}

let bad_swap = expr {|
  pi1 (((lam(x:*).x) : *->* => * : * => forall X. forall Y. <X,Y> -> <Y,X>) [int] [int] <1,2>)
|}

let invalid_cast = expr {|
  (lam (x : int) . x : int => bool) 5
|}

let no_cast = expr {|
  (lam (x : *) . x : * => int) 5
|}

