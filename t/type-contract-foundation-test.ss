;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: executable admission of project Type and Contract refinement.
(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite check-equal? check-exception)
        (only-in :clan/poo/object .o .cc .ref .mix)
        (only-in :clan/poo/mop element? validate TypeError? define-type)
        :yuanxu/object-types/contracts)
(export type-contract-foundation-test)

(define-type (NamedContract @ YuanxuObjectContract.)
  identity: 'named
  proto: (.o)
  responsibilities:
  (.o name: (yuanxu-predicate-contract 'symbol symbol? (lambda (_c _x) '()))))

(def type-contract-foundation-test
  (test-suite "project Type and Contract foundation"
    (yuanxu-test-case "native ancestry rejects lookalike objects"
      (let ((prototype (.ref NamedContract 'proto)) (contract NamedContract))
        (check-equal? (element? contract (.o (:: @ prototype) name: 'flow)) #t)
        (check-equal? (element? contract (.cc (.mix (.o) prototype) 'name 'flow)) #t)
        (check-equal? (element? contract (.o name: 'flow)) #f)))
    (yuanxu-test-case "object contracts validate inherited POO responsibility maps"
      (let* ((contract NamedContract)
             (prototype (.ref contract 'proto))
             (good (yuanxu-contract-admit contract (.o (:: @ prototype) name: 'flow) 'context))
             (missing (yuanxu-contract-admit contract (.mix prototype) 'context)))
        (check-equal? (.ref good 'accepted?) #t)
        (check-equal? (length (.ref good 'responsibility-evidence)) 1)
        (check-equal? (.ref missing 'accepted?) #f)
        (check-equal? (.ref (car (.ref missing 'responsibility-evidence)) 'responsibility) 'name)
        (check-exception (validate contract (.o (:: @ prototype) name: 42)) TypeError?)
        (check-exception (validate contract 'not-an-object) TypeError?)))
    (yuanxu-test-case "object-level refinements cannot be skipped after field admission"
      (let* ((prototype (.ref NamedContract 'proto))
             (candidate (.o (:: @ prototype) name: 'flow))
             (refined (.cc NamedContract 'proto prototype '.obligations
                           (lambda (_candidate _context) '(cross-field-denied))))
             (evidence (yuanxu-contract-admit refined candidate 'context)))
        (check-equal? (.ref evidence 'accepted?) #f)
        (check-equal? (.ref evidence 'obligation-evidence) '(cross-field-denied))
        (check-exception (validate refined candidate) TypeError?)))
    (yuanxu-test-case "object classifier must return bound complete evidence"
      (let* ((prototype (.ref NamedContract 'proto))
             (candidate (.o (:: @ prototype) name: 'flow))
             (wrong-source
              (.cc NamedContract '.classify
                   (lambda (_candidate context)
                     (yuanxu-classification-evidence 'named 'other #t '() context))))
             (wrong-context
              (.cc NamedContract '.classify
                   (lambda (value _context)
                     (yuanxu-classification-evidence 'named value #t '() 'other-context)))))
        (check-exception (yuanxu-contract-admit wrong-source candidate 'context) TypeError?)
        (check-exception (yuanxu-contract-admit wrong-context candidate 'context) TypeError?)))
    (yuanxu-test-case "classification labels do not replace the actual admission descriptor"
      (let* ((prototype (.ref NamedContract 'proto))
             (candidate (.o (:: @ prototype) name: 'flow))
             (derived
              (.cc NamedContract '.classify
                   (lambda (value context)
                     (yuanxu-classification-evidence 'other value #t '() context))))
             (evidence (yuanxu-contract-admit derived candidate 'context)))
        (check-equal? (.ref evidence 'accepted?) #t)
        (check-equal? (eq? (.ref evidence 'admission-contract) derived) #t)
        (check-equal? (eq? (.ref evidence 'admission-contract) NamedContract) #f)
        (check-equal? (.ref evidence 'contract-identity) 'named)
        (check-equal? (.ref (.ref evidence 'classification) 'type-identity) 'other)
        (check-equal? (eq? (.ref evidence 'candidate) candidate) #t)
        (check-equal? (.ref evidence 'context) 'context)))
    (yuanxu-test-case "incomplete evidence cannot pass admission or serialization"
      (let (partial (.o kind: 'yuanxu.type.classification-evidence
                        accepted?: #t diagnostics: '()))
        (check-equal? (yuanxu-classification-evidence? partial) #f)
        (check-exception (yuanxu-classification-evidence->alist partial) TypeError?))
      (let (partial (.o kind: 'yuanxu.contract.validation-evidence
                        accepted?: #t diagnostics: '()))
        (check-equal? (yuanxu-validation-evidence? partial) #f)
        (check-exception (yuanxu-validation-evidence->alist partial) TypeError?)))
    (yuanxu-test-case "structured type identities remain valid evidence"
      (let (evidence
            (yuanxu-classification-evidence
             '[Symbol] '(read) #t '() 'context))
        (check-equal? (yuanxu-classification-evidence? evidence) #t)
        (check-equal? (yuanxu-classification-evidence-accepted? evidence) #t)))
    (yuanxu-test-case "native specialization has one classification decision"
      (let* ((base (yuanxu-predicate-type 'symbol symbol?))
             (refined
              (.cc base '.classify
                   (lambda (candidate context)
                     (yuanxu-classification-evidence
                      'symbol candidate #f '(refinement-rejected) context)))))
        (check-equal? (element? base 'flow) #t)
        (check-equal? (element? refined 'flow) #f)
        (check-exception (validate refined 'flow) TypeError?)
        (check-equal? (validate base 'flow) 'flow)))
    (yuanxu-test-case "classification failure suppresses obligations"
      (let* ((contract
              (yuanxu-predicate-contract
               'symbol symbol? (lambda (_candidate _context) (error "unexpected obligation"))))
             (evidence (yuanxu-contract-admit contract 42 'context)))
        (check-equal? (yuanxu-validation-evidence? evidence) #t)
        (check-equal? (.ref evidence 'accepted?) #f)
        (check-equal? (.ref evidence 'obligation-evidence) '())))
    (yuanxu-test-case "obligation failure and forged success remain rejected"
      (let* ((contract
              (yuanxu-predicate-contract
               'symbol symbol? (lambda (_candidate _context) '(obligation-denied))))
             (evidence (yuanxu-contract-admit contract 'flow 'context)))
        (check-equal? (yuanxu-validation-evidence? evidence) #t)
        (check-equal? (.ref evidence 'accepted?) #f)
        (check-exception (validate contract 'flow) TypeError?)
        (check-equal? (yuanxu-validation-evidence? (.cc evidence 'accepted? #t)) #f)
        (check-equal? (yuanxu-validation-evidence? (.cc evidence 'candidate 'other)) #f)
        (check-equal? (yuanxu-validation-evidence? (.cc evidence 'context 'other)) #f)))
    (yuanxu-test-case "successful admission retains identity candidate and context"
      (let* ((contract (yuanxu-predicate-contract 'symbol symbol? (lambda (_c _x) '())))
             (evidence (yuanxu-contract-admit contract 'flow 'context)))
        (check-equal? (yuanxu-validation-evidence? evidence) #t)
        (check-equal? (.ref evidence 'accepted?) #t)
        (check-equal? (.ref evidence 'contract-identity) 'symbol)
        (check-equal? (validate contract 'flow) 'flow)
        (check-equal? (length (yuanxu-validation-evidence->alist evidence)) 7)))))
