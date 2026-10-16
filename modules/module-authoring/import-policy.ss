;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: reader-native policy for imports written inside a POO module role.
;;; Invariant: this owner reads datums only; it never expands or evaluates them.

(import (only-in :core/utilities/algorithms
                 poo-flow-read-datums/append-map
                 poo-flow-scheme-datum-find))

(export poo-flow-module-owner-import-observation-kind
        poo-flow-module-forbidden-aggregate-imports
        poo-flow-module-owner-import-datum-observations
        poo-flow-module-owner-import-port-observations
        poo-flow-module-owner-import-file-observations
        poo-flow-build-bootstrap-import-datum-observations
        poo-flow-build-bootstrap-import-port-observations
        poo-flow-build-bootstrap-import-file-observations
        poo-flow-build-bootstrap-datum-observations
        poo-flow-build-bootstrap-port-observations
        poo-flow-build-bootstrap-file-observations)


(def poo-flow-module-owner-import-observation-kind
  "poo-flow.module-owner-import-observation.v1")

;;; These are user-facing aggregate surfaces. Module implementation roles must
;;; import the precise owner that defines the bindings they consume.
(def poo-flow-module-forbidden-aggregate-imports
  '(:poo-flow/modules/workflow/control-plane/api
    :poo-flow/modules/user-interface/interface
    :core/feature-system/interface))

(def (poo-flow-module-import-datum-first-member datum members)
  (poo-flow-scheme-datum-find
   (lambda (candidate)
     (and (symbol? candidate) (memq candidate members) candidate))
   datum))

(def (poo-flow-module-owner-import-observation scope owner)
  (list
   (cons 'kind poo-flow-module-owner-import-observation-kind)
   (cons 'scope scope)
   (cons 'owner owner)
   (cons 'form 'import)
   (cons 'phase 'module-admission)
   (cons 'status 'aggregate-owner-import)
   (cons 'detail
         (list
          (cons 'code 'module-owner-import-expands-aggregate-facade)
          (cons 'recommendation 'import-precise-owner)))
   (cons 'runtime-executed #f)))

;; : (-> Symbol SchemeDatum [Alist])
(def (poo-flow-module-owner-import-datum-observations scope datum)
  (if (and (pair? datum) (eq? (car datum) 'import))
    (let (owner
          (poo-flow-module-import-datum-first-member
           (cdr datum)
           poo-flow-module-forbidden-aggregate-imports))
      (if owner
        (list (poo-flow-module-owner-import-observation scope owner))
        '()))
    '()))

;; : (-> Symbol InputPort [Alist])
(def (poo-flow-module-owner-import-port-observations scope port)
  (poo-flow-read-datums/append-map
   (cut poo-flow-module-owner-import-datum-observations scope <>)
   port))

;; : (-> Symbol PathString [Alist])
(def (poo-flow-module-owner-import-file-observations scope path)
  (call-with-input-file
   path
   (lambda (port)
     (poo-flow-module-owner-import-port-observations scope port))))

;;; A package build entry executes before its own artifacts exist. Importing a
;;; local package owner here creates a loaded-module/currentness cycle on
;;; macOS, where the compiler emits numbered replacement objects forever.
(def (poo-flow-build-bootstrap-package-owner datum)
  (poo-flow-scheme-datum-find
   (lambda (candidate)
     (cond
      ((string? candidate)
       (and (or (string-prefix? "./src/" candidate)
                (string-prefix? "src/" candidate))
            candidate))
      ((symbol? candidate)
       (and (string-prefix? ":poo-flow/" (symbol->string candidate))
            candidate))
      (else #f)))
   datum))

(def (poo-flow-build-bootstrap-import-observation scope owner)
  (list
   (cons 'kind poo-flow-module-owner-import-observation-kind)
   (cons 'scope scope)
   (cons 'owner (if (string? owner) (string->symbol owner) owner))
   (cons 'form 'import)
   (cons 'phase 'build-bootstrap-admission)
   (cons 'status 'build-bootstrap-imports-package-owner)
   (cons 'detail
         (list
          (cons 'code 'build-bootstrap-self-import)
          (cons 'recommendation 'declare-package-spec-only)))
   (cons 'runtime-executed #f)))

;;; PackageSpec already owns native import-closure projection.  Re-entering the
;;; package loader, scanning every Gerbil source, or supplying a parallel
;;; `modules` catalog from build.ss duplicates that owner and can expand the
;;; package before std/make performs its currentness pass.
(def poo-flow-build-bootstrap-forbidden-projection-forms
  '(poo-flow-load-modules all-gerbil-modules modules))

(def (poo-flow-build-bootstrap-projection-form datum)
  (poo-flow-scheme-datum-find
   (lambda (candidate)
     (and (pair? candidate)
          (memq (car candidate)
                poo-flow-build-bootstrap-forbidden-projection-forms)
          (car candidate)))
   datum))

(def (poo-flow-build-bootstrap-projection-observation scope form)
  (list
   (cons 'kind poo-flow-module-owner-import-observation-kind)
   (cons 'scope scope)
   (cons 'owner form)
   (cons 'form form)
   (cons 'phase 'build-bootstrap-admission)
   (cons 'status 'build-bootstrap-reimplements-package-projection)
   (cons 'detail
         (list
          (cons 'code 'build-bootstrap-parallel-projection)
          (cons 'recommendation 'declare-public-entry-modules)))
   (cons 'runtime-executed #f)))

(def (poo-flow-build-bootstrap-import-datum-observations scope datum)
  (if (and (pair? datum) (eq? (car datum) 'import))
    (alet (owner (poo-flow-build-bootstrap-package-owner (cdr datum)))
      (list (poo-flow-build-bootstrap-import-observation scope owner)))
    '()))

(def (poo-flow-build-bootstrap-import-port-observations scope port)
  (poo-flow-read-datums/append-map
   (cut poo-flow-build-bootstrap-import-datum-observations scope <>)
   port))

(def (poo-flow-build-bootstrap-import-file-observations scope path)
  (call-with-input-file
   path
   (lambda (port)
     (poo-flow-build-bootstrap-import-port-observations scope port))))

;; : (-> Symbol SchemeDatum [Alist])
(def (poo-flow-build-bootstrap-datum-observations scope datum)
  (append
   (or (poo-flow-build-bootstrap-import-datum-observations scope datum) '())
   (let (form (poo-flow-build-bootstrap-projection-form datum))
     (if form
       (list (poo-flow-build-bootstrap-projection-observation scope form))
       '()))))

;; : (-> Symbol InputPort [Alist])
(def (poo-flow-build-bootstrap-port-observations scope port)
  (poo-flow-read-datums/append-map
   (cut poo-flow-build-bootstrap-datum-observations scope <>)
   port))

;; : (-> Symbol PathString [Alist])
(def (poo-flow-build-bootstrap-file-observations scope path)
  (call-with-input-file
   path
   (lambda (port)
     (poo-flow-build-bootstrap-port-observations scope port))))
