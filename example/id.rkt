#lang k

(require k/equality
         k/data/nat)

(def (identity [a : A]) : A
  [a => a])

(check (≡ (identity z) z)
       refl)
