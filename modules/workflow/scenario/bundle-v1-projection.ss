;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: serializes validated feature compositions as Bundle v1 images.
;;; Invariant: writing preserves the lowering result and canonical content identity.
(export poo-flow-scenario-case->bundle-v1-image
        poo-flow-write-composition-bundle-v1!
        poo-flow-write-composition-bundle-v1/from-environment!)

(import (only-in :std/format format)
        (only-in :clan/poo/object .ref .slot?)
        :poo-flow/modules/workflow/control-plane/plan
        (only-in :poo-flow/modules/workflow/scenario/plan-projection
                 poo-flow-scenario-case->execution-plan)
        :core/feature-system/bundle-v1-lowering
        :core/feature-system/bundle-v1-foreign-arena
        :core/feature-system/bundle-v1-writer)

;; : (-> PooPlanNode String)
(def (plan-node-semantic-id node)
  (format "%s" (plan-node-id node)))

;;; Guard declarations are data. POO Flow compiles them into Bundle v1
;;; policy metadata; an admitted receipt is supplied by the execution runtime.
(def +poo-flow-bundle-v1-guard-symbol-kind+ 2)

;; : (-> Object String)
(def (guard->string guard)
  (if (string? guard)
    guard
    (call-with-output-string (lambda (port) (write guard port)))))

;; : (-> Object Object)
(def (guard-unbox value)
  (if (and (pair? value) (null? (cdr value)) (pair? (car value)))
    (guard-unbox (car value))
    value))

;; : (-> List String)
(def (guard-payload->string payload)
  (unless (and (pair? payload) (null? (cdr payload)))
    (error "POO-FLOW-GUARD-E001 guard expects exactly one declaration" payload))
  (guard->string (guard-unbox (car payload))))

