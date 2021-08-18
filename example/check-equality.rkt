#lang k

(require k/data/bool
         k/data/nat)

(check (≡ true true)
       (refl))

(check (≡ (+ (s z) (s z))
          (s (s z)))
       (refl))

(check (≡ (s (s z))
          (+ (s z) (s z)))
       (refl))

(check (≡ (* (s z) (s z))
          (s z))
       (refl))

(check (≡ (* (s (s z)) (s (s z)))
          (s (s (s (s z)))))
       (refl))
