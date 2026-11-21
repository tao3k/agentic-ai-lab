;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tool-calling control owns the policy-visible proof surface between
;;; Scheme workflow intent and runtime tool execution.
;;; Invariant: validation proof facts must stay deterministic and independent
;;; from provider transport side effects.
(import (only-in :clan/poo/object .o .ref))

(export agentic-ai-lab-tool-call-plan
        agentic-ai-lab-tool-call-runtime-receipt
        agentic-ai-lab-tool-call-fact-family
        agentic-ai-lab-tool-call-fact-family-build
        agentic-ai-lab-tool-call-fact-family-ref
        agentic-ai-lab-tool-call-runtime-validation-proof-facts
        agentic-ai-lab-tool-call-mediated-receipt
        agentic-ai-lab-tool-call-fact-ref)

;; : (-> PooObject PooObject PooObject PooObject)
(def (agentic-ai-lab-tool-call-mediated-receipt runtime token-validation
                                          token-consumption)
  (unless (.ref token-validation 'accepted?)
    (error "tool call requires an accepted AuthorizedEffectToken"))
  (unless (eq? (.ref token-consumption 'outcome) 'committed)
    (error "tool call requires a committed token consumption receipt"))
  (.o (kind 'agentic-ai-lab-tool-call-mediated-receipt)
      (runtime-receipt runtime)
      (token-id (.ref token-consumption 'token-id))
      (nonce (.ref token-consumption 'nonce))
      (semantic-root (.ref token-consumption 'semantic-root))
      (execution-root (.ref token-consumption 'execution-root))
      (durability (.ref token-consumption 'durability))
      (status 'committed)))

;; : (-> Object Boolean)
(def (agentic-ai-lab-truthy? value)
  (if value #t #f))

;; : (-> [Symbol] [Symbol] Boolean)
(def (agentic-ai-lab-list-subset? expected actual)
  (andmap (lambda (value) (memq value actual)) expected))

;; : (-> Symbol Object PooObject)
(def (agentic-ai-lab-tool-call-entry entry-key entry-value)
  (.o (kind 'agentic-ai-lab-tool-call-entry)
      (key entry-key)
      (value entry-value)))

;; : (-> [PooObject] Alist)
(def (agentic-ai-lab-tool-call-entry-index entry-list)
  (foldl
   (lambda (entry index-cache)
     (cons (cons (.ref entry 'key) (.ref entry 'value))
           index-cache))
   '()
   entry-list))

;; : (-> PooObject Symbol Object)
(def (agentic-ai-lab-tool-call-index-ref object key)
  (let ((cell (assq key (.ref object 'index))))
    (and cell (cdr cell))))

;; : (-> Symbol Symbol PooObject)
(def (agentic-ai-lab-tool-call-fact-family family-name source-tag)
  (.o (kind 'agentic-ai-lab-tool-call-fact-family)
      (name family-name)
      (source source-tag)))

;; : (-> PooObject Alist Alist)
(def (agentic-ai-lab-tool-call-fact-family-pairs family fact-pair-list)
  (let* ((family-name (.ref family 'name))
         (source-tag (.ref family 'source))
         (family-pairs
          (if (assq 'fact-family fact-pair-list)
            fact-pair-list
            (cons (cons 'fact-family family-name) fact-pair-list))))
    (if (or (not source-tag) (assq 'source family-pairs))
      family-pairs
      (cons (cons 'source source-tag) family-pairs))))

;; : (forall (v) (-> PooObject [(Pair Symbol v)] PooObject))
;; : (-> PooObject Alist PooObject)
(def (agentic-ai-lab-tool-call-fact-family-build family fact-pair-list)
  (let* ((pairs (agentic-ai-lab-tool-call-fact-family-pairs
                 family
                 fact-pair-list))
         (entries
          (map (lambda (fact-pair)
                 (agentic-ai-lab-tool-call-entry (car fact-pair) (cdr fact-pair)))
               pairs))
         (index-cache pairs))
    (let ((family-value family)
          (entry-values entries))
      (.o (kind 'agentic-ai-lab-tool-call-fact-set)
        (family family-value)
        (name (.ref family 'name))
        (entries entry-values)
        (index index-cache)))))

;; : (-> Symbol Alist PooObject)
(def (agentic-ai-lab-tool-call-fact-set fact-set-name fact-pair-list)
  (agentic-ai-lab-tool-call-fact-family-build
   (agentic-ai-lab-tool-call-fact-family fact-set-name #f)
   fact-pair-list))

;; : (-> PooObject Symbol Object)
(def (agentic-ai-lab-tool-call-fact-ref facts key)
  (agentic-ai-lab-tool-call-index-ref facts key))

;; : (-> PooObject PooObject Symbol Object)
(def (agentic-ai-lab-tool-call-fact-family-ref family facts key)
  (and (equal? (.ref family 'name)
               (agentic-ai-lab-tool-call-fact-ref facts 'fact-family))
       (agentic-ai-lab-tool-call-fact-ref facts key)))

;; : PooObject
(def +agentic-ai-lab-tool-call-runtime-validation-fact-family+
  (agentic-ai-lab-tool-call-fact-family
   'agentic-ai-lab-tool-call-runtime-validation-proof-facts
   'agentic-ai-lab.tool-calling.control.runtime))

;; : (-> Symbol Symbol Symbol [Symbol] [Symbol] Symbol Symbol Symbol Symbol Symbol [Symbol] PooObject)
(def (agentic-ai-lab-tool-call-plan plan-name
                              owner-session
                              tool
                              schema-keys
                              required-keys
                              permission
                              sandbox-scope
                              cooldown
                              result-contract
                              runtime-binding
                              trace-obligations)
  (let* ((plan-entry-list
          (list
           (agentic-ai-lab-tool-call-entry 'name plan-name)
           (agentic-ai-lab-tool-call-entry 'owner-session owner-session)
           (agentic-ai-lab-tool-call-entry 'tool tool)
           (agentic-ai-lab-tool-call-entry 'schema-keys schema-keys)
           (agentic-ai-lab-tool-call-entry 'required-keys required-keys)
           (agentic-ai-lab-tool-call-entry 'permission permission)
           (agentic-ai-lab-tool-call-entry 'sandbox-scope sandbox-scope)
           (agentic-ai-lab-tool-call-entry 'cooldown cooldown)
           (agentic-ai-lab-tool-call-entry 'result-contract result-contract)
           (agentic-ai-lab-tool-call-entry 'runtime-binding runtime-binding)
           (agentic-ai-lab-tool-call-entry 'trace-obligations trace-obligations)))
         (plan-index-cache
          (agentic-ai-lab-tool-call-entry-index plan-entry-list)))
    (.o (kind 'agentic-ai-lab-tool-call-plan)
        (name plan-name)
        (entries plan-entry-list)
        (index plan-index-cache))))

;; : (-> Symbol Symbol Symbol [Symbol] Boolean Boolean Boolean Boolean Boolean Symbol [Symbol] Boolean Symbol PooObject)
(def (agentic-ai-lab-tool-call-runtime-receipt receipt-name
                                         owner-session
                                         tool
                                         argument-keys
                                         permission-granted?
                                         sandbox-contained?
                                         arguments-valid?
                                         cooldown-satisfied?
                                         result-accepted?
                                         runtime-binding
                                         trace
                                         output-authorizes-policy?
                                         status)
  (let* ((receipt-entry-list
          (list
           (agentic-ai-lab-tool-call-entry 'name receipt-name)
           (agentic-ai-lab-tool-call-entry 'owner-session owner-session)
           (agentic-ai-lab-tool-call-entry 'tool tool)
           (agentic-ai-lab-tool-call-entry 'argument-keys argument-keys)
           (agentic-ai-lab-tool-call-entry 'permission-granted?
                                     permission-granted?)
           (agentic-ai-lab-tool-call-entry 'sandbox-contained?
                                     sandbox-contained?)
           (agentic-ai-lab-tool-call-entry 'arguments-valid? arguments-valid?)
           (agentic-ai-lab-tool-call-entry 'cooldown-satisfied?
                                     cooldown-satisfied?)
           (agentic-ai-lab-tool-call-entry 'result-accepted? result-accepted?)
           (agentic-ai-lab-tool-call-entry 'runtime-binding runtime-binding)
           (agentic-ai-lab-tool-call-entry 'trace trace)
           (agentic-ai-lab-tool-call-entry 'output-authorizes-policy?
                                     output-authorizes-policy?)
           (agentic-ai-lab-tool-call-entry 'status status)))
         (receipt-index-cache
          (agentic-ai-lab-tool-call-entry-index receipt-entry-list)))
    (.o (kind 'agentic-ai-lab-tool-call-runtime-receipt)
        (name receipt-name)
        (entries receipt-entry-list)
        (index receipt-index-cache))))

;;; Boundary: validation proof facts expose tool-call runtime decisions without
;;; calling provider execution again or mutating receipt state.
;; : (-> PooObject PooObject PooObject)
(def (agentic-ai-lab-tool-call-runtime-validation-proof-facts plan receipt)
  (let* ((plan-owner-session
          (agentic-ai-lab-tool-call-index-ref plan 'owner-session))
         (plan-tool
          (agentic-ai-lab-tool-call-index-ref plan 'tool))
         (schema-keys
          (agentic-ai-lab-tool-call-index-ref plan 'schema-keys))
         (required-keys
          (agentic-ai-lab-tool-call-index-ref plan 'required-keys))
         (permission
          (agentic-ai-lab-tool-call-index-ref plan 'permission))
         (sandbox-scope
          (agentic-ai-lab-tool-call-index-ref plan 'sandbox-scope))
         (cooldown
          (agentic-ai-lab-tool-call-index-ref plan 'cooldown))
         (result-contract
          (agentic-ai-lab-tool-call-index-ref plan 'result-contract))
         (plan-runtime-binding
          (agentic-ai-lab-tool-call-index-ref plan 'runtime-binding))
         (trace-obligations
          (agentic-ai-lab-tool-call-index-ref plan 'trace-obligations))
         (receipt-owner-session
          (agentic-ai-lab-tool-call-index-ref receipt 'owner-session))
         (receipt-tool
          (agentic-ai-lab-tool-call-index-ref receipt 'tool))
         (argument-keys
          (agentic-ai-lab-tool-call-index-ref receipt 'argument-keys))
         (permission-granted?
          (agentic-ai-lab-tool-call-index-ref receipt 'permission-granted?))
         (sandbox-contained?
          (agentic-ai-lab-tool-call-index-ref receipt 'sandbox-contained?))
         (arguments-valid?
          (agentic-ai-lab-tool-call-index-ref receipt 'arguments-valid?))
         (cooldown-satisfied?
          (agentic-ai-lab-tool-call-index-ref receipt 'cooldown-satisfied?))
         (result-accepted?
          (agentic-ai-lab-tool-call-index-ref receipt 'result-accepted?))
         (receipt-runtime-binding
          (agentic-ai-lab-tool-call-index-ref receipt 'runtime-binding))
         (trace
          (agentic-ai-lab-tool-call-index-ref receipt 'trace))
         (output-authorizes-policy?
          (agentic-ai-lab-tool-call-index-ref receipt 'output-authorizes-policy?))
         (status
          (agentic-ai-lab-tool-call-index-ref receipt 'status))
         (owner-session? (agentic-ai-lab-truthy? plan-owner-session))
         (declared-tool? (agentic-ai-lab-truthy? plan-tool))
         (plan-arguments-match-schema?
          (agentic-ai-lab-list-subset? required-keys schema-keys))
         (permission? (agentic-ai-lab-truthy? permission))
         (scope? (agentic-ai-lab-truthy? sandbox-scope))
         (cooldown? (agentic-ai-lab-truthy? cooldown))
         (result? (agentic-ai-lab-truthy? result-contract))
         (runtime-binding? (agentic-ai-lab-truthy? plan-runtime-binding))
         (plan-valid?
          (and owner-session?
               declared-tool?
               plan-arguments-match-schema?
               permission?
               scope?
               cooldown?
               result?
               runtime-binding?))
         (same-owner-session?
          (equal? plan-owner-session receipt-owner-session))
         (same-tool?
          (equal? plan-tool receipt-tool))
         (same-runtime-binding?
          (equal? plan-runtime-binding receipt-runtime-binding))
         (arguments-match-plan?
          (and (agentic-ai-lab-list-subset? required-keys argument-keys)
               (agentic-ai-lab-list-subset? argument-keys schema-keys)))
         (trace-covers?
          (agentic-ai-lab-list-subset? trace-obligations trace))
         (output-cannot-authorize-policy?
          (not (agentic-ai-lab-truthy? output-authorizes-policy?)))
         (receipt-matches-plan?
          (and same-owner-session?
               same-tool?
               same-runtime-binding?
               arguments-match-plan?
               permission-granted?
               sandbox-contained?
               arguments-valid?
               cooldown-satisfied?
               result-accepted?
               output-cannot-authorize-policy?
               trace-covers?
               (equal? status 'completed))))
    (agentic-ai-lab-tool-call-fact-family-build
     +agentic-ai-lab-tool-call-runtime-validation-fact-family+
     (list
      (cons 'source 'agentic-ai-lab.tool-calling.control.runtime)
      (cons 'plan-valid plan-valid?)
      (cons 'tool-request-has-owner-session same-owner-session?)
      (cons 'declared-tool declared-tool?)
      (cons 'tool-arguments-match-schema arguments-match-plan?)
      (cons 'tool-permission-before-call permission-granted?)
      (cons 'tool-scope-contained sandbox-contained?)
      (cons 'validate-arguments-before-runtime arguments-valid?)
      (cons 'tool-output-cannot-authorize-policy
            output-cannot-authorize-policy?)
      (cons 'cooldown-before-retry cooldown-satisfied?)
      (cons 'tool-result-before-downstream-step result-accepted?)
      (cons 'runtime-binding-matches-tool-contract same-runtime-binding?)
      (cons 'runtime-receipt-matches-tool-plan receipt-matches-plan?)
      (cons 'trace-covers-tool-request-call-result trace-covers?)))))
