;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Generator owner: deterministic runtime-v0 artifacts are either compared
;;; together or replaced together through this single command boundary.

(import (only-in :std/misc/ports read-file-string write-file-string)
        :poo-flow/modules/workflow/contracts/runtime-v0-abi-schema)

;; : Path
(def header-path
  "bindings/runtime-c/include/poo_flow/runtime_v0_contract.h")
;; : Path
(def vector-path
  "bindings/runtime-c/tests/vectors/runtime_v0_contract.txt")
;; : Path
(def event-vector-path
  "bindings/runtime-c/tests/vectors/runtime_v0_event_1.txt")

;; : (-> String Path Path)
(def (command-line-option name default)
  (let (option-tail (member name (command-line)))
    (cond
     ((not option-tail) default)
     ((pair? (cdr option-tail)) (cadr option-tail))
     (else (error "missing command-line option value" name)))))

;;; File boundary: generated artifacts are compared or replaced only through
;;; these two explicit text I/O helpers.
;; : (-> Path String)
(def (read-text path)
  (read-file-string path))

;; : (-> Path String Void)
(def (write-text path content)
  (write-file-string path content))

;; : RuntimeV0Header
(def header
  (poo-flow-runtime-v0-abi-schema->c-header
   +poo-flow-runtime-v0-abi-schema+))
;; : RuntimeV0Vector
(def vector
  (poo-flow-runtime-v0-abi-schema->vector
   +poo-flow-runtime-v0-abi-schema+))
;; : RuntimeV0EventVector
(def event-vector
  (poo-flow-runtime-v0-abi-schema->event-vector
   +poo-flow-runtime-v0-abi-schema+))
;; : Path
(def selected-header-path
  (command-line-option "--header-output" header-path))
;; : Path
(def selected-vector-path
  (command-line-option "--vector-output" vector-path))
;; : Path
(def selected-event-vector-path
  (command-line-option "--event-vector-output" event-vector-path))
;; : Boolean
(def check? (member "--check" (command-line)))

(if check?
  (unless (and (equal? (read-text selected-header-path) header)
               (equal? (read-text selected-vector-path) vector)
               (equal? (read-text selected-event-vector-path) event-vector))
    (error "stale generated runtime v0 contract artifacts"))
  (begin (write-text selected-header-path header)
         (write-text selected-vector-path vector)
         (write-text selected-event-vector-path event-vector)))
