#lang racket
(provide unifier
         check-type
         subst
         typeof
         typeof-expanded
         local-expand-expr
         syntax-property*
         free-identifier?
         constructor?
         normalize)

(require syntax/parse
         syntax/stx
         racket/dict
         "helper/stx-util.rkt"
         "helper/id-hash.rkt")

(define (unifier subst-map)
  (define (unify? t1 t2)
    (cond
      [(and (syntax? t1) (syntax? t2)) (void)]
      [(syntax? t1) (raise-syntax-error 'bad-unification
                                        (format "~a is not syntax" t2)
                                        t1)]
      [(syntax? t2) (raise-syntax-error 'bad-unification
                                        (format "~a is not syntax" t1)
                                        t2)]
      [else (error 'not-syntax "~a or ~a" t1 t2)])
    (syntax-parse (list t1 t2)
      [(a b) #:when (and (free-identifier? t1)
                         (free-identifier? t2))
             (define bounded? (hash-ref subst-map (syntax->datum #'a) #f))
             (if bounded?
                 (unify? t2 bounded?)
                 #t)]
      [(a b) #:when (free-identifier? t2)
             (unify? t2 t1)]
      [(a b) #:when (free-identifier? t1)
             (define bounded? (hash-ref subst-map (syntax->datum #'a) #f))
             (if bounded?
                 (if (unify? (hash-ref subst-map (syntax->datum #'a)) t2)
                     #t
                     (raise-syntax-error 'cannot-unified
                                         (format "`~a` with `~a`"
                                                 (syntax->datum (hash-ref subst-map (syntax->datum #'a)))
                                                 (syntax->datum t2))
                                         t2))
                 (begin
                   (hash-set! subst-map (syntax->datum #'a) #'b)
                   #t))]
      [((a ...) (b ...))
       (define (recheck a b)
         (unless (stx-length=? a b)
           (raise-syntax-error 'bad-unification
                               (format "mismatched length for two term, ~a and ~a"
                                       t1 t2)
                               t2)))

       (cond
         [(stx-length=? #'(a ...) #'(b ...))
          (stx-andmap unify? #'(a ...) #'(b ...))]
         ; have to try expand when length mismatched, this is because sometimes one of them is implicit applied form
         [(stx-length<=? #'(a ...) #'(b ...))
          (define ta (normalize #'(a ...)))
          (recheck ta #'(b ...))
          (stx-andmap unify? ta #'(b ...))]
         [(stx-length>=? #'(a ...) #'(b ...))
          (define tb (normalize #'(b ...)))
          (recheck #'(a ...) tb)
          (stx-andmap unify? #'(a ...) tb)])]
      [(a b) (equal? (syntax->datum t1) (syntax->datum t2))]))
  unify?)

(define (normalize stx)
  (datum->syntax stx (eval (local-expand-expr stx)) stx))

(define (check-type term type
                    [subst-map (make-hash)]
                    [locals (make-mutable-id-hash)])
  (define unify? (unifier subst-map))
  (unless (unify? (typeof term locals) type)
    (raise-syntax-error 'type-mismatch
                        (format "expect: `~a`, get: `~a`"
                                (syntax->datum (subst type subst-map))
                                (syntax->datum (subst (typeof term locals) subst-map)))
                        term)))

(define (subst stx m)
  (syntax-parse stx
    [(A a ...)
     ; The source location of first syntax takes by quasisyntax/loc will be the second constructed syntax's source location
     (quasisyntax/loc stx
       (A #,@(stx-map (λ (b) (subst b m)) #'(a ...))))]
    [name:id (hash-ref m (syntax->datum #'name) stx)]))

(define (typeof stx [locals (make-mutable-id-hash)])
  (syntax-parse stx
    [x:id #:when (free-identifier? #'x)
          (dict-ref locals stx)]
    [x:id #:when (syntax-property (local-expand-expr stx) 'type)
          (syntax-property (local-expand-expr stx) 'type)]
    [x:id (raise-syntax-error 'no-type (format "~a has no type" stx) stx)]
    [(x:id a* ...)
     (syntax-parse (typeof #'x locals)
       [(Pi ([x* : typ*] ...) result-ty) #'result-ty])]))
(define (typeof-expanded stx)
  (syntax->datum (typeof stx)))

(define (local-expand-expr stx [identifiers '()])
  (local-expand stx 'expression identifiers))

(define (syntax-property* stx . pairs)
  (match pairs
    [(cons key (cons value '()))
     (syntax-property stx key value)]
    [(cons key (cons value rest))
     (syntax-property (apply syntax-property* (cons stx rest))
                      key value)]))

(define (constructor? stx)
  (and (bounded-identifier? stx)
       (syntax-property (local-expand-expr stx)
                        'constructor)))

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
