;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: runtime nono FFI live probes and receipts.
;;; Boundary: this module calls the package-managed Gambit FFI shim.
;;; Runtime contract: irreversible sandbox apply is not performed by default.

;;; Runtime nono dynamic-library selection and live-test receipts.
;;; - Keep FFI handles isolated while the Scheme layer reports bounded sandbox receipts.
(import :gerbil/core
        :tao3k/agentic-ai-lab/modules/agent-sandbox/alist
        :tao3k/agentic-ai-lab/modules/nono-sandbox/c-binding-runtime
        :tao3k/yuanxu/module-system/selection/objects
        (only-in ./_nono
                 nono_ffi_apply_null
                 nono_ffi_capability_roundtrip
                 nono_ffi_close
                 nono_ffi_is_loaded
                 nono_ffi_last_error
                 nono_ffi_open
                 nono_ffi_sandbox_is_supported
                 nono_ffi_support_details
                 nono_ffi_support_is_supported
                 nono_ffi_support_platform))

(export +nono-c-binding-ffi-live-test-receipt-schema+
        +nono-c-binding-selection-live-test-receipt-schema+
        +nono-c-binding-ffi-apply-null-error-code+
        nono-c-binding-ffi-library-candidates
        nono-c-binding-ffi-resolve-library
        nono-c-binding-ffi-open
        nono-c-binding-ffi-close
        nono-c-binding-selection-binding
        nono-c-binding-selection-live-test
        nono-c-binding-ffi-live-test)

