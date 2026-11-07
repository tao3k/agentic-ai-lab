;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable runtime manifests describe resumable runtime state at the
;;; Scheme control-plane edge before provider-specific recovery executes.
;;; Invariant: manifest serialization must remain bounded and deterministic for
;;; policy reports, Marlin handoff, and checkpoint replay.
(import :gerbil/core
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/policy-manifest
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/store-backend)

(export +agentic-ai-lab-durable-runtime-envelope-schema+
        agentic-ai-lab-durable-runtime-manifest-alist
        agentic-ai-lab-durable-runtime-manifest-string
        agentic-ai-lab-durable-runtime-manifest-bytes)

(def +agentic-ai-lab-durable-runtime-envelope-schema+
  'agentic-ai-lab.durable.runtime-envelope.v1)

;;; Boundary: runtime manifest alists are the bounded ABI projection from
;;; internal durable runtime state into policy and handoff receipts.
;; agentic-ai-lab-durable-runtime-manifest-alist
;; : (-> PooDurablePolicy PooDurableRuntimeStoreContract PooDurableRuntimeStoreBackend Alist)
;; | doc m%
;;   Project durable policy, store, and backend receipts into one manifest row.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-durable-runtime-manifest-alist policy store backend)
;;   ;; => durable runtime envelope rows
;;   ```
(def (agentic-ai-lab-durable-runtime-manifest-alist policy store-contract backend)
  (let* ((policy-row
          (agentic-ai-lab-durable-policy-runtime-manifest-alist policy))
         (store-row
          (agentic-ai-lab-durable-runtime-store-contract-receipt->alist
           (agentic-ai-lab-durable-runtime-store-contract->receipt store-contract)))
         (backend-row
          (agentic-ai-lab-durable-runtime-store-backend-receipt->alist
           (agentic-ai-lab-durable-runtime-store-backend->receipt backend)))
         (operation-kinds
          (agentic-ai-lab-durable-runtime-manifest-ref backend-row 'operation-kinds '()))
         (backend-executable
          (agentic-ai-lab-durable-runtime-manifest-ref backend-row 'executable "")))
    `((schema . ,+agentic-ai-lab-durable-runtime-envelope-schema+)
      (owner . scheme)
      (policy-schema . ,(agentic-ai-lab-durable-runtime-manifest-ref policy-row 'schema #f))
      (policy-id . ,(agentic-ai-lab-durable-runtime-manifest-ref policy-row 'policy-id #f))
      (checkpoint-id-strategy
       . ,(agentic-ai-lab-durable-runtime-manifest-ref
           policy-row 'checkpoint-id-strategy #f))
      (checkpoint-store
       . ,(agentic-ai-lab-durable-runtime-manifest-ref policy-row 'checkpoint-store #f))
      (repair-mode . ,(agentic-ai-lab-durable-runtime-manifest-ref policy-row 'repair-mode #f))
      (action-classes
       . ,(agentic-ai-lab-durable-runtime-manifest-ref policy-row 'action-classes '()))
      (store-schema . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'schema #f))
      (store-id . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'store-id #f))
      (store-owner . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'store-owner #f))
      (fact-log-ref . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'fact-log-ref #f))
      (checkpoint-store-ref
       . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'checkpoint-store-ref #f))
      (derived-index-ref
       . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'derived-index-ref #f))
      (job-store-ref . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'job-store-ref #f))
      (repair-journal-ref
       . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'repair-journal-ref #f))
      (artifact-store-ref
       . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'artifact-store-ref #f))
      (communication-ledger-ref
       . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'communication-ledger-ref #f))
      (sandbox-ledger-ref
       . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'sandbox-ledger-ref #f))
      (ledger-kinds
       . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'ledger-kinds '()))
      (capability-flags
       . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'capability-flags '()))
      (backend-schema . ,(agentic-ai-lab-durable-runtime-manifest-ref backend-row 'schema #f))
      (backend-id . ,(agentic-ai-lab-durable-runtime-manifest-ref backend-row 'backend-id #f))
      (backend-kind
       . ,(agentic-ai-lab-durable-runtime-manifest-ref backend-row 'backend-kind #f))
      (backend-executable . ,backend-executable)
      (backend-protocol
       . ,(agentic-ai-lab-durable-runtime-manifest-ref backend-row 'protocol #f))
      (operation-kinds . ,operation-kinds)
      (operation-count . ,(length operation-kinds))
      (negotiate-argv . ,(list backend-executable "durable-runtime-store" "negotiate"))
      (operations-argv . ,(list backend-executable "durable-runtime-store" "operations"))
      (runtime-owner
       . ,(agentic-ai-lab-durable-runtime-manifest-ref policy-row 'runtime-owner #f))
      (policy-valid . ,(agentic-ai-lab-durable-runtime-manifest-ref policy-row 'receipt-valid #f))
      (store-valid . ,(agentic-ai-lab-durable-runtime-manifest-ref store-row 'valid? #f))
      (backend-valid . ,(agentic-ai-lab-durable-runtime-manifest-ref backend-row 'valid? #f))
      (diagnostic-count
       . ,(+ (agentic-ai-lab-durable-runtime-manifest-ref policy-row 'receipt-diagnostic-count 0)
             (agentic-ai-lab-durable-runtime-manifest-ref store-row 'diagnostic-count 0)
             (agentic-ai-lab-durable-runtime-manifest-ref backend-row 'diagnostic-count 0)))
      (runtime-executed . #f))))

;; agentic-ai-lab-durable-runtime-manifest-string
;; : (-> PooDurablePolicy PooDurableRuntimeStoreContract PooDurableRuntimeStoreBackend String)
;; | doc m%
;;   Serialize the durable runtime envelope as line-oriented manifest text.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-durable-runtime-manifest-string policy store backend)
;;   ;; => manifest text
;;   ```
(def (agentic-ai-lab-durable-runtime-manifest-string policy store-contract backend)
  (agentic-ai-lab-durable-runtime-manifest-lines->string
   (agentic-ai-lab-durable-runtime-manifest-alist policy store-contract backend)))

;; agentic-ai-lab-durable-runtime-manifest-bytes
;; : (-> PooDurablePolicy PooDurableRuntimeStoreContract PooDurableRuntimeStoreBackend U8Vector)
;; | doc m%
;;   Serialize the durable runtime envelope as UTF-8 bytes for FFI handoff.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-durable-runtime-manifest-bytes policy store backend)
;;   ;; => UTF-8 manifest bytes
;;   ```
(def (agentic-ai-lab-durable-runtime-manifest-bytes policy store-contract backend)
  (string->utf8
   (agentic-ai-lab-durable-runtime-manifest-string policy store-contract backend)))

;; agentic-ai-lab-durable-runtime-manifest-ref
;; : (-> Alist Symbol Datum Datum)
;; | doc m%
;;   Read KEY from a manifest row list, returning DEFAULT when absent.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-durable-runtime-manifest-ref rows 'schema #f)
;;   ;; => schema value or #f
;;   ```
(def (agentic-ai-lab-durable-runtime-manifest-ref row key default)
  (let ((cell (assq key row)))
    (if cell (cdr cell) default)))

;; : (-> Alist String)
(def (agentic-ai-lab-durable-runtime-manifest-lines->string rows)
  (call-with-output-string
   (lambda (port)
     (for-each
      (lambda (row)
        (display (symbol->string (car row)) port)
        (display "=" port)
        (display (agentic-ai-lab-durable-runtime-manifest-value->string (cdr row)) port)
        (newline port))
      rows))))

;; : (-> Datum String)
(def (agentic-ai-lab-durable-runtime-manifest-value->string value)
  (cond
   ((not value) "")
   ((eq? value #t) "true")
   ((symbol? value) (symbol->string value))
   ((string? value) value)
   ((number? value) (number->string value))
   ((list? value) (agentic-ai-lab-durable-runtime-manifest-list->string value))
   (else (call-with-output-string
          (lambda (port) (write value port))))))

;; agentic-ai-lab-durable-runtime-manifest-list->string
;; : (-> [Datum] String)
;; | doc m%
;;   Serialize a list field as the comma-delimited runtime manifest value form.
;;   # Examples
;;   ```scheme
;;   (agentic-ai-lab-durable-runtime-manifest-list->string '(run repair))
;;   ;; => "run,repair"
;;   ```
(def (agentic-ai-lab-durable-runtime-manifest-list->string value)
  (call-with-output-string
   (lambda (port)
     (let loop ((rest value) (first? #t))
       (unless (null? rest)
         (unless first? (display "," port))
         (display (agentic-ai-lab-durable-runtime-manifest-value->string (car rest)) port)
         (loop (cdr rest) #f))))))
