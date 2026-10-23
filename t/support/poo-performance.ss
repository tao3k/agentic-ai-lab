;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: shared fixtures and helpers for POO performance scenario tests.

(import (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-fixture-ref
                 benchmark-receipt-pass?
                 benchmark-run)
        "./poo-performance-fixtures"
        "./poo-performance-object-scenarios"
        (only-in :clan/poo/object
                 .all-slots
                 .def
                 .get
                 .mix
                 .o
                 .putdefault!
                 .ref
                 .setslot!
                 $constant-slot-spec)
        :yuanxu/object-family/indexed)

(export poo-performance-fixture-policy-contract-pass?
        poo-performance-display-receipt
        poo-performance-run-gate
        poo-performance-required-form-evidence
        poo-performance-required-usage-call-evidence
        poo-performance-symbol-member?
        poo-performance-evidence-covers?
        poo-performance-api-evidence-contract-pass?
        poo-performance-api-usage-call-receipt
        poo-performance-family
        poo-performance-family-alist
        poo-performance-family-ref
        poo-performance-family-run-gate
        poo-performance-family-descriptor-vector
        poo-performance-family-slot-lens
        poo-performance-family-slot-lens-ref
        poo-performance-indexed-family
        poo-performance-indexed-family-object
        poo-performance-indexed-family-ref
        poo-performance-indexed-family-slot-lens
        poo-performance-indexed-family-slot-lens-ref
        poo-performance-indexed-family-lenses
        poo-performance-indexed-family-project-descriptors
        +poo-performance-benchmark-receipt-family+
        +poo-performance-large-runtime-profile-family+
        +poo-performance-large-runtime-profile-layout+
        +poo-performance-large-runtime-profile-lenses+
        +poo-performance-fixed-slot-projection-family+
        poo-performance-large-profile-projection-descriptors
        poo-performance-large-profile-indexed-object
        poo-performance-large-profile-indexed-descriptors
        poo-performance-large-profile-indexed-valid-count
        poo-performance-large-profile-projection-valid-count
        poo-performance-large-profile-projection-gate-receipt
        poo-performance-generated-receipt-boundary-alist
        poo-performance-generated-receipt-boundary->alist
        poo-performance-generated-receipt-boundary-valid-count
        poo-performance-generated-receipt-boundary-gate-receipt)

;; : [Symbol]
(def poo-performance-required-policy-keys
  '(benchmarkKind
    max_total
    target_total
    regression_budget
    expected_over_input_budget
    targetRationale
    sampleCount
    sourcePath
    rule
    feature
    optimizationFocus
    inputShape
    expectedOutcome
    expectedRepair
    pooFormEvidence
    pooUsageCallEvidence
    measurementPhases
    tags))

;; : (-> Alist [Symbol] Boolean)
(def (poo-performance-fixture-keys-present? fixture keys)
  (not (ormap (lambda (key)
                (not (assoc key fixture)))
              keys)))

