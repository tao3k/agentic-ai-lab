;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable policy manifests keep the Scheme control-plane receipt stable
;;; across runtime handoff code and parser-owned policy checks.
;;; Invariant: this module must describe durable policy surfaces without
;;; depending on provider-specific recovery execution.
(import :gerbil/core
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy)

(export +agentic-ai-lab-durable-runtime-policy-manifest-schema+
        agentic-ai-lab-durable-policy-runtime-manifest-alist
        agentic-ai-lab-durable-policy-runtime-manifest-string
        agentic-ai-lab-durable-policy-runtime-manifest-bytes)

(def +agentic-ai-lab-durable-runtime-policy-manifest-schema+
  'agentic-ai-lab.durable.runtime-policy-manifest.v1)

;; agentic-ai-lab-durable-policy-runtime-manifest-alist
;; : (-> PooDurablePolicy Alist)
;; | doc m%
;;   Project a durable policy into the runtime manifest row format.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-durable-policy-runtime-manifest-alist policy)
;;   ;; => durable policy manifest rows
;;   ```
(def (agentic-ai-lab-durable-policy-runtime-manifest-alist policy)
  (let* ((receipt (agentic-ai-lab-durable-policy->receipt policy))
         (diagnostics (agentic-ai-lab-durable-policy-receipt-diagnostics receipt)))
    `((schema . ,+agentic-ai-lab-durable-runtime-policy-manifest-schema+)
      (owner . scheme)
      (policy-id . ,(agentic-ai-lab-durable-policy-receipt-policy-id receipt))
      (checkpoint-id-strategy . runtime-generated)
      (require-plan-digest-match . #t)
      (history-retention-limit . #f)
      (checkpoint-store . ,(agentic-ai-lab-durable-policy-receipt-checkpoint-store receipt))
      (repair-mode . ,(agentic-ai-lab-durable-policy-receipt-repair-mode receipt))
      (action-classes . ,(agentic-ai-lab-durable-policy-receipt-action-classes receipt))
      (runtime-owner . ,(agentic-ai-lab-durable-policy-receipt-runtime-owner receipt))
      (receipt-schema . ,+agentic-ai-lab-durable-policy-receipt-schema+)
      (receipt-kind . ,+agentic-ai-lab-durable-policy-kind+)
      (receipt-valid . ,(agentic-ai-lab-durable-policy-receipt-valid? receipt))
      (receipt-diagnostic-count . ,(length diagnostics)))))

;; agentic-ai-lab-durable-policy-runtime-manifest-string
;; : (-> PooDurablePolicy String)
;; | doc m%
;;   Serialize a durable policy manifest as line-oriented text.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-durable-policy-runtime-manifest-string policy)
;;   ;; => manifest text
;;   ```
(def (agentic-ai-lab-durable-policy-runtime-manifest-string policy)
  (agentic-ai-lab-durable-manifest-lines->string
   (agentic-ai-lab-durable-policy-runtime-manifest-alist policy)))

;; agentic-ai-lab-durable-policy-runtime-manifest-bytes
;; : (-> PooDurablePolicy U8Vector)
;; | doc m%
;;   Serialize a durable policy manifest as UTF-8 bytes for FFI handoff.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-durable-policy-runtime-manifest-bytes policy)
;;   ;; => UTF-8 manifest bytes
;;   ```
(def (agentic-ai-lab-durable-policy-runtime-manifest-bytes policy)
  (string->utf8 (agentic-ai-lab-durable-policy-runtime-manifest-string policy)))

;; : (-> Alist String)
(def (agentic-ai-lab-durable-manifest-lines->string rows)
  (call-with-output-string
   (lambda (port)
     (for-each
      (lambda (row)
        (display (symbol->string (car row)) port)
        (display "=" port)
        (display (agentic-ai-lab-durable-manifest-value->string (cdr row)) port)
        (newline port))
      rows))))

;; : (-> Datum String)
(def (agentic-ai-lab-durable-manifest-value->string value)
  (cond
   ((not value) "")
   ((eq? value #t) "true")
   ((symbol? value) (symbol->string value))
   ((string? value) value)
   ((number? value) (number->string value))
   ((list? value) (agentic-ai-lab-durable-manifest-list->string value))
   (else (call-with-output-string
          (lambda (port) (write value port))))))

;; agentic-ai-lab-durable-manifest-list->string
;; : (-> [Datum] String)
;; | doc m%
;;   Serialize a list field as the comma-delimited manifest value form.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-durable-manifest-list->string '(a b))
;;   ;; => "a,b"
;;   ```
(def (agentic-ai-lab-durable-manifest-list->string value)
  (call-with-output-string
   (lambda (port)
     (let loop ((rest value) (first? #t))
       (unless (null? rest)
         (unless first? (display "," port))
         (display (agentic-ai-lab-durable-manifest-value->string (car rest)) port)
         (loop (cdr rest) #f))))))
