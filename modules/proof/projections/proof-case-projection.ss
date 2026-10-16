;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: projects policy evidence into named proof obligations and case vectors.
;;; Invariant: proof cases retain source identities and explicit discharge status.
(import (only-in :clan/poo/object .o .ref object<-alist)
        (only-in :std/list/list find)
        :poo-flow/modules/governance/policy/authorized-effect-token)

(export poo-flow-proof-obligation
        poo-flow-proof-obligation-family-build
        poo-flow-proof-obligation-family-ref
        poo-flow-authorized-effect-obligations
        poo-flow-proof-evidence-roots
        poo-flow-authorized-effect-proof-case
        poo-flow-authorized-effect-proof-case-valid?)

(def +poo-flow-authorized-effect-obligation-layout+
  '((policy-revision-bound . 0)
    (effect-digest-bound . 1)
    (semantic-root-bound . 2)
    (execution-root-bound . 3)
    (obligation-set-complete . 4)
    (nonce-epoch-fresh . 5)
    (diagnostic-non-executable . 6)
    (l3-chain-complete . 7)))

(def (poo-flow-proof-obligation obligation-name obligation-bit
                                obligation-satisfied?)
  (.o (kind 'poo-flow-proof-obligation)
      (schema 'poo-flow.proof-obligation.v1)
      (name obligation-name)
      (bit obligation-bit)
      (satisfied? (and obligation-satisfied? #t))))

(def (poo-flow-proof-obligation-layout-ref name)
  (let (entry (assq name +poo-flow-authorized-effect-obligation-layout+))
    (and entry (cdr entry))))

(def (poo-flow-proof-obligation-valid? obligation)
  (and (eq? (.ref obligation 'kind) 'poo-flow-proof-obligation)
       (let* ((name (.ref obligation 'name))
              (bit (.ref obligation 'bit))
              (expected (poo-flow-proof-obligation-layout-ref name)))
         (and expected
              (exact-integer? bit)
              (= bit expected)))))

(def (poo-flow-proof-obligation-insert obligation obligations)
  (if (null? obligations)
      (list obligation)
      (if (< (.ref obligation 'bit) (.ref (car obligations) 'bit))
          (cons obligation obligations)
          (cons (car obligations)
                (poo-flow-proof-obligation-insert obligation
                                                  (cdr obligations))))))

(def (poo-flow-proof-obligations-sort obligations)
  (foldl poo-flow-proof-obligation-insert '() obligations))

(def (poo-flow-proof-obligations-unique? obligations)
  (car
   (foldl
    (lambda (obligation state)
      (if (not (car state))
        state
        (let ((name (.ref obligation 'name))
              (bit (.ref obligation 'bit))
              (names (cadr state))
              (bits (caddr state)))
          (if (or (memq name names) (memv bit bits))
            (list #f names bits)
            (list #t (cons name names) (cons bit bits))))))
    (list #t '() '())
    obligations)))

(def (poo-flow-proof-obligations-complete? obligations)
  (and (= (length obligations)
          (length +poo-flow-authorized-effect-obligation-layout+))
       (andmap
        (lambda (layout-entry)
          (and
           (find (lambda (obligation)
                   (eq? (car layout-entry) (.ref obligation 'name)))
                 obligations)
           #t))
        +poo-flow-authorized-effect-obligation-layout+)))

(def (poo-flow-proof-obligation-mask obligations satisfied-only?)
  (foldl
   (lambda (obligation mask)
     (if (or (not satisfied-only?)
             (.ref obligation 'satisfied?))
       (+ mask (expt 2 (.ref obligation 'bit)))
       mask))
   0
   obligations))

(def (poo-flow-proof-obligation-family-build obligations)
  (unless (and (list? obligations)
               (andmap poo-flow-proof-obligation-valid? obligations))
    (error "invalid proof obligation object" obligations))
  (unless (poo-flow-proof-obligations-unique? obligations)
    (error "duplicate proof obligation name or bit" obligations))
  (unless (poo-flow-proof-obligations-complete? obligations)
    (error "incomplete authorized-effect obligation family" obligations))
  (let* ((canonical (poo-flow-proof-obligations-sort obligations))
         (required-value
          (poo-flow-proof-obligation-mask canonical #f))
         (present-value
          (poo-flow-proof-obligation-mask canonical #t)))
    (.o (kind 'poo-flow-proof-obligation-family)
        (schema 'poo-flow.proof-obligation-family.v1)
        (name 'authorized-effect-token)
        (source 'proof-case-vector-v1)
        (obligations canonical)
        (required-mask required-value)
        (present-mask present-value)
        (complete? (= required-value present-value)))))

(def (poo-flow-proof-obligation-family-ref family name)
  (find (lambda (obligation) (eq? name (.ref obligation 'name)))
        (.ref family 'obligations)))

(def (poo-flow-authorized-effect-obligations
      policy-bound? effect-bound? semantic-bound? execution-bound?
      obligation-complete? nonce-fresh? diagnostic-safe? l3-complete?)
  (poo-flow-proof-obligation-family-build
   (list
    (poo-flow-proof-obligation 'policy-revision-bound 0 policy-bound?)
    (poo-flow-proof-obligation 'effect-digest-bound 1 effect-bound?)
    (poo-flow-proof-obligation 'semantic-root-bound 2 semantic-bound?)
    (poo-flow-proof-obligation 'execution-root-bound 3 execution-bound?)
    (poo-flow-proof-obligation 'obligation-set-complete 4 obligation-complete?)
    (poo-flow-proof-obligation 'nonce-epoch-fresh 5 nonce-fresh?)
    (poo-flow-proof-obligation 'diagnostic-non-executable 6 diagnostic-safe?)
    (poo-flow-proof-obligation 'l3-chain-complete 7 l3-complete?))))

(def (poo-flow-proof-evidence-roots semantic-value execution-value batch-value)
  (unless (and semantic-value execution-value)
    (error "proof evidence requires semantic and execution roots"))
  (.o (kind 'poo-flow-proof-evidence-roots)
      (schema 'poo-flow.proof-evidence-roots.v1)
      (semantic-root semantic-value)
      (execution-root execution-value)
      (batch-root batch-value)))

(def (poo-flow-authorized-effect-proof-case
      token-object roots-object obligation-family outcome-value sequence-value
      durability-value epoch-value previous-root-value)
  (unless (eq? (.ref token-object 'kind) 'poo-flow-authorized-effect-token)
    (error "proof case requires AuthorizedEffectToken" token-object))
  (unless (eq? (.ref roots-object 'kind) 'poo-flow-proof-evidence-roots)
    (error "proof case requires proof evidence roots" roots-object))
  (unless (and (eq? (.ref obligation-family 'kind)
                    'poo-flow-proof-obligation-family)
               (eq? (.ref obligation-family 'name) 'authorized-effect-token))
    (error "proof case requires authorized-effect obligation family"
           obligation-family))
  (let (binding-object (.ref token-object 'binding))
    (object<-alist
     (list
      (cons 'kind 'poo-flow-authorized-effect-proof-case)
      (cons 'schema 'poo-flow.proof-case-vector.v1)
      (cons 'token token-object)
      (cons 'token-id (.ref token-object 'token-id))
      (cons 'token-digest (poo-flow-authorized-effect-token-digest token-object))
      (cons 'binding binding-object)
      (cons 'policy-revision (.ref binding-object 'policy-digest))
      (cons 'effect-digest (poo-flow-effect-binding-digest binding-object))
      (cons 'subject-binding (.ref binding-object 'entity-digest))
      (cons 'resource-binding (.ref binding-object 'payload-digest))
      (cons 'action-binding (.ref binding-object 'intent-digest))
      (cons 'nonce (.ref token-object 'nonce))
      (cons 'epoch epoch-value) (cons 'sequence sequence-value)
      (cons 'semantic-root (.ref roots-object 'semantic-root))
      (cons 'execution-root (.ref roots-object 'execution-root))
      (cons 'batch-root (.ref roots-object 'batch-root))
      (cons 'previous-evidence-root previous-root-value)
      (cons 'outcome outcome-value) (cons 'durability durability-value)
      (cons 'obligations obligation-family)
      (cons 'required-obligation-mask (.ref obligation-family 'required-mask))
      (cons 'present-obligation-mask (.ref obligation-family 'present-mask))
      (cons 'obligation-count (length (.ref obligation-family 'obligations)))))))

(def (poo-flow-authorized-effect-proof-case-valid? proof-case)
  (and (eq? (.ref proof-case 'kind) 'poo-flow-authorized-effect-proof-case)
       (= (.ref proof-case 'required-obligation-mask)
          (.ref proof-case 'present-obligation-mask))
       (= (.ref proof-case 'obligation-count)
          (length +poo-flow-authorized-effect-obligation-layout+))
       (not (eq? (.ref proof-case 'durability) 'diagnostic))
       (memq (.ref proof-case 'outcome) '(committed denied indeterminate))
       #t))
