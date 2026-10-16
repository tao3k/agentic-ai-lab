;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: user config fragment loading syntax.
;;; Invariant: `load!` resolves and reads declaration fragments at macro time;
;;; runtime module selection and descriptor realization stay in other owners.

(import (only-in :gerbil/expander/core
                 current-expander-context
                 expander-context-id)
        (only-in :gerbil/expander/stx stx-source))

(export load!
        poo-flow-load-profile-module-binding)

(begin-syntax
  (include "load-binding-syntax-core.inc")

  ;; Compile-time path and naming helpers keep `load!` focused on expansion.
  ;; Engineering note: policy-sensitive helpers in this owner keep explicit
  ;; contracts adjacent to definitions so downstream reports stay actionable.
  ;; : (-> Any Any)
  (def (poo-flow-load-source-path value)
    (cond
     ((string? value) value)
     ((and (pair? value) (string? (car value))) (car value))
     (else #f)))

  ;; : (-> Any Any)
  (def (poo-flow-load-absolute-path? value)
    (and (> (string-length value) 0)
         (char=? (string-ref value 0) #\/)))

  ;; : (-> Any Any)
  (def (poo-flow-load-drop-prefix prefix value)
    (let ((prefix-length (string-length prefix))
          (value-length (string-length value)))
      (if (and (>= value-length prefix-length)
               (string=? (substring value 0 prefix-length) prefix))
        (substring value prefix-length value-length)
        value)))

  ;; : (-> Any Any)
  (def (poo-flow-load-drop-suffix suffix value)
    (let ((value-length (string-length value))
          (suffix-length (string-length suffix)))
      (if (and (>= value-length suffix-length)
               (string=? (substring value
                                    (- value-length suffix-length)
                                    value-length)
                         suffix))
        (substring value 0 (- value-length suffix-length))
        value)))

  ;; : (-> Any Any)
  (def (poo-flow-load-last-segment segments fallback)
    (let loop ((rest segments) (last fallback))
      (if (null? rest) last (loop (cdr rest) (car rest)))))

  ;; : (-> Any Any)
  (def (poo-flow-load-segment-member? names segments)
    (let loop ((rest segments))
      (cond
       ((null? rest) #f)
       ((member (car rest) names) #t)
       (else (loop (cdr rest))))))

  ;; : (-> Any Any)
  (def (poo-flow-load-object-fragment-path? segments)
    (poo-flow-load-segment-member? ["objects" "objects.ss"] segments))

  ;; : (-> Any Any)
  (def (poo-flow-load-case-fragment-path? segments)
    (poo-flow-load-segment-member? ["cases" "cases.ss"] segments))

  ;; : (-> Any Any)
  (def (poo-flow-load-include-source-path path-value)
    (let (path-length
          (and (string? path-value) (string-length path-value)))
      (cond
       ((not (string? path-value))
        (error "load! expects a string path"))
       ((and (>= path-length 3)
             (string=? (substring path-value
                                  (- path-length 3)
                                  path-length)
                       ".ss"))
        path-value)
       (else
        (string-append path-value ".ss")))))

  ;; : (-> Any Any)
  (def (poo-flow-load-candidate-fragment-paths include-source-path
                                               call-source-path)
    (if (poo-flow-load-absolute-path? include-source-path)
      [include-source-path]
      (let* ((source-base
              (path-directory (or call-source-path (current-directory))))
             (owner-path
              (path-expand include-source-path source-base))
             (cwd-path
              (path-expand include-source-path (current-directory)))
             (root-parent-path
              (and (poo-flow-load-binding-string-prefix? "../"
                                                         include-source-path)
                   (path-expand
                    (poo-flow-load-drop-prefix "../" include-source-path)
                    (current-directory)))))
        (append [owner-path cwd-path]
                (if root-parent-path [root-parent-path] [])))))

  ;; : (-> Any Any)
  (def (poo-flow-load-first-existing-path candidates)
    (let loop ((rest candidates))
      (cond
       ((null? rest) (car candidates))
       ((file-exists? (car rest)) (car rest))
       (else (loop (cdr rest))))))

  ;; : (-> Any Any)
  (def (poo-flow-load-fragment-info path-value
                                    path-source
                                    form-source)
    (let* ((include-source-path
            (poo-flow-load-include-source-path path-value))
           (call-source-path/raw
            (or (poo-flow-load-source-path path-source)
                (poo-flow-load-source-path form-source)
                (poo-flow-load-binding-module-context-source-path)))
           (call-source-path
            (and call-source-path/raw
                 (path-expand call-source-path/raw (current-directory))))
           (fragment-source-path
            (poo-flow-load-first-existing-path
             (poo-flow-load-candidate-fragment-paths include-source-path
                                                     call-source-path)))
           (source-segments
            (if call-source-path
              (poo-flow-load-binding-path-segments call-source-path)
              (poo-flow-load-binding-path-segments fragment-source-path)))
           (custom-tail
            (poo-flow-load-binding-member-tail "custom" source-segments))
           (custom-module-name
            (if (and custom-tail (pair? (cdr custom-tail)))
              (cadr custom-tail)
              "module"))
           (load-name
            (poo-flow-load-drop-suffix
             ".ss"
             (poo-flow-load-last-segment
              (poo-flow-load-binding-path-segments include-source-path)
              "config")))
           (include-segments
            (poo-flow-load-binding-path-segments include-source-path))
           (objects-fragment?
            (or (poo-flow-load-object-fragment-path? source-segments)
                (poo-flow-load-object-fragment-path? include-segments)
                (string=? load-name "objects")))
           (case-fragment?
            (or (poo-flow-load-case-fragment-path? source-segments)
                (poo-flow-load-case-fragment-path? include-segments)))
           (binding-name
            (poo-flow-load-binding-fragment-name custom-module-name
                                                load-name
                                                case-fragment?)))
      (list binding-name
            objects-fragment?
            fragment-source-path))))

;; poo-flow-load-profile-module-binding
;; : (-> Syntax Syntax)
;; | doc m%
;;   Resolves a profile fragment name to the binding generated by
;;   `(load! "profiles/<name>")` in the current user module. Boundary: this keeps
;;   load! binding naming in one owner.
;;   # Examples
;;   ```scheme
;;   (poo-flow-load-profile-module-binding langchain)
;;   ;; => poo-flow-custom-<module>-langchain-module
;;   ```
(defsyntax (poo-flow-load-profile-module-binding stx)
  (syntax-case stx ()
    ((ctx profile-name)
     (poo-flow-load-binding-profile-module-syntax
      (syntax ctx)
      (syntax profile-name)))))

;;; Doom-style config fragments are declaration includes, not runtime module
;;; loading. Extensionless paths mirror Doom's `load!` surface; the macro wraps
;;; the fragment result in a generated binding so user files only write the
;;; declaration form, such as `(use-module ...)`.
;; load!
;;   : (-> String Syntax...)
;;   | contract: loads a user config fragment relative to the current module
;;       and exports a generated binding for the fragment result
;;   | doc m%
;;       # Examples
;;
;;       ```scheme
;;       (load! "profiles/session")
;;       ;; => exports poo-flow-custom-<module>-session-module
;;       ```
;;     %
(defsyntax (load! stx)
  (syntax-case stx ()
    ((ctx path)
     (let* ((path-value (syntax->datum (syntax path)))
            (fragment-info
             (poo-flow-load-fragment-info path-value
                                          (stx-source (syntax path))
                                          (stx-source stx)))
            (binding-name (car fragment-info))
            (objects-fragment? (cadr fragment-info))
            (fragment-source-path (caddr fragment-info)))
       (with-syntax ((binding (datum->syntax (syntax ctx)
                                             binding-name))
                     (fragment-source
                      (datum->syntax (syntax ctx) fragment-source-path)))
         (if objects-fragment?
           (syntax
            (begin
              (import :core/module-system/schema/interface)
              ;; : Any
              (def binding
                (begin (include fragment-source)))
              (export binding)))
            (syntax
             (begin
               ;; : Any
               (def binding
                 (begin (include fragment-source)))
               (export binding)))))))))
