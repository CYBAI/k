#lang racket

(provide unifier
         check-type
         subst
         typeof
         typeof-expanded
         syntax-property*
         bounded-identifier?)

(require syntax/parse)

(define (unifier subst-map)
  (define (unify? t1 t2)
    (syntax-parse (list t1 t2)
      [(a b) #:when (and (free-identifier? t1)
                         (free-identifier? t2))
             #t]
      [(a b) #:when (free-identifier? t2)
             (unify? t2 t1)]
      [(a b) #:when (free-identifier? t1)
             (define bounded? (hash-ref subst-map (syntax->datum #'a) #f))
             (if bounded?
                 (begin
                   (if (unify? (hash-ref subst-map (syntax->datum #'a)) t2)
                       #t
                       (raise-syntax-error 'cannot-unified
                                           (format "`~a` with `~a`"
                                                   (syntax->datum (hash-ref subst-map (syntax->datum #'a)))
                                                   (syntax->datum t2))
                                           t2)))
                 (begin
                   (hash-set! subst-map (syntax->datum #'a) #'b)
                   #t))]
      [(((~literal Pi) [ta-name (~literal :) ta-typ] ... ta)
        ((~literal Pi) [tb-name (~literal :) tb-typ] ... tb))
       (and
        (andmap unify?
                (syntax->list #'(ta-typ ...))
                (syntax->list #'(ta-typ ...)))
        (unify? #'ta #'tb))]
      [((a ...) (b ...))
       (andmap unify?
               (syntax->list #'(a ...))
               (syntax->list #'(b ...)))]
      [(a b) (equal? (syntax->datum t1) (syntax->datum t2))]))
  unify?)

(define (normalize stx)
  (syntax-parse stx
    [(a ...)
     (define as (syntax->list stx))
     (if (ormap free-identifier? as)
         (map normalize as)
         (datum->syntax stx (eval stx) stx))]
    [else stx]))

(define (check-type term type
                    [subst-map (make-hash)])
  (define unify? (unifier subst-map))
  (unless (unify? (typeof term) (normalize type))
    (raise-syntax-error 'type-mismatch
                        (format "expect: `~a`, get: `~a`"
                                (syntax->datum (subst type subst-map))
                                (syntax->datum (subst (typeof term) subst-map)))
                        term)))

(define (subst stx m)
  (syntax-parse stx
    [(A a ...)
     #`(A #,@(map (λ (b) (subst b m)) (syntax->list #'(a ...))))]
    [name:id (hash-ref m (syntax->datum #'name) stx)]))

(define (typeof stx [identifiers '()])
  (define t (syntax-property (local-expand stx 'expression identifiers) 'type))
  (if t
      t
      #`#,(gensym 'F)))
(define (typeof-expanded stx)
  (syntax->datum (typeof stx)))

(define (local-expand-expr stx)
  (local-expand stx 'expression '()))

(define (syntax-property* stx . pairs)
  (match pairs
    [(cons key (cons value '()))
     (syntax-property stx key value)]
    [(cons key (cons value rest))
     (syntax-property (apply syntax-property* (cons stx rest))
                      key value)]))

(define (free-identifier? id-stx)
  (and (identifier? id-stx)
       (not (identifier-binding id-stx))))
(define (bounded-identifier? id-stx)
  (and (identifier? id-stx)
       (identifier-binding id-stx (syntax-local-phase-level) #t)))

(module+ test
  (require rackunit)

  (check-equal? (syntax->datum
                 (subst #'(List A) (make-hash '((A . Nat)))))
                '(List Nat)))
