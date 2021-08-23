#lang racket

(provide (except-out (all-from-out racket/base))
         ; helpers
         typeof
         check
         ; builtin types
         Type Pi
         ; definition forms
         data
         def)

(require racket/base
         syntax/parse/define
         "lib/type.rkt"
         (for-syntax racket/base
                     syntax/parse
                     syntax/parse/define
                     syntax/transformer
                     syntax/stx
                     "lib/core.rkt"))

(define-syntax-parser typeof
  [(_ stx) #`'#,(typeof-expanded #'stx)])

(begin-for-syntax
  (define-syntax-class ctor-clause
    (pattern [name:id (~literal :) ty]
             #:attr def
             #'(define-syntax-parser name
                 [_ (syntax-property* #''name 'type #'ty)]))
    (pattern [name:id (p-name* (~literal :) p-ty*) ... (~literal :) ty]
             #:attr def
             #'(define-syntax-parser name
                 [(_ p-name* ...)
                  (define subst-map (make-hash))
                  (check-type #'p-name* (subst #'p-ty* subst-map)
                              subst-map)
                  ...
                  (with-syntax ([e (stx-map local-expand-expr #'(list p-name* ...))])
                    (syntax-property* #'`(name ,@e)
                                      'type (subst #'ty subst-map)))]))))

(define-syntax-parser data
  [(_ name:id (~literal :) ty
      ctor*:ctor-clause ...)
   (with-syntax ([def #'(define-syntax-parser name
                          [_ (syntax-property* #''name 'type #'ty)])])
     #'(begin
         def
         ctor*.def ...))]
  [(_ (name:id [p-name* (~literal :) p-ty*] ...) (~literal :) ty
      ctor*:ctor-clause ...)
   (with-syntax ([def #'(define-syntax-parser name
                          [(_ p-name* ...)
                           (define subst-map (make-hash))
                           (check-type #'p-name* (subst #'p-ty* subst-map)
                                       subst-map)
                           ...
                           (with-syntax ([e (stx-map local-expand-expr #'(list p-name* ...))])
                             (syntax-property* #'`(name ,@e)
                                               'type (subst #'ty subst-map)))])])
     #'(begin
         def
         ctor*.def ...))])

(begin-for-syntax
  (define (convert pattern-stx)
    (syntax-parse pattern-stx
      [x:id #:when (bounded-identifier? #'x)
            #'(~literal x)]
      [(x ...)
       (stx-map convert #'(x ...))]
      [x #'x]))
  (define-syntax-class def-clause
    (pattern [pat* ... => expr]
             #:attr pat #`(_ #,@(stx-map convert #'(pat* ...))))))

(define-syntax-parser def
  [(_ name:id (~literal :) ty expr)
   (check-type #'expr (normalize #'ty))
   #'(begin
       (void ty)
       (define-syntax name (make-variable-like-transformer #'expr)))]
  [(_ (name:id [p-name* (~literal :) p-ty*] ...) (~literal :) ty
      clause*:def-clause ...)
   (for ([pat* (syntax->list #'((clause*.pat* ...) ...))])
     (define subst-map (make-hash))
     (define unify? (unifier subst-map))
     (for ([pat (syntax->list pat*)]
           [exp-ty (syntax->list #'(p-ty* ...))])
       (syntax-parse pat
         [x:id #:when (bounded-identifier? #'x)
               (define pat-ty (typeof #'x))
               (unless (unify? pat-ty exp-ty)
                 (raise-syntax-error 'bad-pattern
                                     (format "expect: `~a`, get: `~a`"
                                             (syntax->datum exp-ty)
                                             (syntax->datum pat-ty))
                                     pat))]
         [(x:id p ...) #:when (bounded-identifier? #'x)
                       (void)]
         [x (void)])))
   (with-syntax ([def #'(define-syntax-parser name
                          [clause*.pat #'clause*.expr] ...)]
                 [(free-p-ty* ...)
                  (filter free-identifier? (syntax->list #'(p-ty* ...)))])
     #'(begin
         (void (let* ([free-p-ty* 'free-p-ty*] ...
                      [p-name* 'p-name*] ...)
                 ty))
         def))])
(define-syntax-parser check
  [(_ ty expr)
   (check-type #'expr (normalize #'ty))
   #'(begin
       (void ty)
       expr)])

(module reader syntax/module-reader k)
