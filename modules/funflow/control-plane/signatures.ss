;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Flow edges use ordinary runtime Function descriptors, not signature labels.
(import :clan/poo/object
        (only-in :clan/poo/type Type Type. Function Function. Fun Any Bool validate element?
                 raise-type-error String Symbol List Pair Null Unit Sum OrFalse Record Exactly
                 Union)
        (only-in :clan/poo/mop prototype-instance?)
        (only-in :clan/poo/number Number Integer)
        (only-in :clan/poo/types/relation subtype-expression? capture-type-catalog type-refusal? type-refusal-kind type-work)
        (only-in :clan/poo/types/optional-validation catalog-type? catalog-descriptor)
        :tao3k/agentic-ai-lab/modules/funflow/control-plane/failure)
(export OperationSignature operation-input operation-output admit-operation-signature
        type-flows? require-type-flow! type-description PairValue TryValue
        Type Type. Function Fun Any Bool String Symbol List Pair Null Unit OrFalse Record Exactly Union Number Integer
        validate element? raise-type-error)


;; The interpreter carries one value on each edge. Higher-order values still
;; have arbitrary runtime Function signatures inside that single value.
(def OperationSignature
  (.cc Type. sexp: 'FunflowOperationSignature
    '.element?
    (lambda (value)
      (and (prototype-instance? Function. value)
           (= (length (.get value inputs)) 1) (= (length (.get value outputs)) 1)
           (null? (.get value optional)) (null? (.get value keywords))
           (not (.get value rest))
           (= (length (.get value signatures)) 1)))))
(def (admit-operation-signature signature) (validate OperationSignature signature))
(def (operation-input signature) (car (.get (admit-operation-signature signature) inputs)))
(def (operation-output signature) (car (.get (admit-operation-signature signature) outputs)))

;; Runtime finite relations own supported structural subtyping. Opaque domain
;; Types compose by identity; an unsupported relation never becomes approval.
(def (type-flows? actual expected)
  (or (eq? actual expected)
      (with-catch
        (lambda (cause)
          (if (and (type-refusal? cause) (eq? (type-refusal-kind cause) 'unsupported))
            ;; The runtime catalog represents opaque Types by actual identity.
            ;; In particular it proves an opaque source may flow to runtime Any;
            ;; it does not infer inclusion between unrelated predicates.
            (let (directory (capture-type-catalog (.o Source: actual Target: expected) '(Source Target)))
              (subtype-expression? (cdr (assq 'Source directory))
                (if (eq? expected Any) 'Any (cdr (assq 'Target directory)))))
            (raise cause)))
        (lambda () (subtype-expression? (.get actual sexp) (.get expected sexp))))))
(def (require-type-flow! actual expected)
  (unless (type-flows? actual expected)
    (error "incompatible Flow edge" actual expected)))
(def (PairValue left right) (Pair left (Pair right Null)))
;; An opaque domain descriptor enters the runtime finite relation through its
;; captured identity, never through a public symbol pretending to be a Type.
(def failure-catalog
  (capture-type-catalog (.o Failure: ExecutionFailureType) '(Failure)))
(def failure-expression (cdr (assq 'Failure failure-catalog)))
(def (TryValue result-type)
  (.cc (Sum left: ExecutionFailureType right: result-type)
    sexp: (list 'Sum left: failure-expression right: (.get result-type sexp))))

;; Boundary projection only: runtime catalog tokens keep their authority in
;; memory. Reports carry the underlying descriptor's descriptive data instead.
(def (type-description descriptor)
  (def work (type-work 8192))
  (let project ((term (.get descriptor sexp)))
    (work)
    (cond
      ((catalog-type? term) (project (.get (catalog-descriptor term work) sexp)))
      ((pair? term) (cons (project (car term)) (project (cdr term))))
      (else term))))
