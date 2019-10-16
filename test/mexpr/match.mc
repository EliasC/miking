// Miking is licensed under the MIT license.
// Copyright (C) David Broman. See file LICENSE.txt
//
// Test integer primitives

// Constructor construction
data K1 in
data K2 in
utest K1(1,3) with K1(1,3) in
utest K2("k",100) with K2("k",100) in


// Matching two constructors
data Foo in
data Bar in
let f = lam x.
   match x with Foo t then
     let s = t.0 in
     let n = t.1 in
     (n,s)
   else
   match x with Bar b then (addi b 5, "b") else
   (negi 1, "b") in
utest f (Foo("a",1)) with (1, "a") in
utest f (Bar 10) with (15, "b") in


()
