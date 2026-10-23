;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox profile core owns reusable profile objects before
;;; backend-specific modules specialize filesystem, network, and resource policy.
;;; Invariant: profile objects must remain composable through POO inheritance.

(import :gerbil/core
        (only-in :clan/poo/object object<-alist .ref .slot?)
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-core
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy-backend-capability
        :agentic-ai-lab/modules/sandbox-core/profile-support/projection-syntax
        (only-in :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy
                 agentic-ai-lab-durable-policy/default
                 agentic-ai-lab-durable-policy?
                 agentic-ai-lab-durable-policy-name))

(export agentic-ai-lab-sandbox-profile-policy
        agentic-ai-lab-sandbox-profile-policy?
        agentic-ai-lab-sandbox-profile-policy-required-capabilities
        agentic-ai-lab-sandbox-profile-policy-resource-policy
        agentic-ai-lab-sandbox-profile-policy-durable-policy
        agentic-ai-lab-sandbox-profile-policy-durable-policy-ref
        agentic-ai-lab-sandbox-profile-policy-sandbox-handle-class
        agentic-ai-lab-sandbox-profile-policy/default
        agentic-ai-lab-sandbox-profile-policy-append-distinct
        agentic-ai-lab-sandbox-profile-policy-append-distinct/indexed
        agentic-ai-lab-sandbox-profile-policy-effective-required)

;; agentic-ai-lab-sandbox-profile-policy
;;   : (-> [Symbol] [Alist] POOObject)
;;   | contract: build a POO sandbox profile policy object from required capabilities
;;   | result: immutable policy object carrying normalized option slots
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy
;;        '(filesystem-read) '((network-policy . deny)))
;;       ;; => sandbox profile policy object
;;       ```
;;     %
;;; Sandbox profile policy objects carry required capabilities and runtime policy knobs.
;;; - Keep durable, resource, and sandbox handle policy fields on one POO object boundary.
;; : (-> List List Object)
(def (agentic-ai-lab-sandbox-profile-policy required-capabilities . maybe-options)
  (let (options (if (null? maybe-options) '() (car maybe-options)))
    (object<-alist
     (list
      (cons 'kind agentic-ai-lab-sandbox-profile-policy-kind)
      (cons 'required-capabilities required-capabilities)
      (cons 'backend-intent
            (agentic-ai-lab-sandbox-profile-policy-option options 'backend-intent '()))
      (cons 'resource-policy
            (agentic-ai-lab-sandbox-profile-policy-option options 'resource-policy '()))
      (cons 'durable-policy
            (agentic-ai-lab-sandbox-profile-policy-option
             options
             'durable-policy
             agentic-ai-lab-durable-policy/default))
      (cons 'sandbox-handle-class
            (agentic-ai-lab-sandbox-profile-policy-option
             options
             'sandbox-handle-class
             'sandbox/profile-handle))
      (cons 'safety-policy
            (agentic-ai-lab-sandbox-profile-policy-option
             options
             'safety-policy
             '((deny . ()) (human-gates . ()))))
      (cons 'failure-policy
            (agentic-ai-lab-sandbox-profile-policy-option
             options
             'failure-policy
             '((structured . #t) (recoverable . #t))))
      (cons 'projection-policy
            (agentic-ai-lab-sandbox-profile-policy-option
             options
             'projection-policy
             '((runtime-executed . #f) (target . marlin-agent-core))))
      (cons 'metadata
            (agentic-ai-lab-sandbox-profile-policy-option options 'metadata '()))))))

;; agentic-ai-lab-sandbox-profile-policy?
;;   : (-> SandboxPolicyCandidate Boolean)
;;   | contract: recognize POO sandbox profile policy objects
;;   | result: #t only for values carrying the sandbox profile policy kind id
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy? '())
;;       ;; => #f
;;       ```
;;     %
;; : (-> SandboxPolicyCandidate Boolean)
(def (agentic-ai-lab-sandbox-profile-policy? value)
  (agentic-ai-lab-sandbox-policy-object-kind?
   value
   agentic-ai-lab-sandbox-profile-policy-kind))