;; : (-> Alist Symbol Boolean)
(def (poo-performance-fixture-nonempty-string? fixture key)
  (let (value (poo-performance-slot-ref/default fixture key #f))
    (and (string? value) (> (string-length value) 0))))

;; : (-> Alist Boolean)
(def (poo-performance-source-path-contract-pass? fixture)
  (let (source-path (poo-performance-slot-ref/default
                    fixture
                    'sourcePath
                    #f))
    (and (string? source-path)
         (> (string-length source-path) 0)
         (file-exists? source-path))))

;; : (-> Alist Boolean)
(def (poo-performance-text-policy-contract-pass? fixture)
  (and (poo-performance-fixture-nonempty-string? fixture 'targetRationale)
       (poo-performance-fixture-nonempty-string? fixture 'optimizationFocus)
       (poo-performance-fixture-nonempty-string? fixture 'inputShape)
       (poo-performance-fixture-nonempty-string? fixture 'expectedRepair)
       (symbol? (poo-performance-slot-ref/default fixture 'rule #f))
       (symbol? (poo-performance-slot-ref/default fixture 'feature #f))))

;; : (-> Alist Boolean)
(def (poo-performance-measurement-phase-contract-pass? fixture)
  (let (phases (poo-performance-slot-ref/default
                fixture
                'measurementPhases
                #f))
    (and (list? phases)
         (poo-performance-symbol-member? phases 'assert-time-gate)
         (poo-performance-symbol-member? phases 'observe-runtime-memory))))

;; : (-> Alist Boolean)
(def (poo-performance-tags-contract-pass? fixture)
  (let (tags (poo-performance-slot-ref/default fixture 'tags #f))
    (and (list? tags)
         (poo-performance-symbol-member? tags 'poo)
         (poo-performance-symbol-member? tags 'performance))))

;; : (-> Alist Boolean)
(def (poo-performance-fixture-policy-contract-pass? fixture)
  (and (benchmark-fixture-contract-pass? fixture)
       (poo-performance-fixture-keys-present?
       fixture
       poo-performance-required-policy-keys)
       (poo-performance-source-path-contract-pass? fixture)
       (poo-performance-text-policy-contract-pass? fixture)
       (poo-performance-measurement-phase-contract-pass? fixture)
       (poo-performance-tags-contract-pass? fixture)
       (poo-performance-api-evidence-contract-pass? fixture)))

;; : (-> Alist Unit)
(def (poo-performance-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] ")
  (write (benchmark-fixture-ref receipt 'feature))
  (display " ")
  (write receipt)
  (newline)
  (force-output))

;; poo-performance-run-gate
;;   : (-> Alist (-> Object) Alist)
;;   | doc m%
;;       Checks the local POO benchmark policy contract before entering the
;;       measured thunk, so scenario gates fail before they allocate work.
;;
;;       # Examples
;;       ```scheme
;;       (benchmark-receipt-pass?
;;        (poo-performance-run-gate
;;         (poo-performance-fixed-slot-projection-fixture)
;;         (lambda () 1)))
;;       ;; => #t
;;       ```
;;     %
(def (poo-performance-run-gate fixture thunk)
  (if (poo-performance-fixture-policy-contract-pass? fixture)
    (benchmark-run fixture thunk)
    (error "poo performance fixture policy contract failed" fixture)))

;; : [Symbol]
(def poo-performance-required-form-evidence
  '(.o .def defpoo))

;; : [Symbol]
(def poo-performance-required-usage-call-evidence
  '(.ref .get .mix .o .def .putdefault! .setslot! setslots! .all-slots))

;; poo-performance-symbol-member?
;;   : (-> [Symbol] Symbol Boolean)
;;   | doc m%
;;       `poo-performance-symbol-member? values value` checks whether benchmark
;;       evidence includes one required POO API symbol using symbol identity.
;;
;;       # Examples
;;       ```scheme
;;       (poo-performance-symbol-member? '(.o .def) '.o)
;;       ;; => #t
;;       ```
;;     %
(def (poo-performance-symbol-member? values value)
  (ormap (lambda (candidate)
           (eq? candidate value))
         values))

;; poo-performance-evidence-covers?
;;   : (-> Alist Symbol [Symbol] Boolean)
;;   | doc m%
;;       `poo-performance-evidence-covers? fixture key required` verifies that
;;       a benchmark fixture records every required API witness under `key`.
;;
;;       # Examples
;;       ```scheme
;;       (poo-performance-evidence-covers?
;;        '((pooFormEvidence . (.o .def defpoo)))
;;        'pooFormEvidence
;;        '(.o .def))
;;       ;; => #t
;;       ```
;;     %
(def (poo-performance-evidence-covers? fixture key required)
  (let (values (benchmark-fixture-ref fixture key))
    (and (list? values)
         (not (ormap (lambda (required-value)
                       (not (poo-performance-symbol-member?
                             values
                             required-value)))
                     required)))))

;; : (-> Alist Boolean)
(def (poo-performance-api-evidence-contract-pass? fixture)
  (and (poo-performance-evidence-covers?
        fixture
        'pooFormEvidence
        poo-performance-required-form-evidence)
       (poo-performance-evidence-covers?
        fixture
        'pooUsageCallEvidence
        poo-performance-required-usage-call-evidence)))

;; : (-> Alist)
(def (poo-performance-api-usage-call-receipt)
  (let (object (.mix (.o (color 'blue))
                     (.o (name 'poo-api-evidence)
                         (field-count 2))))
    (.putdefault! object 'fallback 'defaulted)
    (.setslot! object dynamic ($constant-slot-spec 'slot-added-through-api))
    (list (cons 'name (.ref object 'name))
          (cons 'color (.get object color))
          (cons 'fallback (.get object fallback))
          (cons 'dynamic (.get object dynamic))
          (cons 'slots (.all-slots object)))))

;; : (-> Symbol Symbol PooObject)
(def (poo-performance-family family-name source-tag)
  (.o (kind 'poo-performance-family)
      (name family-name)
      (source source-tag)))

;; : PooObject
(def +poo-performance-benchmark-receipt-family+
  (poo-performance-family 'poo-performance-benchmark-receipt-family
                          'agentic-ai-lab.performance.benchmark))

;; : PooObject
(def +poo-performance-large-runtime-profile-family+
  (poo-performance-family 'poo-performance-large-runtime-profile-family
                          'agentic-ai-lab.performance.large-runtime-profile))

;; : PooObject
(def +poo-performance-fixed-slot-projection-family+
  (poo-performance-family 'poo-performance-fixed-slot-projection-family
                          'agentic-ai-lab.performance.fixed-slot-projection))

;; : (-> PooObject Alist Alist)
(def (poo-performance-family-alist family alist)
  (let* ((family-name (.ref family 'name))
         (source-tag (.ref family 'source))
         (with-family
          (if (assoc 'family alist)
            alist
            (cons (cons 'family family-name) alist))))
    (if (or (not source-tag) (assoc 'source with-family))
      with-family
      (cons (cons 'source source-tag) with-family))))

;; : (-> PooObject Alist Symbol Object Object)
(def (poo-performance-family-ref family alist key default-value)
  (if (eq? (poo-performance-slot-ref/default
            alist
            'family
            #f)
           (.ref family 'name))
    (poo-performance-slot-ref/default alist key default-value)
    default-value))

;; : (-> PooObject Alist (-> Object) Alist)
(def (poo-performance-family-run-gate family fixture thunk)
  (poo-performance-family-alist
   family
   (poo-performance-run-gate fixture thunk)))

;; : (-> (Listof Symbol) Alist)
(def (poo-performance-index-slots slot-names)
  (poo-index-slots slot-names))

;; : (-> Symbol Symbol (Listof Symbol) POOObject)
(def (poo-performance-indexed-family family-name source-tag slot-names)
  (poo-indexed-family family-name source-tag slot-names))

;; : (-> POOObject Symbol (Maybe Fixnum))
(def (poo-performance-indexed-family-slot-index family-object slot-name)
  (poo-indexed-family-slot-index family-object slot-name))

;; : (-> POOObject [Object] POOObject)
(def (poo-performance-indexed-family-object family-object values)
  (poo-indexed-family-object family-object values))

;; : (-> POOObject POOObject Symbol Object Object)
(def (poo-performance-indexed-family-ref family-object object slot-name default-value)
  (poo-indexed-family-ref family-object object slot-name default-value))

;; : (-> POOObject Symbol Symbol POOObject)
(def (poo-performance-indexed-family-named-slot-lens family-object slot-name descriptor-name)
  (poo-indexed-family-named-slot-lens family-object
                                      slot-name
                                      descriptor-name))

;; : (-> POOObject Symbol POOObject)
(def (poo-performance-indexed-family-slot-lens family-object slot-name)
  (poo-indexed-family-slot-lens family-object slot-name))

;; : (-> POOObject Alist Vector)
(def (poo-performance-indexed-family-lenses family-object specs)
  (poo-indexed-family-lenses family-object specs))

;; : (-> POOObject POOObject Object Object)
(def (poo-performance-indexed-family-slot-lens-ref lens object default-value)
  (poo-indexed-family-slot-lens-ref lens object default-value))

;; : (-> POOObject POOObject Vector Vector)
(def (poo-performance-indexed-family-project-descriptors family-object object lenses)
  (poo-indexed-family-project-descriptors
   family-object
   object
   lenses
   (lambda (descriptor-family descriptor-name value)
     (poo-performance-family-alist
      descriptor-family
      (list (cons 'name descriptor-name)
            (cons 'value value))))))

;; : (-> PooObject PooObject Pair Alist)
(def (poo-performance-family-descriptor family object spec)
  (poo-performance-family-alist
   family
   (list (cons 'name (cdr spec))
         (cons 'value (.ref object (car spec))))))

;; poo-performance-family-descriptor-vector
;;   : (-> PooObject PooObject Alist Vector)
;;   | doc m%
;;       Projects a POO object through an explicit slot descriptor alist and
;;       returns vectorized descriptor rows for benchmark receipt boundaries.
;;
;;       # Examples
;;       ```scheme
;;       (vector-length
;;        (poo-performance-family-descriptor-vector
;;         +poo-performance-large-runtime-profile-family+
;;         (.o (profile-id 'example))
;;         '((profile-id . profile-id))))
;;       ;; => 1
;;       ```
;;     %
(def (poo-performance-family-descriptor-vector family object specs)
  (list->vector
   (map (lambda (spec)
          (poo-performance-family-descriptor family object spec))
        specs)))

;; : (-> PooObject Symbol PooObject)
(def (poo-performance-family-slot-lens family-object slot-name)
  (.o (kind 'poo-performance-family-slot-lens)
      (family family-object)
      (slot slot-name)))

;; : (-> PooObject PooObject Object)
(def (poo-performance-family-slot-lens-ref lens object)
  (.ref object (.ref lens 'slot)))

;; : Alist
(def +poo-performance-large-profile-projection-specs+
  '((profile-id . profile-id)
    (policy . policy)
    (strategy . strategy)
    (sandbox . sandbox)
    (tool-scope . tool-scope)
    (checkpoint . checkpoint)
    (handoff . handoff)
    (proof . proof)
    (priority . priority)
    (limit . limit)))

;; : POOObject
(def +poo-performance-large-runtime-profile-layout+
  (poo-performance-indexed-family
   'poo-performance-large-runtime-profile-family
   'agentic-ai-lab.performance.large-runtime-profile
   (map car +poo-performance-large-profile-projection-specs+)))

;; : Vector
(def +poo-performance-large-runtime-profile-lenses+
  (poo-performance-indexed-family-lenses
   +poo-performance-large-runtime-profile-layout+
   +poo-performance-large-profile-projection-specs+))

;; : (-> PooObject)
(def (poo-performance-large-profile-projection-profile)
  (.o (profile-id 'large-profile)
      (family 'poo-performance-large-runtime-profile-family)
      (policy 'loop-policy)
      (strategy 'graph-strategy)
      (sandbox 'scoped-sandbox)
      (tool-scope 'declared-tools)
      (checkpoint 'durable-checkpoint)
      (handoff 'runtime-language)
      (proof 'lean-required)
      (priority 7)
      (limit 128)))

;; : (-> Vector)
(def (poo-performance-large-profile-projection-descriptors)
  (let (profile (poo-performance-large-profile-projection-profile))
    (poo-performance-family-descriptor-vector
     +poo-performance-large-runtime-profile-family+
     profile
     +poo-performance-large-profile-projection-specs+)))

;; : (-> PooObject)
(def (poo-performance-large-profile-indexed-object)
  (poo-performance-indexed-family-object
   +poo-performance-large-runtime-profile-layout+
   '(large-profile
     loop-policy
     graph-strategy
     scoped-sandbox
     declared-tools
     durable-checkpoint
     runtime-language
     lean-required
     7
     128)))

;; : (-> Vector)
(def (poo-performance-large-profile-indexed-descriptors)
  (poo-performance-indexed-family-project-descriptors
   +poo-performance-large-runtime-profile-layout+
   (poo-performance-large-profile-indexed-object)
   +poo-performance-large-runtime-profile-lenses+))

;; : (-> Integer Integer)
(def (poo-performance-large-profile-indexed-valid-count rounds)
  (let* ((object (poo-performance-large-profile-indexed-object))
         (lenses +poo-performance-large-runtime-profile-lenses+)
         (count (vector-length lenses))
         (first-lens (vector-ref lenses 0))
         (last-lens (vector-ref lenses (- count 1))))
    (if (and (= count 10)
             (eq? (.ref object 'family)
                  +poo-performance-large-runtime-profile-layout+)
             (eq? (poo-performance-indexed-family-slot-lens-ref
                   first-lens
                   object
                   #f)
                  'large-profile)
             (= (poo-performance-indexed-family-slot-lens-ref
                 last-lens
                 object
                 #f)
                128))
      rounds
      0)))

;; : (-> Integer Integer)
(def (poo-performance-large-profile-projection-valid-count rounds)
  (let* ((descriptors
          (poo-performance-large-profile-projection-descriptors))
         (count (vector-length descriptors))
         (first-descriptor (vector-ref descriptors 0))
         (last-descriptor (vector-ref descriptors (- count 1)))
         (valid?
          (and (= count 10)
               (eq? (poo-performance-family-ref
                     +poo-performance-large-runtime-profile-family+
                     first-descriptor
                     'name
                     #f)
                    'profile-id)
               (eq? (cdr (assoc 'value first-descriptor)) 'large-profile)
               (= (cdr (assoc 'value last-descriptor)) 128))))
    (if valid? rounds 0)))

;; : (-> Integer Alist)
(def (poo-performance-large-profile-projection-gate-receipt rounds)
  (poo-performance-family-run-gate
   +poo-performance-benchmark-receipt-family+
   (poo-performance-large-profile-projection-fixture)
   (lambda ()
     (poo-performance-large-profile-projection-valid-count rounds))))

;; : PooPerformanceGeneratedLoopReceipt
(defstruct poo-performance-generated-loop-receipt
  (profile-id status runtime checkpoint sandbox tool-scope proof))

;; : (-> Integer PooPerformanceGeneratedLoopReceipt)
(def (poo-performance-generated-receipt-boundary-record index)
  (make-poo-performance-generated-loop-receipt
   index
   'ready
   'runtime-language
   'durable-checkpoint
   'scoped-sandbox
   'declared-tools
   'lean-required))

;; : (-> PooPerformanceGeneratedLoopReceipt Alist)
(def (poo-performance-generated-receipt-boundary->alist receipt)
  (poo-performance-family-alist
   +poo-performance-benchmark-receipt-family+
   (list
    (cons 'profile-id
          (poo-performance-generated-loop-receipt-profile-id receipt))
    (cons 'status
          (poo-performance-generated-loop-receipt-status receipt))
    (cons 'runtime
          (poo-performance-generated-loop-receipt-runtime receipt))
    (cons 'checkpoint
          (poo-performance-generated-loop-receipt-checkpoint receipt))
    (cons 'sandbox
          (poo-performance-generated-loop-receipt-sandbox receipt))
    (cons 'tool-scope
          (poo-performance-generated-loop-receipt-tool-scope receipt))
    (cons 'proof
          (poo-performance-generated-loop-receipt-proof receipt)))))

;; : (-> Alist)
(def (poo-performance-generated-receipt-boundary-alist)
  (poo-performance-generated-receipt-boundary->alist
   (poo-performance-generated-receipt-boundary-record 41)))

;; : (-> Integer Integer)
(def (poo-performance-generated-receipt-boundary-valid-count rounds)
  (let* ((receipt-alist
          (poo-performance-generated-receipt-boundary-alist))
         (valid?
          (and (= (cdr (assoc 'profile-id receipt-alist)) 41)
               (eq? (cdr (assoc 'status receipt-alist)) 'ready)
               (eq? (cdr (assoc 'proof receipt-alist)) 'lean-required))))
    (if valid? rounds 0)))

;; : (-> Integer Alist)
(def (poo-performance-generated-receipt-boundary-gate-receipt rounds)
  (poo-performance-family-run-gate
   +poo-performance-benchmark-receipt-family+
   (poo-performance-generated-receipt-boundary-fixture)
   (lambda ()
     (poo-performance-generated-receipt-boundary-valid-count rounds))))