;; : Symbol
(def +nono-c-binding-ffi-live-test-receipt-schema+
  'agentic-ai-lab.sandbox.nono-sandbox.c-binding.runtime-live-test.v1)

;; : Symbol
(def +nono-c-binding-selection-live-test-receipt-schema+
  'agentic-ai-lab.sandbox.nono-sandbox.c-binding.selection-live-test.v1)

;; : Integer
(def +nono-c-binding-ffi-apply-null-error-code+ -12)

;;; Runtime live-test row expansion stays separate from dynamic FFI handles.
;; nono-c-binding-ffi-field-rows
;; : (-> Syntax Syntax)
;; | contract: expands literal `(field value)` pairs into bounded runtime rows
;; | warning: keep library open/close and apply calls outside this macro
;; | doc m%
;;   Generates the runtime nono receipt row list.
;;   # Examples
;;   ```scheme
;;   (nono-c-binding-ffi-field-rows (status 'skipped))
;;   ;; => ((status . skipped))
;;   ```
(defrules nono-c-binding-ffi-field-rows ()
  ((_ (field value) ...)
   (list (cons 'field value) ...)))

;; : (-> List List List)
(def (nono-c-binding-ffi-rows/tail rows tail)
  (foldr cons tail rows))

;;; Boundary: nono c binding runtime library candidates is the policy-visible
;;; edge for sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> [Alist] [String])
(def (nono-c-binding-ffi-library-candidates . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (library-path (agent-sandbox-alist-ref options 'library-path #f)))
    (if library-path
      (list library-path)
      '())))

;; nono-c-binding-ffi-resolve-library
;;   : (forall (o) (-> [o] (U String #f)))
;;   : (-> [Alist] (U String #f))
;;   | contract: returns the first existing runtime library candidate or #f.
;;   | doc m%
;;     # Examples
;;     ```scheme
;;     (nono-c-binding-ffi-resolve-library '((library-path . "/tmp/missing.dylib")))
;;     ;; result: #f when the path does not exist
;;     ```
;; : (-> [Alist] (U String #f))
(def (nono-c-binding-ffi-resolve-library . maybe-options)
  (let (candidates
        (apply nono-c-binding-ffi-library-candidates maybe-options))
    (find file-exists? candidates)))

;; : (-> String Alist)
(def (nono-c-binding-ffi-open library-path)
  (let ((status (nono_ffi_open library-path))
        (error (nono_ffi_last_error)))
    (nono-c-binding-ffi-field-rows
     (ok? (zero? status))
     (status status)
     (library-path library-path)
     (loaded? (= (nono_ffi_is_loaded) 1))
     (error error))))

;; : (-> Unit Alist)
(def (nono-c-binding-ffi-close)
  (let (status (nono_ffi_close))
    (nono-c-binding-ffi-field-rows
     (ok? (zero? status))
     (status status)
     (loaded? (= (nono_ffi_is_loaded) 1)))))

;;; Boundary: nono c binding selection binding is the policy-visible edge for
;;; sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> PooUserModuleSelection Symbol)
(def (nono-c-binding-selection-binding selection)
  (let (entry (yuanxu-user-module-selection-flag-entry selection ':binding))
    (cond
     ((and entry (pair? entry)) (cdr entry))
     ((yuanxu-user-module-selection-has-flag? selection '+ffi)
      'ffi)
     ((yuanxu-user-module-selection-has-flag? selection '+cli)
      'cli)
     (else 'ffi))))

;; : (-> PooUserModuleSelection Symbol Alist Alist)
(def (nono-c-binding-selection-receipt-prefix selection binding)
  (list (cons 'binding-source 'use-module)
        (cons 'selection-binding binding)
        (cons 'selection-key
              (yuanxu-user-module-selection-key selection))
        (cons 'selection-flags
              (yuanxu-user-module-selection-flags selection))))

;; : (-> PooUserModuleSelection Symbol RuntimeManifest Alist)
(def (nono-c-binding-selection-unsupported-receipt selection
                                                   binding
                                                   runtime-manifest)
  (nono-c-binding-ffi-rows/tail
   (nono-c-binding-selection-receipt-prefix selection binding)
   (nono-c-binding-ffi-field-rows
    (schema +nono-c-binding-selection-live-test-receipt-schema+)
    (ok? #f)
    (enabled? #f)
    (skipped? #t)
    (skip-reason 'unsupported-nono-binding)
    (runtime-executed #f)
    (cli-executed #f)
    (runtime-executed #f)
    (would-apply? #f)
    (irreversible-apply? #f)
    (dry-run (nono-c-binding-dry-run runtime-manifest)))))

;; : (-> PooUserModuleSelection RuntimeManifest [AlistOrCommand] Alist)
(def (nono-c-binding-selection-live-test selection runtime-manifest . maybe-options)
  (let (binding (nono-c-binding-selection-binding selection))
    (cond
     ((eq? binding 'ffi)
      (nono-c-binding-ffi-rows/tail
       (nono-c-binding-selection-receipt-prefix selection binding)
       (apply nono-c-binding-ffi-live-test
              runtime-manifest
              maybe-options)))
     ((eq? binding 'cli)
      (let (receipt
            (apply nono-c-binding-live-test runtime-manifest maybe-options))
        (nono-c-binding-ffi-rows/tail
         (nono-c-binding-selection-receipt-prefix selection binding)
         (nono-c-binding-ffi-rows/tail
          (nono-c-binding-ffi-field-rows
           (cli-executed
            (agent-sandbox-alist-ref receipt 'live-executed #f))
           (runtime-executed #f))
          receipt))))
     (else
      (nono-c-binding-selection-unsupported-receipt
       selection
       binding
       runtime-manifest)))))

;; : (-> RuntimeManifest Alist Symbol Alist)
(def (nono-c-binding-ffi-skip-receipt runtime-manifest options reason)
  (list (cons 'schema +nono-c-binding-ffi-live-test-receipt-schema+)
        (cons 'ok? #t)
        (cons 'enabled? #f)
        (cons 'skipped? #t)
        (cons 'skip-reason reason)
        (cons 'library-candidates
              (nono-c-binding-ffi-library-candidates options))
        (cons 'runtime-executed #f)
        (cons 'runtime-loaded? #f)
        (cons 'cli-executed #f)
        (cons 'runtime-executed #f)
        (cons 'would-apply? #f)
        (cons 'irreversible-apply? #f)
        (cons 'dry-run (nono-c-binding-dry-run runtime-manifest))))

;; : (-> RuntimeManifest Alist String Alist Alist)
(def (nono-c-binding-ffi-failure-receipt runtime-manifest
                                            options
                                            library-path
                                            open-receipt)
  (list (cons 'schema +nono-c-binding-ffi-live-test-receipt-schema+)
        (cons 'ok? #f)
        (cons 'enabled? #t)
        (cons 'skipped? #f)
        (cons 'library-path library-path)
        (cons 'library-candidates
              (nono-c-binding-ffi-library-candidates options))
        (cons 'runtime-executed #f)
        (cons 'runtime-loaded?
              (agent-sandbox-alist-ref open-receipt 'loaded? #f))
        (cons 'cli-executed #f)
        (cons 'runtime-executed #f)
        (cons 'would-apply? #f)
        (cons 'irreversible-apply? #f)
        (cons 'error (agent-sandbox-alist-ref open-receipt 'error ""))
        (cons 'open open-receipt)
        (cons 'dry-run (nono-c-binding-dry-run runtime-manifest))))

;;; Boundary: nono c binding runtime safe string is the policy-visible edge for
;;; sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> String)
(def (nono-c-binding-ffi-safe-string value)
  (if (string? value) value ""))

;; : (-> RuntimeManifest Alist String Alist)
(def (nono-c-binding-ffi-success-receipt runtime-manifest options library-path)
  (let* ((support? (nono_ffi_sandbox_is_supported))
         (support-info-supported? (nono_ffi_support_is_supported))
         (platform
          (nono-c-binding-ffi-safe-string
           (nono_ffi_support_platform)))
         (details
          (nono-c-binding-ffi-safe-string
           (nono_ffi_support_details)))
         (capability-roundtrip-code
          (nono_ffi_capability_roundtrip))
         (apply-null-code (nono_ffi_apply_null))
         (ok? (and (>= support? 0)
                   (>= support-info-supported? 0)
                   (zero? capability-roundtrip-code)
                   (= apply-null-code
                      +nono-c-binding-ffi-apply-null-error-code+))))
    (nono-c-binding-ffi-close)
    (list (cons 'schema +nono-c-binding-ffi-live-test-receipt-schema+)
          (cons 'ok? ok?)
          (cons 'enabled? #t)
          (cons 'skipped? #f)
          (cons 'library-path library-path)
          (cons 'library-candidates
                (nono-c-binding-ffi-library-candidates options))
          (cons 'runtime-executed #t)
          (cons 'runtime-loaded? #t)
          (cons 'cli-executed #f)
          (cons 'runtime-executed #f)
          (cons 'would-apply? #f)
          (cons 'irreversible-apply? #f)
          (cons 'apply-symbol 'nono_sandbox_apply)
          (cons 'apply-null-only? #t)
          (cons 'apply-null-code apply-null-code)
          (cons 'capability-roundtrip-code capability-roundtrip-code)
          (cons 'support? (= support? 1))
          (cons 'support-info-supported? (= support-info-supported? 1))
          (cons 'platform platform)
          (cons 'details details)
          (cons 'dry-run (nono-c-binding-dry-run runtime-manifest)))))

;; : (-> RuntimeManifest [Alist] Alist)
(def (nono-c-binding-ffi-live-test runtime-manifest . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (library-path
          (nono-c-binding-ffi-resolve-library options)))
    (if library-path
      (let (open-receipt (nono-c-binding-ffi-open library-path))
        (if (agent-sandbox-alist-ref open-receipt 'ok? #f)
          (nono-c-binding-ffi-success-receipt
           runtime-manifest
           options
           library-path)
          (nono-c-binding-ffi-failure-receipt
           runtime-manifest
           options
           library-path
           open-receipt)))
      (nono-c-binding-ffi-skip-receipt
       runtime-manifest
       options
       'runtime-library-not-found))))
