#lang k

(provide Nat z s
         (for-syntax Nat z s)
         + *
         (for-syntax + *))

(data Nat : Type
      [z : Nat]
      [s (n : Nat) : Nat])

(def (+ [n : Nat] [m : Nat]) : Nat
  [z m => m]
  [(s n) m => (s (+ n m))])

(def (* [n : Nat] [m : Nat]) : Nat
  [z m => z]
  [(s n) m => (+ m (* n m))])

(module+ test
  (require rackunit)

  (check-equal? Nat 'Nat)
  (check-equal? z 'z)
  (check-equal? (s (s (s z))) '(s (s (s z))))

  (def a : Nat (s (s z)))
  (check-equal? a (s (s z)))

  (def b : Nat (+ z (s (s z))))
  (check-equal? b (s (s z)))

  (check-equal? (+ z (s z)) '(s z))
  (check-equal? (+ (s z) (s z))
                '(s (s z)))
  (check-equal? (+ (s (s z)) (s z))
                '(s (s (s z))))

  (check-equal? (* (s (s z)) (s z))
                '(s (s z)))
  (check-equal? (* (s (s z)) (s (s z)))
                '(s (s (s (s z))))))
