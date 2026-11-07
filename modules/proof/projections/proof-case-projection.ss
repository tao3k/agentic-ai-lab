;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: projects policy evidence into named proof obligations and case vectors.
;;; Invariant: proof cases retain source identities and explicit discharge status.
(import (only-in :clan/poo/object .o .ref object<-alist)
        (only-in :std/list/list find)
        :agentic-ai-lab/modules/governance/policy/authorized-effect-token)

(export agentic-ai-lab-proof-obligation
        agentic-ai-lab-proof-obligation-family-build
        agentic-ai-lab-proof-obligation-family-ref
        agentic-ai-lab-authorized-effect-obligations
        agentic-ai-lab-proof-evidence-roots
        agentic-ai-lab-authorized-effect-proof-case
        agentic-ai-lab-authorized-effect-proof-case-valid?)

(def +agentic-ai-lab-authorized-effect-obligation-layout+
  '((policy-revision-bound . 0)
    (effect-digest-bound . 1)
    (semantic-root-bound . 2)
    (execution-root-bound . 3)
    (obligation-set-complete . 4)
    (nonce-epoch-fresh . 5)
    (diagnostic-non-executable . 6)
    (l3-chain-complete . 7)))

(def (agentic-ai-lab-proof-obligation obligation-name obligation-bit
                                obligation-satisfied?)
  (.o (kind 'agentic-ai-lab-proof-obligation)
      (schema 'agentic-ai-lab.proof-obligation.v1)
      (name obligation-name)
      (bit obligation-bit)
      (satisfied? (and obligation-satisfied? #t))))

(def (agentic-ai-lab-proof-obligation-layout-ref name)
  (let (entry (assq name +agentic-ai-lab-authorized-effect-obligation-layout+))
    (and entry (cdr entry))))

(def (agentic-ai-lab-proof-obligation-valid? obligation)
  (and (eq? (.ref obligation 'kind) 'agentic-ai-lab-proof-obligation)
       (let* ((name (.ref obligation 'name))
              (bit (.ref obligation 'bit))
              (expected (agentic-ai-lab-proof-obligation-layout-ref name)))
         (and expected
              (exact-integer? bit)
              (= bit expected)))))

(def (agentic-ai-lab-proof-obligation-insert obligation obligations)
  (if (null? obligations)
      (list obligation)
      (if (< (.ref obligation 'bit) (.ref (car obligations) 'bit))
          (cons obligation obligations)
          (cons (car obligations)
                (agentic-ai-lab-proof-obligation-insert obligation
                                                  (cdr obligations))))))

(def (agentic-ai-lab-proof-obligations-sort obligations)
  (foldl agentic-ai-lab-proof-obligation-insert '() obligations))

(def (agentic-ai-lab-proof-obligations-unique? obligations)
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

(def (agentic-ai-lab-proof-obligations-complete? obligations)
  (and (= (length obligations)
          (length +agentic-ai-lab-authorized-effect-obligation-layout+))
       (andmap
        (lambda (layout-entry)
          (and
           (find (lambda (obligation)
                   (eq? (car layout-entry) (.ref obligation 'name)))
                 obligations)
           #t))
        +agentic-ai-lab-authorized-effect-obligation-layout+)))

(def (agentic-ai-lab-proof-obligation-mask obligations satisfied-only?)
  (foldl
   (lambda (obligation mask)
     (if (or (not satisfied-only?)
             (.ref obligation 'satisfied?))
       (+ mask (expt 2 (.ref obligation 'bit)))
       mask))
   0
   obligations))

(def (agentic-ai-lab-proof-obligation-family-build obligations)
  (unless (and (list? obligations)
               (andmap agentic-ai-lab-proof-obligation-valid? obligations))
    (error "invalid proof obligation object" obligations))
  (unless (agentic-ai-lab-proof-obligations-unique? obligations)
    (error "duplicate proof obligation name or bit" obligations))
  (unless (agentic-ai-lab-proof-obligations-complete? obligations)
    (error "incomplete authorized-effect obligation family" obligations))
  (let* ((canonical (agentic-ai-lab-proof-obligations-sort obligations))
         (required-value
          (agentic-ai-lab-proof-obligation-mask canonical #f))
         (present-value
          (agentic-ai-lab-proof-obligation-mask canonical #t)))
    (.o (kind 'agentic-ai-lab-proof-obligation-family)
        (schema 'agentic-ai-lab.proof-obligation-family.v1)
        (name 'authorized-effect-token)
        (source 'proof-case-vector-v1)
        (obligations canonical)
        (required-mask required-value)
        (present-mask present-value)
        (complete? (= required-value present-value)))))

(def (agentic-ai-lab-proof-obligation-family-ref family name)
  (find (lambda (obligation) (eq? name (.ref obligation 'name)))
        (.ref family 'obligations)))

(def (agentic-ai-lab-authorized-effect-obligations
      policy-bound? effect-bound? semantic-bound? execution-bound?
      obligation-complete? nonce-fresh? diagnostic-safe? l3-complete?)
  (agentic-ai-lab-proof-obligation-family-build
   (list
    (agentic-ai-lab-proof-obligation 'policy-revision-bound 0 policy-bound?)
    (agentic-ai-lab-proof-obligation 'effect-digest-bound 1 effect-bound?)
    (agentic-ai-lab-proof-obligation 'semantic-root-bound 2 semantic-bound?)
    (agentic-ai-lab-proof-obligation 'execution-root-bound 3 execution-bound?)
    (agentic-ai-lab-proof-obligation 'obligation-set-complete 4 obligation-complete?)
    (agentic-ai-lab-proof-obligation 'nonce-epoch-fresh 5 nonce-fresh?)
    (agentic-ai-lab-proof-obligation 'diagnostic-non-executable 6 diagnostic-safe?)
    (agentic-ai-lab-proof-obligation 'l3-chain-complete 7 l3-complete?))))

(def (agentic-ai-lab-proof-evidence-roots semantic-value execution-value batch-value)
  (unless (and semantic-value execution-value)
    (error "proof evidence requires semantic and execution roots"))
  (.o (kind 'agentic-ai-lab-proof-evidence-roots)
      (schema 'agentic-ai-lab.proof-evidence-roots.v1)
      (semantic-root semantic-value)
      (execution-root execution-value)
      (batch-root batch-value)))

(def (agentic-ai-lab-authorized-effect-proof-case
      token-object roots-object obligation-family outcome-value sequence-value
      durability-value epoch-value previous-root-value)
  (unless (eq? (.ref token-object 'kind) 'agentic-ai-lab-authorized-effect-token)
    (error "proof case requires AuthorizedEffectToken" token-object))
  (unless (eq? (.ref roots-object 'kind) 'agentic-ai-lab-proof-evidence-roots)
    (error "proof case requires proof evidence roots" roots-object))
  (unless (and (eq? (.ref obligation-family 'kind)
                    'agentic-ai-lab-proof-obligation-family)
               (eq? (.ref obligation-family 'name) 'authorized-effect-token))
    (error "proof case requires authorized-effect obligation family"
           obligation-family))
  (let (binding-object (.ref token-object 'binding))
    (object<-alist
     (list
      (cons 'kind 'agentic-ai-lab-authorized-effect-proof-case)
      (cons 'schema 'agentic-ai-lab.proof-case-vector.v1)
      (cons 'token token-object)
      (cons 'token-id (.ref token-object 'token-id))
      (cons 'token-digest (agentic-ai-lab-authorized-effect-token-digest token-object))
      (cons 'binding binding-object)
      (cons 'policy-revision (.ref binding-object 'policy-digest))
      (cons 'effect-digest (agentic-ai-lab-effect-binding-digest binding-object))
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

(def (agentic-ai-lab-authorized-effect-proof-case-valid? proof-case)
  (and (eq? (.ref proof-case 'kind) 'agentic-ai-lab-authorized-effect-proof-case)
       (= (.ref proof-case 'required-obligation-mask)
          (.ref proof-case 'present-obligation-mask))
       (= (.ref proof-case 'obligation-count)
          (length +agentic-ai-lab-authorized-effect-obligation-layout+))
       (not (eq? (.ref proof-case 'durability) 'diagnostic))
       (memq (.ref proof-case 'outcome) '(committed denied indeterminate))
       #t))
