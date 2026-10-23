;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :clan/poo/object .ref object? object<-alist)
        :yuanxu/object-family/syntax)

(def +poo-object-family-syntax-test-kind+
  'poo-object-family-syntax-test)

(def poo-object-family-syntax-test-object
  (object<-alist
   (list
    (cons 'kind +poo-object-family-syntax-test-kind+)
    (cons 'ref 'scenario-model)
    (cons 'provider 'runtime-local)
    (cons 'capabilities '(chat text json))
    (cons 'runtime-executed #f))))

(defpoo-object-family +poo-object-family-syntax-test-kind+
  poo-object-family-syntax-test?
  (accessors
   (poo-object-family-syntax-test-ref ref)
   (poo-object-family-syntax-test-provider provider)
   (poo-object-family-syntax-test-capabilities capabilities))
  (projections
   (poo-object-family-syntax-test->alist
    (ref ref)
    (provider provider)
    (capabilities capabilities)
    (runtime-executed runtime-executed))))

(defpoo-object-family
  (prototype poo-object-family-declaration-prototype
             declaration-object?
             poo-object-family-declaration?)
  (constructor make-poo-object-family-declaration
               (ref-value ref)
               (capabilities-value capabilities))
  (accessors
   (poo-object-family-declaration-ref ref)
   (poo-object-family-declaration-capabilities capabilities))
  (projections
   (poo-object-family-declaration->alist
    (ref ref)
    (capabilities capabilities))))

(defpoo-object-family
  (prototype poo-object-family-fixed-prototype
             fixed-object?
             poo-object-family-fixed?
             (kind 'fixed-object))
  (constructor make-poo-object-family-fixed
               (value-value value))
  (accessors
   (poo-object-family-fixed-value value))
  (projections))

(export object-family-syntax-test)

(def object-family-syntax-test
  (test-suite "object family syntax"
    (yuanxu-test-case "generates POO-native predicates, accessors, and projections"
      (check-equal? (poo-object-family-syntax-test?
                     poo-object-family-syntax-test-object)
                    #t)
      (check-equal? (poo-object-family-syntax-test? 'not-a-poo-object) #f)
      (check-equal?
       (poo-object-family-syntax-test?
        (object<-alist (list (cons 'ref 'missing-kind))))
       #f)
      (check-equal? (poo-object-family-syntax-test-ref
                     poo-object-family-syntax-test-object)
                    'scenario-model)
      (check-equal? (poo-object-family-syntax-test-provider
                     poo-object-family-syntax-test-object)
                    'runtime-local)
      (check-equal? (poo-object-family-syntax-test-capabilities
                     poo-object-family-syntax-test-object)
                    '(chat text json))
      (check-equal? (poo-object-family-syntax-test->alist
                     poo-object-family-syntax-test-object)
                    '((ref . scenario-model)
                      (provider . runtime-local)
                      (capabilities chat text json)
                      (runtime-executed . #f))))
    (yuanxu-test-case "generates prototype constructor and fixed family surface once"
      (let (declaration
            (make-poo-object-family-declaration
             'scenario-model '(chat text json)))
        (check-equal? (object? declaration) #t)
        (check-equal? (poo-object-family-declaration? declaration) #t)
        (check-equal? (poo-object-family-declaration-ref declaration)
                      'scenario-model)
        (check-equal? (poo-object-family-declaration-capabilities declaration)
                      '(chat text json))
        (check-equal? (poo-object-family-declaration->alist declaration)
                      '((ref . scenario-model)
                        (capabilities chat text json)))))
    (yuanxu-test-case "preserves fixed prototype slots for every instance"
      (let (instance (make-poo-object-family-fixed 42))
        (check-equal? (poo-object-family-fixed? instance) #t)
        (check-equal? (.ref instance 'kind) 'fixed-object)
        (check-equal? (poo-object-family-fixed-value instance) 42)))))
