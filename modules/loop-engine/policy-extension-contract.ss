;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine policy-extension object predicates and slot validators.
;;; Invariant: malformed POO slots fail before receipt lowering begins.

(import (only-in :clan/poo/object .ref .slot? object?))

(export +agentic-ai-lab-user-loop-engine-policy-extension-prototype-kind+
        agentic-ai-lab-user-loop-engine-policy-extension-kind?
        agentic-ai-lab-user-loop-engine-policy-extension-require-slot
        agentic-ai-lab-user-loop-engine-policy-extension-require-alist-slot
        agentic-ai-lab-user-loop-engine-policy-extension-require-symbol-list-slot
        agentic-ai-lab-user-loop-engine-policy-extension-require-string-list-slot
        agentic-ai-lab-user-loop-engine-policy-extension-require-maybe-symbol-slot
        agentic-ai-lab-user-loop-engine-policy-extension-require-maybe-string-slot
        agentic-ai-lab-user-loop-engine-policy-extension-require-maybe-integer-slot)

;;; The prototype kind is the cross-owner contract anchor shared by public POO
;;; prototypes and receipt lowering. Keeping it here prevents core/runtime
;;; owners from each defining their own incompatible policy-extension kind.
;; : Symbol
(def +agentic-ai-lab-user-loop-engine-policy-extension-prototype-kind+
  'agentic-ai-lab.loop-engine.policy-extension.prototype)

;;; Slot failure payloads include object, slot, expected contract, and value so
;;; downstream diagnostics can point at the POO declaration instead of a runtime
;;; manifest row.
;; : (-> Symbol Symbol Symbol Boolean Value Unit)
(def (agentic-ai-lab-user-loop-engine-policy-extension-require-slot
      object
      slot
      expected
      ok?
      value)
  (if ok?
    (void)
    (error
     "loop-engine policy-extension POO object slot contract failed"
     (list (cons 'object object)
           (cons 'slot slot)
           (cons 'expected expected)
           (cons 'value value)))))

;;; Alist slots are the controlled escape hatch for family-specific receipt
;;; rows. They must stay proper alists so later projection can append them
;;; without reinterpreting arbitrary Scheme data.
;; : (-> Symbol Symbol Value Unit)
(def (agentic-ai-lab-user-loop-engine-policy-extension-require-alist-slot
      object
      slot
      value)
  (agentic-ai-lab-user-loop-engine-policy-extension-require-slot
   object
   slot
   'alist
   (and (list? value) (andmap pair? value))
   value))

;; agentic-ai-lab-user-loop-engine-policy-extension-require-symbol-list-slot
;;   : (-> Symbol Symbol Value Unit)
;;   | contract: validates a policy-extension slot whose value must be a proper
;;       list of symbols
;;   | result: returns void on success; raises a POO slot contract error on
;;       malformed values
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-user-loop-engine-policy-extension-require-symbol-list-slot
;;        'loop-engine-policy-extension 'priority '(ci-sweeper))
;;       ;; => (void)
;;       ```
;;     %
(def (agentic-ai-lab-user-loop-engine-policy-extension-require-symbol-list-slot
      object
      slot
      value)
  (agentic-ai-lab-user-loop-engine-policy-extension-require-slot
   object
   slot
   '(list symbol)
   (and (list? value) (andmap symbol? value))
   value))

;; agentic-ai-lab-user-loop-engine-policy-extension-require-string-list-slot
;;   : (-> Symbol Symbol Value Unit)
;;   | contract: validates a policy-extension slot whose value must be a proper
;;       list of strings
;;   | result: returns void on success; raises a POO slot contract error on
;;       malformed values
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-user-loop-engine-policy-extension-require-string-list-slot
;;        'loop-engine-policy-extension 'denylist-paths '(".env"))
;;       ;; => (void)
;;       ```
;;     %
(def (agentic-ai-lab-user-loop-engine-policy-extension-require-string-list-slot
      object
      slot
      value)
  (agentic-ai-lab-user-loop-engine-policy-extension-require-slot
   object
   slot
   '(list string)
   (and (list? value) (andmap string? value))
   value))

;;; Optional scalar slots are policy knobs: absent values mean "no opinion" and
;;; present values must remain symbolic so Marlin can match them as enums.
;; : (-> Symbol Symbol Value Unit)
(def (agentic-ai-lab-user-loop-engine-policy-extension-require-maybe-symbol-slot
      object
      slot
      value)
  (agentic-ai-lab-user-loop-engine-policy-extension-require-slot
   object
   slot
   '(maybe symbol)
   (or (not value) (symbol? value))
   value))

;;; Optional string slots carry runtime-owned paths such as logs or inboxes;
;;; Scheme validates shape only and leaves path interpretation to Marlin.
;; : (-> Symbol Symbol Value Unit)
(def (agentic-ai-lab-user-loop-engine-policy-extension-require-maybe-string-slot
      object
      slot
      value)
  (agentic-ai-lab-user-loop-engine-policy-extension-require-slot
   object
   slot
   '(maybe string)
   (or (not value) (string? value))
   value))

;;; Optional integer slots describe bounded retry or budget facts. The control
;;; plane records the number but does not execute scheduling from it.
;; : (-> Symbol Symbol Value Unit)
(def (agentic-ai-lab-user-loop-engine-policy-extension-require-maybe-integer-slot
      object
      slot
      value)
  (agentic-ai-lab-user-loop-engine-policy-extension-require-slot
   object
   slot
   '(maybe integer)
   (or (not value) (integer? value))
   value))

;;; Prototype-kind matching is the inheritance gate for policy extensions: only
;;; POO objects extending the base prototype can become runtime receipts.
;; : (-> Value Symbol Boolean)
(def (agentic-ai-lab-user-loop-engine-policy-extension-kind? value kind)
  (and (object? value)
       (.slot? value 'kind)
       (eq? (.ref value 'kind) kind)))