;; agentic-ai-lab-sandbox-profile-policy-required-capabilities
;;   : (-> PooSandboxProfilePolicy [CapabilitySymbol])
;;   | contract: read required capability symbols from a profile policy object
;;   | result: required capability list, or empty list for invalid policies
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-required-capabilities '())
;;       ;; => ()
;;       ```
;;     %
;; : (-> PooSandboxProfilePolicy [CapabilitySymbol])
(def (agentic-ai-lab-sandbox-profile-policy-required-capabilities policy)
  (if (agentic-ai-lab-sandbox-profile-policy? policy)
    (.ref policy 'required-capabilities)
    '()))

;; agentic-ai-lab-sandbox-profile-policy-resource-policy
;;   : (-> PooSandboxProfilePolicy ResourcePolicy)
;;   | contract: read resource policy rows from a profile policy object
;;   | result: resource policy rows, or empty list for invalid policies
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-resource-policy '())
;;       ;; => ()
;;       ```
;;     %
;; : (-> PooSandboxProfilePolicy ResourcePolicy)
(def (agentic-ai-lab-sandbox-profile-policy-resource-policy policy)
  (if (agentic-ai-lab-sandbox-profile-policy? policy)
    (.ref policy 'resource-policy)
    '()))

;; agentic-ai-lab-sandbox-profile-policy-durable-policy
;;   : (-> PooSandboxProfilePolicy PooDurablePolicy)
;;   | contract: read durable policy slot or fall back to the default policy
;;   | result: durable policy object used by sandbox profile validation
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-durable-policy '())
;;       ;; => default durable policy object
;;       ```
;;     %
;; : (-> PooSandboxProfilePolicy PooDurablePolicy)
(def (agentic-ai-lab-sandbox-profile-policy-durable-policy policy)
  (if (and (agentic-ai-lab-sandbox-profile-policy? policy)
           (.slot? policy 'durable-policy))
    (.ref policy 'durable-policy)
    agentic-ai-lab-durable-policy/default))

;; agentic-ai-lab-sandbox-profile-policy-durable-policy-ref
;;   : (-> PooSandboxProfilePolicy MaybeSymbol)
;;   | contract: project the durable policy name from a profile policy object
;;   | result: durable policy symbol when available, otherwise #f
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-durable-policy-ref '())
;;       ;; => durable/default
;;       ```
;;     %
;; : (-> PooSandboxProfilePolicy MaybeSymbol)
(def (agentic-ai-lab-sandbox-profile-policy-durable-policy-ref policy)
  (let (durable-policy
        (agentic-ai-lab-sandbox-profile-policy-durable-policy policy))
    (if (agentic-ai-lab-durable-policy? durable-policy)
      (agentic-ai-lab-durable-policy-name durable-policy)
      #f)))

;; agentic-ai-lab-sandbox-profile-policy-sandbox-handle-class
;;   : (-> PooSandboxProfilePolicy Symbol)
;;   | contract: read sandbox handle class with the profile-handle default
;;   | result: sandbox handle class symbol
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-sandbox-handle-class '())
;;       ;; => sandbox/profile-handle
;;       ```
;;     %
;; : (-> PooSandboxProfilePolicy Symbol)
(def (agentic-ai-lab-sandbox-profile-policy-sandbox-handle-class policy)
  (if (and (agentic-ai-lab-sandbox-profile-policy? policy)
           (.slot? policy 'sandbox-handle-class))
    (.ref policy 'sandbox-handle-class)
    'sandbox/profile-handle))

;; agentic-ai-lab-sandbox-profile-policy/default
;;   : PooSandboxProfilePolicy
;;   | contract: default sandbox profile policy with no required capabilities
;;   | result: reusable POO policy object for callers without explicit policy rows
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy? agentic-ai-lab-sandbox-profile-policy/default)
;;       ;; => #t
;;       ```
;;     %
(def agentic-ai-lab-sandbox-profile-policy/default
  (agentic-ai-lab-sandbox-profile-policy '()))

;; agentic-ai-lab-sandbox-profile-policy-append-distinct
;;   : (-> [CapabilitySymbol] [CapabilitySymbol] [CapabilitySymbol])
;;   | contract: append missing capability symbols without duplicates
;;   | result: base capabilities plus distinct extra capabilities in stable order
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-append-distinct '(read) '(read write))
;;       ;; => (read write)
;;       ```
;;     %
(def (agentic-ai-lab-sandbox-profile-policy-append-distinct base extra)
  (if (null? extra)
    base
    (agentic-ai-lab-sandbox-profile-policy-append-distinct/indexed
     base
     extra
     (agentic-ai-lab-sandbox-policy-value-index base)
     '())))

;; : (-> CapabilityList CapabilityList HashTable CapabilityList CapabilityList)
(def (agentic-ai-lab-sandbox-profile-policy-append-distinct/indexed base
                                                              extra
                                                              seen
                                                              added)
  (cond
   ((null? extra)
    (if (null? added)
      base
      (append base (reverse added))))
   ((hash-get seen (car extra))
    (agentic-ai-lab-sandbox-profile-policy-append-distinct/indexed
     base
     (cdr extra)
     seen
     added))
   (else
    (hash-put! seen (car extra) #t)
    (agentic-ai-lab-sandbox-profile-policy-append-distinct/indexed
     base
     (cdr extra)
     seen
     (cons (car extra) added)))))

;; agentic-ai-lab-sandbox-profile-policy-effective-required
;;   : (-> PooSandboxProfilePolicy [CapabilitySymbol] [CapabilitySymbol])
;;   | contract: combine policy-required and profile-provided capabilities
;;   | result: distinct effective required capability symbols
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile-policy-effective-required policy '(read))
;;       ;; => effective capability symbols
;;       ```
;;     %
;; : (-> PooSandboxProfilePolicy [CapabilitySymbol] [CapabilitySymbol])
(def (agentic-ai-lab-sandbox-profile-policy-effective-required policy
                                                         profile-capabilities)
  (agentic-ai-lab-sandbox-profile-policy-append-distinct
   (agentic-ai-lab-sandbox-profile-policy-required-capabilities policy)
   profile-capabilities))