;; : (-> PooCompositionStage MaybeString)
(def (stage-guard stage)
  (and (.slot? stage 'guard)
       (guard->string (.ref stage 'guard))))

;; : (-> PooComposition Symbol MaybeString)
(def (profile-guard composition profile-name)
  (let loop ((profiles (.ref composition 'profiles)))
    (cond
     ((null? profiles) #f)
     ((eq? (.ref (car profiles)
                 (if (.slot? (car profiles) 'identity) 'identity 'name))
           profile-name)
      (let ((profile (car profiles)))
        (if (and (.slot? profile 'guard) (.ref profile 'guard))
          (guard->string (.ref profile 'guard))
          #f)))
     (else (loop (cdr profiles))))))

;; : (-> PooComposition PooPlanNode MaybeString)
(def (plan-node-guard composition node)
  (case (plan-node-kind node)
    ((case) (stage-guard (plan-node-step node)))
    ((profile-instance) (profile-guard composition (plan-node-name node)))
    (else #f)))

;; : (-> PooPlanNode String)
(def (plan-node-policy-id node)
  (string-append (plan-node-semantic-id node) ".guard"))

;; : (-> PooExecutionPlan PooComposition [PooFeatureBundleV1Component])
(def (plan-components plan composition)
  (map
   (lambda (node)
     (let* ((semantic-id (plan-node-semantic-id node))
            (guard (plan-node-guard composition node))
            (policy-id (if guard (plan-node-policy-id node) 'poo-flow.policy.none)))
       (feature-bundle-v1-component
        (execution-plan-flow-name plan)
        semantic-id
        semantic-id
        (plan-node-kind node)
        'poo-flow.contract.none
        (plan-node-kind node)
        (plan-node-name node)
        policy-id
        'poo-flow.strategy.none
        +feature-bundle-v1-no-adapter-id+
        +feature-bundle-v1-no-projection-id+
        (plan-node-ordinal node))))
   (execution-plan-nodes plan)))

;; : (-> PooExecutionPlan PooComposition [PooFeatureBundleV1Symbol])
(def (plan-symbols plan composition)
  (append
   (map
    (lambda (node)
      (feature-bundle-v1-symbol
       'component
       (plan-node-semantic-id node)
       (symbol->string (plan-node-name node))
       1))
    (execution-plan-nodes plan))
   (filter-map
    (lambda (node)
      (let (guard (plan-node-guard composition node))
        (and guard
             (feature-bundle-v1-symbol
              'policy
              (plan-node-policy-id node)
              guard
              +poo-flow-bundle-v1-guard-symbol-kind+))))
    (execution-plan-nodes plan))))

;; : (-> PooExecutionPlan [PooFeatureBundleV1Edge])
(def (plan-edges plan)
  (let (order+edges-reversed
        (foldl
         (lambda (edge state)
           (let (order (car state))
             (cons
              (+ order 1)
              (cons
               (feature-bundle-v1-edge
                (execution-plan-flow-name plan)
                (format "%s" (car edge))
                (format "%s" (cadr edge))
                'poo-flow.bundle-v1.plan-dependency
                order)
               (cdr state)))))
         (cons 0 '())
         (execution-plan-dependency-edges plan)))
    (reverse (cdr order+edges-reversed))))

;; : (-> PooComposition Symbol Integer (Values PooExecutionPlan PooFeatureBundleV1ForeignArenaImage))
(def (poo-flow-scenario-case->bundle-v1-image composition bundle-id bundle-epoch)
  (let* ((plan (poo-flow-scenario-case->execution-plan composition))
         (lowering
          (require-feature-bundle-v1-lowering-plan
           (feature-bundle-v1-lowering/with-symbols
            bundle-id
            bundle-epoch
            (plan-symbols plan composition)
            (plan-components plan composition)
            (plan-edges plan)
            '())))
         (image
          (require-feature-bundle-v1-foreign-arena-image
           (feature-bundle-v1-write-foreign-arena lowering))))
    (values plan image)))

;; : (-> PooComposition Symbol Integer String String PooExecutionPlan)
(def (poo-flow-write-composition-bundle-v1!
      composition bundle-id bundle-epoch descriptor-path arena-path)
  (let-values (((plan image)
                (poo-flow-scenario-case->bundle-v1-image
                 composition bundle-id bundle-epoch)))
    (write-feature-bundle-v1-image! image descriptor-path arena-path)
    plan))

;; : (-> String String)
(def (required-environment-value name)
  (let (value (getenv name))
    (unless (and value (> (string-length value) 0))
      (error "Bundle v1 composition environment value is required" name))
    value))

;; : (-> PooComposition PooExecutionPlan)
(def (poo-flow-write-composition-bundle-v1/from-environment! composition)
  (let* ((bundle-id
          (string->symbol
           (required-environment-value "POO_FLOW_BUNDLE_V1_ID")))
         (bundle-epoch-text
          (required-environment-value "POO_FLOW_BUNDLE_V1_EPOCH"))
         (bundle-epoch (string->number bundle-epoch-text))
         (descriptor-path
          (required-environment-value "POO_FLOW_BUNDLE_V1_DESCRIPTOR_OUT"))
         (arena-path
          (required-environment-value "POO_FLOW_BUNDLE_V1_ARENA_OUT")))
    (unless (and bundle-epoch
                 (integer? bundle-epoch)
                 (>= bundle-epoch 0))
      (error "Bundle v1 epoch must be a non-negative integer"
             bundle-epoch-text))
    (let (plan
          (poo-flow-write-composition-bundle-v1!
           composition bundle-id bundle-epoch descriptor-path arena-path))
      (display "POO_FLOW_BUNDLE_V1_RECEIPT bundle=")
      (display bundle-id)
      (display " nodes=")
      (display (length (execution-plan-nodes plan)))
      (display " edges=")
      (display (length (execution-plan-dependency-edges plan)))
      (display " symbols=")
      (display (length (plan-symbols plan composition)))
      (newline)
      plan)))
