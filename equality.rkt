#lang k

(provide (data-out ≡))

(data (≡ [a : A] [b : A]) : Type
      [refl : (≡ a a)])
