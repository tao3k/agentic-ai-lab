;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: models runtime context demand cells and recovery decisions as POO values.
;;; Invariant: recovery transitions preserve context identity and explicit evidence state.
(import (only-in :clan/poo/object .ref object<-alist object?))

(export agentic-ai-lab-runtime-context-prototype
        agentic-ai-lab-demand-cell-prototype
        agentic-ai-lab-recovery-decision-prototype
        agentic-ai-lab-runtime-context
        agentic-ai-lab-demand-cell-transition
        agentic-ai-lab-recovery-decision
        agentic-ai-lab-runtime-control-object?)

(def agentic-ai-lab-runtime-context-prototype
  (object<-alist '((kind . runtime-context))))

(def agentic-ai-lab-demand-cell-prototype
  (object<-alist '((kind . demand-cell))))

(def agentic-ai-lab-recovery-decision-prototype
  (object<-alist '((kind . recovery-decision))))

;; : (-> AgenticAILabRuntimeIdentity Symbol Natural AgenticAILabRuntimeContext)
(def (agentic-ai-lab-runtime-context identity phase generation)
  (object<-alist
   `((kind . runtime-context)
     (identity . ,identity)
     (phase . ,phase)
     (generation . ,generation))))

;; : (-> AgenticAILabDemandCellState AgenticAILabDemandCellState AgenticAILabDemandCellState)
(def (agentic-ai-lab-demand-cell-transition current requested)
  (cond
   ((eq? current requested) current)
   ((and (eq? current 'pending) (eq? requested 'realizing)) 'realizing)
   ((and (eq? current 'realizing) (eq? requested 'realized)) 'realized)
   ((and (eq? current 'realizing) (eq? requested 'failed)) 'failed)
   (else 'invalid-transition)))

;; : (-> Condition Boolean Natural AgenticAILabRecoveryDecision)
(def (agentic-ai-lab-recovery-decision condition continuable? retry-budget)
  (object<-alist
   `((kind . recovery-decision)
     (condition . ,condition)
     (continuable? . ,continuable?)
     (retry-budget . ,retry-budget)
     (action . ,(match (cons continuable? (> retry-budget 0))
                  ([#t . #t] 'resume)
                  ([#t . #f] 'defer)
                  (else 'abort))))))

;; : (-> Object Boolean)
(def (agentic-ai-lab-runtime-control-object? value)
  (and (object? value)
       (with-catch
        (lambda (_failure) #f)
        (lambda ()
          (case (.ref value 'kind)
            ((runtime-context demand-cell recovery-decision) #t)
            (else #f))))))
