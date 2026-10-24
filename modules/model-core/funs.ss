;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: pure model lookup, compatibility, and selection algorithms.
;;; Invariant: this owner consumes admitted POO values and returns an inert
;;; receipt; it neither constructs configuration nor invokes a Provider.

(import (only-in :clan/poo/object .ref)
        (only-in :agentic-ai-lab/modules/session/objects-core
                 agentic-ai-lab-session-every?
                 agentic-ai-lab-session-require)
        :agentic-ai-lab/modules/model-core/objects)

(export agentic-ai-lab-model-catalog-find
        agentic-ai-lab-model-supports-capability?
        agentic-ai-lab-model-supports-capabilities?
        agentic-ai-lab-model-select)

(def (agentic-ai-lab-model-spec-find model-ref models)
  (cond
   ((null? models) #f)
   ((eq? model-ref (agentic-ai-lab-model-spec-ref (car models))) (car models))
   (else (agentic-ai-lab-model-spec-find model-ref (cdr models)))))

(def (agentic-ai-lab-model-catalog-find catalog model-ref)
  (agentic-ai-lab-model-spec-find model-ref (.ref catalog 'models)))

(def (agentic-ai-lab-model-supports-capability? spec capability)
  (and (memq capability (agentic-ai-lab-model-spec-capabilities spec)) #t))

(def (agentic-ai-lab-model-supports-capabilities? spec capabilities)
  (agentic-ai-lab-session-every?
   (lambda (capability)
     (agentic-ai-lab-model-supports-capability? spec capability))
   capabilities))

(def (agentic-ai-lab-model-selection-diagnostic model-ref reason)
  (agentic-ai-lab-model-field-rows
   (model-ref model-ref)
   (reason reason)))

(def (agentic-ai-lab-model-selection-fallback-receipt policy catalog fallback-ref
                                                fallback-model fallback-valid?
                                                diagnostics)
  (agentic-ai-lab-model-selection-receipt
   policy catalog
   (if fallback-valid? #t #f)
   (if fallback-valid? fallback-model #f)
   (if fallback-valid?
     diagnostics
     (cons (agentic-ai-lab-model-selection-diagnostic
            fallback-ref 'no-model-selected)
           diagnostics))))

(def (agentic-ai-lab-model-select-candidates catalog candidate-model-refs
                                       capabilities diagnostics)
  (cond
   ((null? candidate-model-refs) (values #f (reverse diagnostics)))
   (else
    (let* ((model-ref (car candidate-model-refs))
           (model (agentic-ai-lab-model-catalog-find catalog model-ref)))
      (cond
       ((not model)
        (agentic-ai-lab-model-select-candidates
         catalog (cdr candidate-model-refs) capabilities
         (cons (agentic-ai-lab-model-selection-diagnostic model-ref 'missing-model)
               diagnostics)))
       ((agentic-ai-lab-model-supports-capabilities? model capabilities)
        (values model (reverse diagnostics)))
       (else
        (agentic-ai-lab-model-select-candidates
         catalog (cdr candidate-model-refs) capabilities
         (cons (agentic-ai-lab-model-selection-diagnostic
                model-ref 'missing-capability)
               diagnostics))))))))

(def (agentic-ai-lab-model-select policy catalog)
  (agentic-ai-lab-session-require "model selection policy must be a model policy"
                            (agentic-ai-lab-model-selection-policy? policy) policy)
  (agentic-ai-lab-session-require "model selection catalog must be a model catalog"
                            (agentic-ai-lab-model-catalog? catalog) catalog)
  (let (required-capabilities (.ref policy 'required-capabilities))
    (let-values (((selected-model diagnostics)
                  (agentic-ai-lab-model-select-candidates
                   catalog (.ref policy 'candidate-model-refs)
                   required-capabilities '())))
      (if selected-model
        (agentic-ai-lab-model-selection-receipt
         policy catalog #t selected-model diagnostics)
        (let* ((fallback-ref (.ref policy 'fallback-model-ref))
               (fallback-model
                (and fallback-ref
                     (agentic-ai-lab-model-catalog-find catalog fallback-ref)))
               (fallback-valid?
                (and fallback-model
                     (agentic-ai-lab-model-supports-capabilities?
                      fallback-model required-capabilities))))
          (agentic-ai-lab-model-selection-fallback-receipt
           policy catalog fallback-ref fallback-model fallback-valid?
           diagnostics))))))
