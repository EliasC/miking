include "char.mc"
include "option.mc"
include "seq.mc"
include "math.mc"

recursive
  let eqstr = lam s1. lam s2.
      if neqi (length s1) (length s2)
      then false
      else if null s1
           then true
           else if eqchar (head s1) (head s2)
           then eqstr (tail s1) (tail s2)
           else false
end

let str2upper = lam s. map char2upper s
let str2lower = lam s. map char2lower s

let string2int = lam s.
  recursive
  let string2int_rechelper = lam s.
    let len = length s in
    let last = subi len 1 in
    if eqi len 0
    then 0
    else
      let lsd = subi (char2int (get s last)) (char2int '0') in
      let rest = muli 10 (string2int_rechelper (slice s 0 last)) in
      addi rest lsd
  in
  match s with [] then 0 else
  if eqchar '-' (head s)
  then negi (string2int_rechelper (tail s))
  else string2int_rechelper s

utest string2int "5" with 5
utest string2int "25" with 25
utest string2int "314159" with 314159
utest string2int "-314159" with (negi 314159)

let int2string = lam n.
  recursive
  let int2string_rechelper = lam n.
    if lti n 10
    then [int2char (addi n (char2int '0'))]
    else
      let d = [int2char (addi (modi n 10) (char2int '0'))] in
      concat (int2string_rechelper (divi n 10)) d
  in
  if lti n 0
  then cons '-' (int2string_rechelper (negi n))
  else int2string_rechelper n

utest int2string 5 with "5"
utest int2string 25 with "25"
utest int2string 314159 with "314159"
utest int2string (negi 314159) with "-314159"

-- 'stringIsInt s' returns true iff 's' is a string representing an integer
let stringIsInt: String -> Bool = lam s.
  eqstr s (int2string (string2int s))

utest stringIsInt "" with false
utest stringIsInt "1 " with false
utest stringIsInt " 1" with false
utest stringIsInt "1" with true
utest stringIsInt "-1098" with true

-- A naive float2string implementation that only formats in standard form
let float2string = lam arg.
  -- Quick fix to check for infinities
  if eqf arg inf then "INFINITY" else
  if eqf arg (negf inf) then "-INFINITY" else
  -- End of quick fix
  let precision = 7 in -- Precision in number of digits
  let prefixpair = if ltf arg 0.0 then ("-", negf arg) else ("", arg) in
  let prefix = prefixpair.0 in
  let val = prefixpair.1 in
  recursive
  let float2string_rechelper = lam prec. lam digits. lam v.
    -- Assume 0 <= v < 10
    if eqi prec digits then
      ""
    else if eqf v 0.0 then
      "0"
    else
      let fstdig = floorfi v in
      let remaining = mulf (subf v (int2float fstdig)) 10.0 in
      let c = int2char (addi fstdig (char2int '0')) in
      cons c (float2string_rechelper prec (addi digits 1) remaining)
  in
  recursive
  let positive_exponent_pair = lam acc. lam v.
    if ltf v 10.0
    then (v, acc)
    else positive_exponent_pair (addi acc 1) (divf v 10.0)
  in
  recursive
  let negative_exponent_pair = lam acc. lam v.
    if geqf v 1.0
    then (v, acc)
    else negative_exponent_pair (addi acc 1) (mulf v 10.0)
  in
  let res = if eqf val 0.0 then
              "0.0"
            else if gtf val 1.0 then
              let pospair = positive_exponent_pair 0 val in
              let retstr = float2string_rechelper precision 0 (pospair.0) in
              let decimals = cons (head retstr) (cons '.' (tail retstr)) in
              concat decimals (concat "e+" (int2string pospair.1))
            else
              let pospair = negative_exponent_pair 0 val in
              let retstr = float2string_rechelper precision 0 (pospair.0) in
              let decimals = cons (head retstr) (cons '.' (tail retstr)) in
              concat decimals (concat "e-" (int2string pospair.1))
  in
  concat prefix res

utest float2string 5.0e+25 with "5.0e+25"
utest float2string (negf 5.0e+25) with "-5.0e+25"
utest float2string (5.0e-5) with "5.0e-5"
utest float2string (negf 5.0e-5) with "-5.0e-5"

-- Returns an option with the index of the first occurrence of c in s. Returns
-- None if c was not found in s.
let strIndex = lam c. lam s.
  recursive
  let strIndex_rechelper = lam i. lam c. lam s.
    if eqi (length s) 0
    then None ()
    else if eqchar c (head s)
         then Some(i)
         else strIndex_rechelper (addi i 1) c (tail s)
  in
  strIndex_rechelper 0 c s

utest strIndex '%' "a % 5" with Some(2)
utest strIndex '%' "a & 5" with None ()
utest strIndex 'w' "Hello, world!" with Some(7)
utest strIndex 'w' "Hello, World!" with None ()
utest strIndex 'o' "Hello, world!" with Some(4)
utest strIndex '@' "Some @TAG@" with Some(5)

-- Returns an option with the index of the last occurrence of c in s. Returns
-- None if c was not found in s.
let strLastIndex = lam c. lam s.
  recursive
  let strLastIndex_rechelper = lam i. lam acc. lam c. lam s.
    if eqi (length s) 0 then
      if eqi acc (negi 1)
      then None ()
      else Some(acc)
    else
      if eqchar c (head s)
      then strLastIndex_rechelper (addi i 1) i   c (tail s)
      else strLastIndex_rechelper (addi i 1) acc c (tail s)
  in
  strLastIndex_rechelper 0 (negi 1) c s

utest strLastIndex '%' "a % 5" with Some(2)
utest strLastIndex '%' "a & 5" with None ()
utest strLastIndex 'w' "Hello, world!" with Some(7)
utest strLastIndex 'w' "Hello, World!" with None ()
utest strLastIndex 'o' "Hello, world!" with Some(8)
utest strLastIndex '@' "Some @TAG@" with Some(9)

-- Splits s on delim
recursive
  let strSplit = lam delim. lam s.
    if or (eqi (length delim) 0) (lti (length s) (length delim))
    then cons s []
    else if eqstr delim (slice s 0 (length delim))
         then cons [] (strSplit delim (slice s (length delim) (length s)))
         else let remaining = strSplit delim (tail s) in
              cons (cons (head s) (head remaining)) (tail remaining)
end

utest strSplit "ll" "Hello" with ["He", "o"]
utest strSplit "ll" "Hellallllo" with ["He", "a", "", "o"]
utest strSplit "" "Hello" with ["Hello"]
utest strSplit "lla" "Hello" with ["Hello"]
utest strSplit "Hello" "Hello" with ["", ""]

-- Trims s of spaces
let strTrim = lam s.
  recursive
  let strTrim_init = lam s.
    if eqstr s ""
    then s
    else if is_whitespace (head s)
         then strTrim_init (tail s)
         else s
  in
  reverse (strTrim_init (reverse (strTrim_init s)))

utest strTrim " aaaa   " with "aaaa"
utest strTrim "   bbbbb  bbb " with "bbbbb  bbb"
utest strTrim "ccccc c\t   \n" with "ccccc c"

-- Joins the strings in strs on delim
recursive
  let strJoin = lam delim. lam strs.
    if eqi (length strs) 0
    then ""
    else if eqi (length strs) 1
         then head strs
         else concat (concat (head strs) delim) (strJoin delim (tail strs))
end

utest strJoin "--" ["water", "tea", "coffee"] with "water--tea--coffee"
utest strJoin "--" [] with ""
utest strJoin "--" ["coffee"] with "coffee"
utest strJoin "water" ["coffee", "tea"] with "coffeewatertea"
